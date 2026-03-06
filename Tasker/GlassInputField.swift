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
    @State private var photoLoadingTask: Task<Void, Never>?
    
    private var showsSendButton: Bool {
        isFocused || !text.isEmpty || !photos.isEmpty
    }
    
    private var controlsAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .bouncy(duration: 0.32, extraBounce: 0.08)
        } else {
            return .spring(response: 0.34, dampingFraction: 0.84)
        }
    }

    private var contentAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .smooth(duration: 0.22)
        } else {
            return .easeInOut(duration: 0.22)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isFocused {
                    PhotoPickerButton(selectedPhotos: $selectedPhotos, photosCount: photos.count)
                        .transition(.move(edge: .leading).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                }

                // Input field with photos
                InputFieldContent(
                    text: $text,
                    photos: $photos,
                    placeholder: placeholder,
                    isFocused: $isFocused,
                    onSubmit: onSubmit
                )

                if showsSendButton {
                    SendButton(onSubmit: onSubmit, isDisabled: text.isEmpty && photos.isEmpty)
                        .transition(.move(edge: .trailing).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .animation(controlsAnimation, value: isFocused)
            .animation(controlsAnimation, value: showsSendButton)
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
                    withAnimation(controlsAnimation) {
                        dragOffset = 0
                    }
                }
        )
        .onDisappear {
            photoLoadingTask?.cancel()
        }
        .onChange(of: selectedPhotos) { _, newItems in
            photoLoadingTask?.cancel()
            photoLoadingTask = Task {
                for item in newItems {
                    if Task.isCancelled { break }
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if photos.count < 10 {
                            await MainActor.run {
                                withAnimation(contentAnimation) {
                                    photos.insert(data, at: 0)
                                }
                            }
                        }
                    }
                }
                await MainActor.run {
                    selectedPhotos.removeAll()
                }
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
    
    private var contentAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .smooth(duration: 0.22)
        } else {
            return .easeInOut(duration: 0.22)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Inline photos
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                            CachedDataImage(
                                data: photoData,
                                maxPixelSize: 48,
                                content: { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button(action: {
                                                guard photos.indices.contains(index) else { return }
                                                withAnimation(contentAnimation) {
                                                    photos.remove(at: index)
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                            .padding(2)
                                        }
                                },
                                placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                }
                            )
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
                    withAnimation(contentAnimation) {
                        isFocused = newValue
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(contentAnimation, value: photos.count)
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
    
    private var tapAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .snappy(duration: 0.22, extraBounce: 0.06)
        } else {
            return .spring(response: 0.35, dampingFraction: 0.6)
        }
    }

    var body: some View {
        Button(action: {
            withAnimation(tapAnimation) {
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
    private var pressAnimation: Animation {
        if #available(iOS 26.0, *) {
            return .bouncy(duration: 0.22, extraBounce: 0.08)
        } else {
            return .spring(response: 0.35, dampingFraction: 0.6)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(pressAnimation, value: configuration.isPressed)
    }
}
