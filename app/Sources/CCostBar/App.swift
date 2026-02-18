import AppKit

@main
struct CCostBarApp {
    @MainActor static var controller: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        controller = StatusBarController()
        app.run()
    }
}
