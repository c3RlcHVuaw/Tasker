import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.98),
                    Color(red: 0.98, green: 0.94, blue: 0.96)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background shapes
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(red: 0.9, green: 0.85, blue: 0.95).opacity(0.6))
                    .frame(width: 200)
                    .offset(x: -120, y: -100)
                    .blur(radius: 40)
                
                Spacer()
                
                Circle()
                    .fill(Color(red: 0.85, green: 0.95, blue: 0.92).opacity(0.6))
                    .frame(width: 250)
                    .offset(x: 100, y: 50)
                    .blur(radius: 40)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Tasker")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.4))
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    LoadingView()
}
