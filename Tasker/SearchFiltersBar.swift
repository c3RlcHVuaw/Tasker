import SwiftUI

func usedReactions(from tasks: [TaskItem]) -> [String] {
    let used = Set(tasks.flatMap(\.reactions))
    if used.isEmpty {
        return []
    }

    let fromPreset = reactionEmojis.filter { used.contains($0) }
    let custom = used.subtracting(reactionEmojis).sorted()
    return fromPreset + custom
}

struct SearchFiltersMenuButton: View {
    @Binding var filterWithPhoto: Bool
    @Binding var filterArchive: Bool

    var body: some View {
        Menu {
            Toggle(isOn: $filterWithPhoto) {
                Label("С картинкой", systemImage: "photo")
            }
            Toggle(isOn: $filterArchive) {
                Label("Архивированные", systemImage: "archivebox")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: (filterWithPhoto || filterArchive)
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle((filterWithPhoto || filterArchive) ? Color.accentColor : Color.primary)

                if filterWithPhoto || filterArchive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Фильтры")
    }
}

struct SearchReactionChipsBar: View {
    let reactions: [String]
    @Binding var selectedReaction: String?

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var reactionHighlightNS

    private var allItems: [String] {
        ["Все"] + reactions
    }

    private var shouldStretchToWidth: Bool {
        allItems.count <= 4
    }

    var body: some View {
        if !reactions.isEmpty {
            Group {
                if shouldStretchToWidth {
                    HStack(spacing: 6) {
                        ForEach(allItems, id: \.self) { item in
                            reactionPillItem(
                                title: item,
                                isSelected: item == "Все" ? selectedReaction == nil : selectedReaction == item,
                                stretch: true
                            ) {
                                selectedReaction = item == "Все" ? nil : item
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allItems, id: \.self) { item in
                                reactionPillItem(
                                    title: item,
                                    isSelected: item == "Все" ? selectedReaction == nil : selectedReaction == item,
                                    stretch: false
                                ) {
                                    selectedReaction = item == "Все" ? nil : item
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(
                            .regular
                                .tint(colorScheme == .dark ? .black.opacity(0.20) : .black.opacity(0.08)),
                            in: .capsule
                        )
                } else {
                    Capsule()
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.12))
                        )
                }
            }
            .clipShape(Capsule())
        }
    }

    private func reactionPillItem(
        title: String,
        isSelected: Bool,
        stretch: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if #available(iOS 26.0, *) {
                withAnimation(.snappy(duration: 0.35, extraBounce: 0.10)) {
                    action()
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    action()
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.vertical, 10)
                .padding(.horizontal, stretch ? 8 : 14)
                .frame(maxWidth: stretch ? .infinity : nil)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: stretch ? .infinity : nil)
        .background {
            if isSelected {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(
                            .regular
                                .tint(colorScheme == .dark ? .white.opacity(0.20) : .white.opacity(0.44))
                                .interactive(),
                            in: .capsule
                        )
                        .matchedGeometryEffect(id: "reactionHighlight", in: reactionHighlightNS)
                } else {
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.10))
                        .background(.ultraThinMaterial, in: Capsule())
                        .matchedGeometryEffect(id: "reactionHighlight", in: reactionHighlightNS)
                }
            }
        }
    }
}
