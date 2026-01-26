import SwiftUI

struct PinnedTasksHeader: View {
    let pinnedTasks: [TaskItem]
    @Binding var currentIndex: Int
    var onTaskSelected: ((TaskItem) -> Void)?
    
    var currentTask: TaskItem? {
        guard currentIndex >= 0 && currentIndex < pinnedTasks.count else { return nil }
        return pinnedTasks[currentIndex]
    }
    
    var body: some View {
        if let task = currentTask {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                    
                    Text(task.text.prefix(50))
                        .lineLimit(1)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Text("Закреплено: \(pinnedTasks.count)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: previousPinned) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        
                        Button(action: nextPinned) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                onTaskSelected?(task)
                nextPinned()
            }
        }
    }
    
    private func nextPinned() {
        if currentIndex < pinnedTasks.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
    }
    
    private func previousPinned() {
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = pinnedTasks.count - 1
        }
    }
}

#Preview {
    let store = TaskStore()
    var task1 = TaskItem(text: "Первое закрепленное сообщение")
    task1.isPinned = true
    var task2 = TaskItem(text: "Второе закрепленное сообщение")
    task2.isPinned = true
    
    return VStack {
        PinnedTasksHeader(pinnedTasks: [task1, task2], currentIndex: .constant(0))
            .padding()
        Spacer()
    }
    .background(Color(.systemBackground))
}
