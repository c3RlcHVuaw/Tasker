import Foundation
import Combine

// MARK: - Хранилище задач
@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            scheduleTasksSave()
            scheduleRecurringNotifications()
        }
    }
    @Published var archivedTasks: [TaskItem] = [] {
        didSet {
            scheduleArchivedTasksSave()
        }
    }
    
    private let tasksKey = "SavedTasks"
    private let archivedTasksKey = "SavedArchivedTasks"
    private var isHydrating = false
    private var tasksSaveTask: Task<Void, Never>?
    private var archivedTasksSaveTask: Task<Void, Never>?
    private var recurringNotificationsTask: Task<Void, Never>?
    private let saveDebounceNanoseconds: UInt64 = 250_000_000
    
    init() {
        isHydrating = true
        loadTasks()
        loadArchivedTasks()
        isHydrating = false
        scheduleRecurringNotifications(immediate: true)
    }
    
    func archiveTask(_ task: TaskItem) {
        PerformanceTelemetry.event("archiveTask")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let removed = tasks.remove(at: index)
            archivedTasks.append(removed)
            if let next = makeRecurringTask(from: removed) {
                tasks.append(next)
            }
        }
    }

    func archiveTasks(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        PerformanceTelemetry.countEvent("archiveTasks.batchCount", count: ids.count)

        let archivedBatch = tasks.filter { ids.contains($0.id) }
        guard !archivedBatch.isEmpty else { return }

        tasks.removeAll { ids.contains($0.id) }
        archivedTasks.append(contentsOf: archivedBatch)
        let recurring = archivedBatch.compactMap(makeRecurringTask(from:))
        if !recurring.isEmpty {
            tasks.append(contentsOf: recurring)
        }
    }

    func archiveAllTasks() {
        guard !tasks.isEmpty else { return }
        PerformanceTelemetry.countEvent("archiveAllTasks.batchCount", count: tasks.count)
        let batch = tasks
        archivedTasks.append(contentsOf: batch)
        tasks.removeAll(keepingCapacity: true)
        let recurring = batch.compactMap(makeRecurringTask(from:))
        if !recurring.isEmpty {
            tasks.append(contentsOf: recurring)
        }
    }

    func flushPendingSaves() {
        tasksSaveTask?.cancel()
        archivedTasksSaveTask?.cancel()
        persist(tasks, forKey: tasksKey)
        persist(archivedTasks, forKey: archivedTasksKey)
        PerformanceTelemetry.event("flushPendingSaves")
    }

    func refreshRecurringNotifications() {
        scheduleRecurringNotifications(immediate: true)
    }
    
    deinit {
        tasksSaveTask?.cancel()
        archivedTasksSaveTask?.cancel()
        recurringNotificationsTask?.cancel()
    }

    // MARK: - Сохранение и загрузка
    private func scheduleTasksSave() {
        guard !isHydrating else { return }
        tasksSaveTask?.cancel()
        let snapshot = tasks
        let key = tasksKey
        tasksSaveTask = Task {
            try? await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                Self.persistSnapshot(snapshot, forKey: key)
            }.value
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
    }
    
    private func scheduleArchivedTasksSave() {
        guard !isHydrating else { return }
        archivedTasksSaveTask?.cancel()
        let snapshot = archivedTasks
        let key = archivedTasksKey
        archivedTasksSaveTask = Task {
            try? await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                Self.persistSnapshot(snapshot, forKey: key)
            }.value
        }
    }
    
    private func loadArchivedTasks() {
        if let data = UserDefaults.standard.data(forKey: archivedTasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            archivedTasks = decoded
        }
    }

    private func persist(_ tasks: [TaskItem], forKey key: String) {
        PerformanceTelemetry.measure("persistTasks") {
            Self.persistSnapshot(tasks, forKey: key)
        }
    }

    nonisolated private static func persistSnapshot(_ tasks: [TaskItem], forKey key: String) {
        guard let encoded = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private func scheduleRecurringNotifications(immediate: Bool = false) {
        guard !isHydrating else { return }

        recurringNotificationsTask?.cancel()
        let snapshot = tasks
        let enabled = UserDefaults.standard.bool(forKey: AppPreferenceKeys.enableRecurrenceNotifications)
        let hour = UserDefaults.standard.object(forKey: AppPreferenceKeys.recurrenceNotificationHour) == nil
            ? 9
            : UserDefaults.standard.integer(forKey: AppPreferenceKeys.recurrenceNotificationHour)
        let minute = UserDefaults.standard.object(forKey: AppPreferenceKeys.recurrenceNotificationMinute) == nil
            ? 0
            : UserDefaults.standard.integer(forKey: AppPreferenceKeys.recurrenceNotificationMinute)

        recurringNotificationsTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            await RecurringTaskNotifications.refresh(tasks: snapshot, enabled: enabled, hour: hour, minute: minute)
        }
    }

    private func makeRecurringTask(from task: TaskItem) -> TaskItem? {
        guard task.recurrence != .none else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let component: Calendar.Component

        switch task.recurrence {
        case .none:
            return nil
        case .daily:
            component = .day
        case .weekly:
            component = .weekOfYear
        case .monthly:
            component = .month
        }

        let base = max(task.date, now)
        guard let nextDate = calendar.date(byAdding: component, value: 1, to: base) else { return nil }

        return TaskItem(
            text: task.text,
            date: nextDate,
            photos: task.photos,
            reactions: task.reactions,
            isPinned: task.isPinned,
            recurrence: task.recurrence
        )
    }
}
