import Foundation
import Combine

// MARK: - Хранилище задач
@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            saveTasks()
        }
    }
    @Published var archivedTasks: [TaskItem] = [] {
        didSet {
            saveArchivedTasks()
        }
    }
    
    private let tasksKey = "SavedTasks"
    private let archivedTasksKey = "SavedArchivedTasks"
    
    init() {
        loadTasks()
        loadArchivedTasks()
    }
    
    func archiveTask(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks.remove(at: index)
            archivedTasks.append(task)
        }
    }
    
    // MARK: - Сохранение и загрузка
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
    }
    
    private func saveArchivedTasks() {
        if let encoded = try? JSONEncoder().encode(archivedTasks) {
            UserDefaults.standard.set(encoded, forKey: archivedTasksKey)
        }
    }
    
    private func loadArchivedTasks() {
        if let data = UserDefaults.standard.data(forKey: archivedTasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            archivedTasks = decoded
        }
    }
}

