#if os(iOS)
import SwiftUI

@main
struct FrameLabIOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSContentView()
        }
    }
}
#endif
