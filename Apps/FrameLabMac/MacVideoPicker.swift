#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Native macOS NSOpenPanel and NSSavePanel helpers.
@MainActor
public enum MacFilePicker {
    /// Presents an NSOpenPanel to select a local video file.
    public static func pickVideoFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .movie,
            .video,
            .quickTimeMovie,
            .mpeg4Movie
        ]
        panel.title = "Select Video File — FrameLab"
        panel.prompt = "Open Video"

        let response = panel.runModal()
        return (response == .OK) ? panel.url : nil
    }

    /// Presents an NSSavePanel to export the current frame.
    public static func pickExportLocation(defaultName: String = "FrameLab_Export.png") -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.png, .jpeg]
        panel.title = "Export Processed Frame — FrameLab"
        panel.prompt = "Save Frame"

        let response = panel.runModal()
        return (response == .OK) ? panel.url : nil
    }
}
#endif
