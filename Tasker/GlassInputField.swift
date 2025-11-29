import SwiftUI

struct GlassInputField: View {
    @Binding var text: String
    var placeholder: String = "Создать задачу"
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    @Namespace private var buttonNamespace

    var body: some View {
        HStack(spacing: 10) {
            // MARK: - Инпут
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .font(.system(.body, design: .rounded))
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .glassEffect(.regular.tint(.clear).interactive(), in: .rect(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white.opacity(0.2))
                )

            // MARK: - Кнопка отправки
            if isFocused || !text.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        onSubmit()
                    }
                }) {
                    ZStack {
                        if #available(iOS 18.0, *) {
                            Circle()
                                .glassEffect(
                                    .regular
                                        .tint(text.isEmpty ? .clear : .blue)
                                        .interactive(),
                                    in: .circle
                                )
                        } else {
                            Circle()
                                .fill(text.isEmpty ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.blue))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        }

                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(text.isEmpty ? .gray.opacity(0.4) : .white)
                    }
                    .frame(width: 44, height: 44)
                    .matchedGeometryEffect(id: "sendButton", in: buttonNamespace)
                }
                .buttonStyle(PressableButtonStyle())
                .transition(
                    .asymmetric(
                        insertion: .smoothCombined(scale: 0.7, opacity: 0.0),
                        removal: .smoothCombined(scale: 0.7, opacity: 0.0)
                    )
                )
                .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isFocused)
                .animation(.spring(response: 0.55, dampingFraction: 0.75), value: text)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Эффект отскока при нажатии
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Расширение для плавного “жидкого” перехода
extension AnyTransition {
    static func smoothCombined(scale: CGFloat, opacity: CGFloat) -> AnyTransition {
        .modifier(
            active: SmoothAppearModifier(scale: scale, opacity: opacity),
            identity: SmoothAppearModifier(scale: 1, opacity: 1)
        )
    }
}

struct SmoothAppearModifier: ViewModifier {
    var scale: CGFloat
    var opacity: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(Double(opacity))
    }
}
