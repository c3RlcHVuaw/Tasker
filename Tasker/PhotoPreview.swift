import SwiftUI

struct PhotoPreview: View {
    let photoData: Data
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            CachedDataImage(
                data: photoData,
                content: { image in
                    image
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
                                        withAnimation(AppAnimations.standard) {
                                            if scale <= 1 { scale = 1; offset = .zero }
                                        }
                                    }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(AppAnimations.quick) {
                                scale = scale > 1 ? 1 : 2
                            }
                        }
                },
                placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            )

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
