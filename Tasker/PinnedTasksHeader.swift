import SwiftUI

struct PinnedTasksHeader: View {
    let pinnedTasks: [TaskItem]
    @Binding var currentIndex: Int
    var onTaskSelected: ((TaskItem) -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor
    
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
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(appAccentColor)

                Text(task.text.prefix(70))
                    .lineLimit(1)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(
                            .regular
                                .tint(colorScheme == .dark ? .white.opacity(0.22) : .white.opacity(0.46)),
                            in: .capsule
                        )
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.34))
                        )
                }
            }
            .clipShape(Capsule())
            .padding(.horizontal, 4)
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
    
    private func normalizeCurrentIndex() {
        guard !pinnedTasks.isEmpty else {
            currentIndex = 0
            return
        }
        currentIndex = safeIndex
    }
}

#Preview {
    let task1 = TaskItem(text: "Первое закрепленное сообщение")
    let task2 = TaskItem(text: "Второе закрепленное сообщение")
    
    VStack {
        PinnedTasksHeader(pinnedTasks: [task1, task2], currentIndex: .constant(0))
            .padding()
        Spacer()
    }
    .background(Color(.systemBackground))
}
