import SwiftUI
import UIKit

enum ChatBackgroundStorage {
    static func saveImageData(_ data: Data, replacing oldPath: String? = nil) -> String? {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.86) else {
            return nil
        }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let path = directory?.appendingPathComponent("chat_background_\(UUID().uuidString).jpg") else {
            return nil
        }

        do {
            try jpeg.write(to: path, options: .atomic)
            if let oldPath, oldPath != path.path {
                removeImage(at: oldPath)
            }
            return path.path
        } catch {
            return nil
        }
    }

    static func removeImage(at path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

struct ChatBackgroundView: View {
    let style: ChatBackgroundStyle
    let customImagePath: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch style {
                case .system:
                    Color.clear

                case .goldenPeach:
                    animatedGradient(
                        colors: [
                            Color(red: 1.00, green: 0.88, blue: 0.84),
                            Color(red: 0.98, green: 0.85, blue: 0.94),
                            Color(red: 1.00, green: 0.93, blue: 0.74)
                        ],
                        glowA: Color(red: 1.00, green: 0.60, blue: 0.48),
                        glowB: Color(red: 0.41, green: 0.70, blue: 1.00)
                    )

                case .sunsetCandy:
                    animatedGradient(
                        colors: [
                            Color(red: 1.00, green: 0.76, blue: 0.72),
                            Color(red: 0.97, green: 0.67, blue: 0.84),
                            Color(red: 1.00, green: 0.82, blue: 0.62)
                        ],
                        glowA: Color(red: 1.00, green: 0.41, blue: 0.47),
                        glowB: Color(red: 0.62, green: 0.49, blue: 1.00)
                    )

                case .mintSky:
                    animatedGradient(
                        colors: [
                            Color(red: 0.78, green: 0.94, blue: 0.90),
                            Color(red: 0.78, green: 0.90, blue: 1.00),
                            Color(red: 0.94, green: 0.97, blue: 0.84)
                        ],
                        glowA: Color(red: 0.26, green: 0.82, blue: 0.76),
                        glowB: Color(red: 0.39, green: 0.61, blue: 1.00)
                    )

                case .custom:
                    customBackground
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var customBackground: some View {
        if let image = UIImage(contentsOfFile: customImagePath), !customImagePath.isEmpty {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                    .clipped()
                    .overlay(Color.black.opacity(0.12))
            }
            .id(customImagePath)
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            Color.clear
        }
    }

    private func animatedGradient(colors: [Color], glowA: Color, glowB: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phaseA = sin(t * 0.45)
            let phaseB = cos(t * 0.31)

            let gradientStart = UnitPoint(
                x: 0.18 + 0.12 * phaseA,
                y: 0.08 + 0.08 * phaseB
            )
            let gradientEnd = UnitPoint(
                x: 0.82 - 0.10 * phaseB,
                y: 0.92 - 0.10 * phaseA
            )

            let glowCenterA = UnitPoint(
                x: 0.20 + 0.16 * phaseB,
                y: 0.18 + 0.12 * phaseA
            )
            let glowCenterB = UnitPoint(
                x: 0.82 - 0.18 * phaseA,
                y: 0.78 - 0.16 * phaseB
            )

            ZStack {
                LinearGradient(colors: colors, startPoint: gradientStart, endPoint: gradientEnd)

                RadialGradient(
                    colors: [glowA.opacity(0.30), .clear],
                    center: glowCenterA,
                    startRadius: 24,
                    endRadius: 340
                )

                RadialGradient(
                    colors: [glowB.opacity(0.26), .clear],
                    center: glowCenterB,
                    startRadius: 18,
                    endRadius: 320
                )

                LinearGradient(
                    colors: [
                        .white.opacity(0.18),
                        .clear,
                        .white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
        }
    }
}
