import Foundation

@MainActor
protocol Reloadable: AnyObject {
    var isReloading: Bool { get set }
}

extension Reloadable {
    func withReloadGuard(_ work: @MainActor () async -> Void) async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        await work()
    }
}
