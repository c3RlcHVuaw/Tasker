import Foundation
import Combine

// MARK: - Хранилище задач
@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            scheduleTasksSave()
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
    private let saveDebounceNanoseconds: UInt64 = 250_000_000
    
    init() {
        isHydrating = true
        loadTasks()
        loadArchivedTasks()
        isHydrating = false
    }
    
    func archiveTask(_ task: TaskItem) {
        PerformanceTelemetry.event("archiveTask")
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks.remove(at: index)
            archivedTasks.append(task)
        }
    }

    func archiveTasks(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        PerformanceTelemetry.countEvent("archiveTasks.batchCount", count: ids.count)

        let archivedBatch = tasks.filter { ids.contains($0.id) }
        guard !archivedBatch.isEmpty else { return }

        tasks.removeAll { ids.contains($0.id) }
        archivedTasks.append(contentsOf: archivedBatch)
    }

    func archiveAllTasks() {
        guard !tasks.isEmpty else { return }
        PerformanceTelemetry.countEvent("archiveAllTasks.batchCount", count: tasks.count)
        archivedTasks.append(contentsOf: tasks)
        tasks.removeAll(keepingCapacity: true)
    }

    func flushPendingSaves() {
        tasksSaveTask?.cancel()
        archivedTasksSaveTask?.cancel()
        persist(tasks, forKey: tasksKey)
        persist(archivedTasks, forKey: archivedTasksKey)
        PerformanceTelemetry.event("flushPendingSaves")
    }
    
    deinit {
        tasksSaveTask?.cancel()
        archivedTasksSaveTask?.cancel()
    }

    // MARK: - Сохранение и загрузка
    private func scheduleTasksSave() {
        guard !isHydrating else { return }
        tasksSaveTask?.cancel()
        let snapshot = tasks
        tasksSaveTask = Task {
            try? await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            persist(snapshot, forKey: tasksKey)
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
        archivedTasksSaveTask = Task {
            try? await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            persist(snapshot, forKey: archivedTasksKey)
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
            guard let encoded = try? JSONEncoder().encode(tasks) else { return }
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
