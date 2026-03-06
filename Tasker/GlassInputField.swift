import SwiftUI
import PhotosUI

struct GlassInputField: View {
    struct DraftPhoto: Identifiable, Equatable {
        let id = UUID()
        let data: Data
    }

    var placeholder: String = "Создать задачу"
    var onSubmit: ((String, [Data], TaskRecurrence) -> Void)?
    @State private var isFocused = false

    @State private var text = ""
    @State private var photos: [DraftPhoto] = []
    @State private var recurrence: TaskRecurrence = .none
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var dragOffset: CGFloat = 0
    @State private var photoLoadingTask: Task<Void, Never>?
    
    private var showsSendButton: Bool {
        isFocused || !text.isEmpty || !photos.isEmpty
    }
    
    private var controlsAnimation: Animation {
        AppAnimations.standard
    }

    private var contentAnimation: Animation {
        AppAnimations.fade
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
                    onSubmit: submitDraft
                )

                if showsSendButton {
                    SendButton(
                        recurrence: $recurrence,
                        onSubmit: submitDraft,
                        isDisabled: text.isEmpty && photos.isEmpty
                    )
                        .transition(.move(edge: .trailing).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .animation(controlsAnimation, value: isFocused)
        }
        .offset(y: dragOffset * 0.5)
        .background(Color.clear)
        .ignoresSafeArea(.keyboard)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if isFocused, value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if isFocused, value.translation.height > 60 {
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
                let availableSlots = max(0, 10 - photos.count)
                guard availableSlots > 0 else { return }
                var loaded: [DraftPhoto] = []
                loaded.reserveCapacity(min(newItems.count, availableSlots))

                for item in newItems {
                    if Task.isCancelled { break }
                    if loaded.count >= availableSlots { break }
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(DraftPhoto(data: data))
                    }
                }
                await MainActor.run {
                    if !loaded.isEmpty {
                        withAnimation(contentAnimation) {
                            photos.insert(contentsOf: loaded.reversed(), at: 0)
                        }
                    }
                    selectedPhotos.removeAll()
                }
            }
        }
    }

    private func submitDraft() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !photos.isEmpty else { return }
        onSubmit?(text, photos.map(\.data), recurrence)
        text = ""
        photos.removeAll(keepingCapacity: true)
        recurrence = .none
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
    @Binding var photos: [GlassInputField.DraftPhoto]
    let placeholder: String
    @FocusState private var focusState: Bool
    @Binding var isFocused: Bool
    var onSubmit: (() -> Void)?
    
    private var contentAnimation: Animation {
        AppAnimations.fade
    }

    var body: some View {
        VStack(spacing: 8) {
            // Inline photos
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(photos) { photo in
                            CachedDataImage(
                                data: photo.data,
                                maxPixelSize: 48,
                                content: { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button(action: {
                                                withAnimation(contentAnimation) {
                                                    photos.removeAll(where: { $0.id == photo.id })
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
                    .frame(height: 52, alignment: .leading)
                }
                .frame(height: 52)
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
                .onChange(of: focusState) { _, newValue in
                    withAnimation(contentAnimation) {
                        isFocused = newValue
                    }
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
    @Binding var recurrence: TaskRecurrence
    var onSubmit: (() -> Void)?
    let isDisabled: Bool
    
    private var tapAnimation: Animation {
        AppAnimations.quick
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
        .contextMenu {
            ForEach(TaskRecurrence.allCases, id: \.rawValue) { item in
                Button {
                    recurrence = item
                } label: {
                    HStack {
                        Text(item.title)
                        if recurrence == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    private var pressAnimation: Animation {
        AppAnimations.press
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(pressAnimation, value: configuration.isPressed)
    }
}
