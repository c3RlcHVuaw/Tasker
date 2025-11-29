import SwiftUI

/// Иконка как в макете
struct CheckIconBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 64, height: 64)

            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)

            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

/// Кнопка "жидкое стекло" на базе .glassEffect() из iOS 26
struct LiquidGlassButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonBorderShape(.capsule)     // форма пилюли
        .glassEffect()                   // НОВЫЙ компонент iOS 26
    }
}
