#if os(macOS)
import SwiftUI

@main
struct FrameLabMacApp: App {
    var body: some Scene {
        WindowGroup {
            MacContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
#endif
