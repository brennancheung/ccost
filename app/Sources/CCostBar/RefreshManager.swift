import Foundation

@MainActor
final class RefreshManager {
    private var timer: Timer?
    private let onRefresh: @MainActor () -> Void

    init(onRefresh: @MainActor @escaping () -> Void) {
        self.onRefresh = onRefresh
    }

    func start(seconds: Int) {
        stop()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(seconds),
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.onRefresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
