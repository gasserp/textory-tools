import SwiftUI

#if os(macOS)
/// Notification names used to relay macOS menu commands (which have no
/// direct view to target) to whichever view is currently showing the
/// snippet list.
enum AppCommand {
    static let newSnippet = Notification.Name("AppCommand.newSnippet")
    static let refreshSnippets = Notification.Name("AppCommand.refreshSnippets")
}
#endif

@main
struct TextoryApp: App {
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView(authStore: authStore)
                .task {
                    await authStore.bootstrap()
                }
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 400)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Snippet") {
                    NotificationCenter.default.post(name: AppCommand.newSnippet, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: AppCommand.refreshSnippets, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #endif
    }
}
