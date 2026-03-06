import Foundation
import Combine
import CloudKit

private struct CloudTaskSnapshot: Codable {
    var tasks: [TaskItem]
    var archivedTasks: [TaskItem]
    var updatedAt: Date
    var sourceUserID: String
}

private actor TaskCloudStore {
    private let container = CKContainer.default()
    private let recordID = CKRecord.ID(recordName: "tasker-sync-state-v1")

    private var database: CKDatabase { container.privateCloudDatabase }

    func accountAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    func fetchSnapshot() async throws -> CloudTaskSnapshot? {
        do {
            let record = try await database.record(for: recordID)
            guard let payload = record["payload"] as? Data else { return nil }
            return try JSONDecoder().decode(CloudTaskSnapshot.self, from: payload)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: CloudTaskSnapshot) async throws {
        let payload = try JSONEncoder().encode(snapshot)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: "TaskSyncState", recordID: recordID)
        }
        record["payload"] = payload as CKRecordValue
        record["updatedAt"] = snapshot.updatedAt as CKRecordValue
        _ = try await database.save(record)
    }
}

@MainActor
final class TaskSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published var isSyncEnabled = true
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var syncStatusText: String = "Синхронизация выключена"

    private let localUpdatedAtKey = "task_store_local_updated_at"
    private lazy var cloudStore = TaskCloudStore()

    private weak var store: TaskStore?
    private weak var accountManager: AppleAccountManager?

    private var cancellables = Set<AnyCancellable>()
    private var didConnect = false
    private var suppressNextUpload = false
    private var localUpdatedAt: Date = Date.distantPast

    func connect(store: TaskStore, accountManager: AppleAccountManager) {
        guard !didConnect else { return }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            syncStatusText = "Синхронизация недоступна в Preview"
            return
        }
        self.store = store
        self.accountManager = accountManager
        self.localUpdatedAt = UserDefaults.standard.object(forKey: localUpdatedAtKey) as? Date ?? Date.distantPast
        self.lastSyncAt = UserDefaults.standard.object(forKey: "task_store_last_sync_at") as? Date

        accountManager.$isSignedIn
            .removeDuplicates()
            .sink { [weak self] isSignedIn in
                guard let self else { return }
                if isSignedIn {
                    self.syncStatusText = "Проверка iCloud…"
                    Task { await self.syncOnSignIn() }
                } else {
                    self.syncStatusText = "Синхронизация выключена"
                }
            }
            .store(in: &cancellables)

        store.$tasks
            .combineLatest(store.$archivedTasks)
            .dropFirst()
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.localUpdatedAt = Date()
                UserDefaults.standard.set(self.localUpdatedAt, forKey: self.localUpdatedAtKey)
                guard !self.suppressNextUpload else {
                    self.suppressNextUpload = false
                    return
                }
                Task { await self.pushLocalSnapshotIfNeeded(reason: "local_change") }
            }
            .store(in: &cancellables)

        didConnect = true

        if accountManager.isSignedIn {
            Task { await syncOnSignIn() }
        }
    }

    func syncNow() async {
        await pullRemoteThenPushIfNeeded(forcePush: true)
    }

    func setSyncEnabled(_ isEnabled: Bool) {
        isSyncEnabled = isEnabled
        if !isEnabled {
            syncStatusText = "Синхронизация на паузе"
        } else if accountManager?.isSignedIn == true {
            Task { await pushLocalSnapshotIfNeeded(reason: "resume") }
        }
    }

    private func syncOnSignIn() async {
        guard let accountManager, accountManager.isSignedIn else { return }

        let accountAvailable = await cloudStore.accountAvailable()
        guard accountAvailable else {
            syncStatusText = "iCloud недоступен"
            return
        }

        syncStatusText = "Синхронизация включена"
        await pullRemoteThenPushIfNeeded(forcePush: false)
    }

    private func pullRemoteThenPushIfNeeded(forcePush: Bool) async {
        guard isSyncEnabled else { return }
        guard let store, let accountManager, accountManager.isSignedIn, let userID = accountManager.userID else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let remote = try await cloudStore.fetchSnapshot()
            if let remote {
                if remote.updatedAt > localUpdatedAt {
                    suppressNextUpload = true
                    store.tasks = remote.tasks
                    store.archivedTasks = remote.archivedTasks
                    store.flushPendingSaves()
                    localUpdatedAt = remote.updatedAt
                    UserDefaults.standard.set(localUpdatedAt, forKey: localUpdatedAtKey)
                    syncStatusText = "Загружено из iCloud"
                } else if forcePush || remote.sourceUserID != userID {
                    try await pushSnapshot(store: store, userID: userID)
                } else {
                    syncStatusText = "Данные актуальны"
                }
            } else {
                try await pushSnapshot(store: store, userID: userID)
            }
            lastSyncAt = Date()
            UserDefaults.standard.set(lastSyncAt, forKey: "task_store_last_sync_at")
        } catch {
            syncStatusText = "Ошибка синхронизации: \(error.localizedDescription)"
        }
    }

    private func pushLocalSnapshotIfNeeded(reason: String) async {
        guard isSyncEnabled else { return }
        guard let store, let accountManager, accountManager.isSignedIn, let userID = accountManager.userID else { return }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await pushSnapshot(store: store, userID: userID)
            syncStatusText = reason == "local_change" ? "Синхронизировано" : "Синхронизация включена"
            lastSyncAt = Date()
            UserDefaults.standard.set(lastSyncAt, forKey: "task_store_last_sync_at")
        } catch {
            syncStatusText = "Ошибка синхронизации: \(error.localizedDescription)"
        }
    }

    private func pushSnapshot(store: TaskStore, userID: String) async throws {
        let snapshot = CloudTaskSnapshot(
            tasks: store.tasks,
            archivedTasks: store.archivedTasks,
            updatedAt: Date(),
            sourceUserID: userID
        )
        try await cloudStore.saveSnapshot(snapshot)
        localUpdatedAt = snapshot.updatedAt
        UserDefaults.standard.set(localUpdatedAt, forKey: localUpdatedAtKey)
    }
}
