import Foundation

public protocol ServiceKey: Hashable {}

public final class DependencyContainer: Sendable {
    public static let shared = DependencyContainer()

    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private let lock = NSRecursiveLock()

    public init() {}

    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock(); defer { lock.unlock() }
        factories[ObjectIdentifier(type)] = factory
    }

    public func resolve<T>(_ type: T.Type) -> T {
        lock.lock(); defer { lock.unlock() }
        if let service = factories[ObjectIdentifier(type)]?() as? T {
            return service
        }
        fatalError("Service \(type) not registered")
    }
}

public final class AsyncDependencyContainer: @unchecked Sendable {
    public static let shared = AsyncDependencyContainer()
    private var factories: [ObjectIdentifier: () async -> Any] = [:]
    private let lock = NSRecursiveLock()

    public func register<T>(_ type: T.Type, factory: @escaping () async -> T) {
        lock.lock(); defer { lock.unlock() }
        factories[ObjectIdentifier(type)] = factory
    }

    public func resolve<T>(_ type: T.Type) async -> T {
        lock.lock(); defer { lock.unlock() }
        guard let factory = factories[ObjectIdentifier(type)] else {
            fatalError("Service \(type) not registered")
        }
        guard let service = await factory() as? T else {
            fatalError("Service \(type) factory returned incompatible instance")
        }
        return service
    }
}
