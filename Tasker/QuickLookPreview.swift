import SwiftUI
import QuickLook

struct QuickLookPreview: UIViewControllerRepresentable {
    let data: Data
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(data: data, onClose: onClose)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator

        // embed in navigation controller to show native close button
        let nav = UINavigationController(rootViewController: controller)
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: context.coordinator,
            action: #selector(Coordinator.closeTapped)
        )
        return nav
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // nothing
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let fileURL: URL?
        private let onClose: () -> Void

        init(data: Data, onClose: @escaping () -> Void) {
            // write to temp file
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileName = "preview_\(UUID().uuidString).jpg"
            let url = tempDir.appendingPathComponent(fileName)
            try? data.write(to: url)
            self.fileURL = url
            self.onClose = onClose
            super.init()
        }

        deinit {
            if let fileURL = fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return fileURL == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            return fileURL! as QLPreviewItem
        }

        @objc func closeTapped() {
            DispatchQueue.main.async {
                self.onClose()
            }
        }
    }
}

struct QuickLookContainer: View {
    let data: Data
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QuickLookPreview(data: data, onClose: onClose)
                .edgesIgnoringSafeArea(.all)

            Button(action: {
                onClose()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(16)
            }
        }
    }
}
