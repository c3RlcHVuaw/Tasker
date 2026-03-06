import SwiftUI

struct LoadingView: View {
    @State private var drift = false
    @State private var pulse = false
    @State private var spin = false

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            decorativeLayer

            VStack(spacing: 28) {
                appBadge

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 148, height: 148)
                        .scaleEffect(pulse ? 1.06 : 0.94)
                        .opacity(pulse ? 0.15 : 0.45)
                        .blur(radius: 0.5)

                    Circle()
                        .trim(from: 0.10, to: 0.90)
                        .stroke(
                            AngularGradient(
                                colors: [.white.opacity(0.15), .white, .white.opacity(0.25), .white],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 122, height: 122)
                        .rotationEffect(.degrees(spin ? 360 : 0))

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.48), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
                        .frame(width: 112, height: 112)
                        .overlay {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.88))
                        }
                        .scaleEffect(pulse ? 1.04 : 0.96)
                }

                VStack(spacing: 8) {
                    Text("Загрузка Tasker")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.86))
                    Text("Подготавливаем задачи и медиа")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.52))
                }
            }
            .padding(.bottom, 34)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                drift = true
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.88, blue: 0.84),
                Color(red: 0.98, green: 0.83, blue: 0.90),
                Color(red: 1.00, green: 0.93, blue: 0.72)
            ],
            startPoint: drift ? .topLeading : .bottomTrailing,
            endPoint: drift ? .bottomTrailing : .topLeading
        )
        .overlay {
            RadialGradient(
                colors: [
                    Color(red: 0.99, green: 0.58, blue: 0.52).opacity(0.36),
                    .clear
                ],
                center: .init(x: drift ? 0.18 : 0.82, y: drift ? 0.20 : 0.74),
                startRadius: 60,
                endRadius: 340
            )
        }
        .overlay {
            RadialGradient(
                colors: [
                    Color(red: 0.37, green: 0.67, blue: 1.00).opacity(0.26),
                    .clear
                ],
                center: .init(x: drift ? 0.82 : 0.20, y: drift ? 0.82 : 0.24),
                startRadius: 50,
                endRadius: 320
            )
        }
    }

    private var appBadge: some View {
        Text("Tasker")
            .font(.system(size: 24, weight: .heavy, design: .rounded))
            .foregroundStyle(.black.opacity(0.82))
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 0.86, green: 0.95, blue: 0.16))
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private var decorativeLayer: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                floatingOrb(symbol: "sun.max.fill", tint: .yellow)
                    .offset(
                        x: width * 0.24,
                        y: drift ? height * 0.21 : height * 0.25
                    )
                floatingOrb(symbol: "bolt.fill", tint: .pink)
                    .offset(
                        x: width * 0.76,
                        y: drift ? height * 0.26 : height * 0.21
                    )
                floatingOrb(symbol: "sparkles", tint: .mint)
                    .offset(
                        x: width * 0.22,
                        y: drift ? height * 0.75 : height * 0.70
                    )
                floatingOrb(symbol: "moon.stars.fill", tint: .purple)
                    .offset(
                        x: width * 0.78,
                        y: drift ? height * 0.72 : height * 0.76
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func floatingOrb(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.46), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
        }
        .scaleEffect(pulse ? 1.04 : 0.94)
    }
}

#Preview {
    LoadingView()
}
