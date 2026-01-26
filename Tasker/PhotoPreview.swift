import SwiftUI

struct PhotoPreview: View {
    let photoData: Data
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                            .simultaneously(with: DragGesture()
                                .onChanged { g in
                                    offset = g.translation
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        if scale <= 1 { scale = 1; offset = .zero }
                                    }
                                }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }
            } else {
                Text("Error loading image")
                    .foregroundColor(.white)
            }

            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
