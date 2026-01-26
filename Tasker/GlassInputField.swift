import SwiftUI
import PhotosUI

struct GlassInputField: View {
    @Binding var text: String
    @Binding var photos: [Data]
    var placeholder: String = "Создать задачу"
    var onSubmit: (() -> Void)?
    @State private var isFocused = false

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Photo picker button - appears only when focused
                if isFocused {
                    PhotoPickerButton(selectedPhotos: $selectedPhotos, photosCount: photos.count)
                        .transition(
                            .asymmetric(
                                insertion: .smoothCombined(scale: 0.7, opacity: 0.0),
                                removal: .smoothCombined(scale: 0.7, opacity: 0.0)
                            )
                        )
                        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isFocused)
                }

                // Input field with photos
                InputFieldContent(
                    text: $text,
                    photos: $photos,
                    placeholder: placeholder,
                    isFocused: $isFocused,
                    onSubmit: onSubmit
                )

                // Send button
                if isFocused || !text.isEmpty || !photos.isEmpty {
                    SendButton(onSubmit: onSubmit, isDisabled: text.isEmpty && photos.isEmpty)
                        .transition(
                            .asymmetric(
                                insertion: .smoothCombined(scale: 0.7, opacity: 0.0),
                                removal: .smoothCombined(scale: 0.7, opacity: 0.0)
                            )
                        )
                        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isFocused)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: text)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: photos.count)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .offset(y: dragOffset * 0.5)
        .background(Color.clear)
        .ignoresSafeArea(.keyboard)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 60 {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    dragOffset = 0
                }
        )
        .onChange(of: selectedPhotos) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if photos.count < 10 {
                            photos.insert(data, at: 0)
                        }
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
}

// MARK: - Photo Picker Button
struct PhotoPickerButton: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    let photosCount: Int

    var body: some View {
        PhotosPicker(
            selection: $selectedPhotos,
            maxSelectionCount: 10 - photosCount,
            matching: .images
        ) {
            Image(systemName: "paperclip")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(width: 44, height: 44)
        .background {
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular, in: .circle)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.2))
                    )
            }
        }
    }
}

// MARK: - Input Field Content
struct InputFieldContent: View {
    @Binding var text: String
    @Binding var photos: [Data]
    let placeholder: String
    @FocusState private var focusState: Bool
    @Binding var isFocused: Bool
    var onSubmit: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Inline photos
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(photos, id: \.self) { photoData in
                            if let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button(action: {
                                            photos.removeAll { $0 == photoData }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(2)
                                    }
                            }
                        }
                    }
                }
            }

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...3)
                .focused($focusState)
                .font(.system(.body, design: .rounded))
                .textFieldStyle(.plain)
                .submitLabel(.return)
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: focusState) { newValue in
                    isFocused = newValue
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(.white.opacity(0.2))
                    )
            }
        }
    }
}

// MARK: - Send Button
struct SendButton: View {
    var onSubmit: (() -> Void)?
    let isDisabled: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                onSubmit?()
            }
        }) {
            ZStack {
                if #available(iOS 26.0, *) {
                    if isDisabled {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Circle()
                            .fill(Color.blue)
                    }
                } else {
                    Circle()
                        .fill(isDisabled ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.blue))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                }

                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDisabled ? Color.gray.opacity(0.4) : .white)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Smooth Transition
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
