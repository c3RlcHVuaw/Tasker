import SwiftUI

struct PinnedTasksHeader: View {
    let pinnedTasks: [TaskItem]
    @Binding var currentIndex: Int
    var onTaskSelected: ((TaskItem) -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    private var safeIndex: Int {
        guard !pinnedTasks.isEmpty else { return 0 }
        return min(max(currentIndex, 0), pinnedTasks.count - 1)
    }

    var currentTask: TaskItem? {
        guard !pinnedTasks.isEmpty else { return nil }
        return pinnedTasks[safeIndex]
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
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .glassEffect(
                            .regular
                                .tint(colorScheme == .dark ? .black.opacity(0.20) : .white.opacity(0.70)),
                            in: .rect(cornerRadius: 10)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.22))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                onTaskSelected?(task)
                nextPinned()
            }
            .onAppear(perform: normalizeCurrentIndex)
            .onChange(of: pinnedTasks.count) { _, _ in
                normalizeCurrentIndex()
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

    private func normalizeCurrentIndex() {
        guard !pinnedTasks.isEmpty else {
            currentIndex = 0
            return
        }
        currentIndex = safeIndex
    }
}

#Preview {
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
