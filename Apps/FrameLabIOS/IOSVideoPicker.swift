#if os(iOS)
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// PhotosPicker helper for iOS video selection.
public struct IOSPhotosVideoPickerView: View {
    @Binding public var selectedItem: PhotosPickerItem?
    public let onVideoSelected: (URL) -> Void

    public init(
        selectedItem: Binding<PhotosPickerItem?>,
        onVideoSelected: @escaping (URL) -> Void
    ) {
        self._selectedItem = selectedItem
        self.onVideoSelected = onVideoSelected
    }

    public var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            Label("Photos Library", systemImage: "photo.on.rectangle")
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
                    onVideoSelected(movie.url)
                }
            }
        }
    }
}

/// Transferable movie wrapper for loading video files from PhotosPicker.
public struct MovieTransferable: Transferable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.copyItem(at: received.file, to: targetURL)
            return Self(url: targetURL)
        }
    }
}
#endif
