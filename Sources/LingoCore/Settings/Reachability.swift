import Foundation
import Network

/// Есть ли сеть (S-17, R-33): без сети на Mac доступна только история, подсказки, словарь и прослушивание фраз.
public final class Reachability: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "lingo.reachability")
    public var onChange: (@Sendable (Bool) -> Void)?
    public private(set) var isOnline = true

    public init() {}

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            self?.isOnline = up
            self?.onChange?(up)
        }
        monitor.start(queue: queue)
    }

    public func stop() { monitor.cancel() }
}
