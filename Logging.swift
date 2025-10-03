import Foundation

public enum LogCategory: String {
    case security
    case storage
    case assistant
    case vital
    case ui
}

public protocol Logger: Sendable {
    func log(_ message: @autoclosure () -> String, category: LogCategory, file: StaticString, line: UInt)
    func error(_ message: @autoclosure () -> String, category: LogCategory, file: StaticString, line: UInt)
}

public struct AppLogger: Logger {
    private let queue = DispatchQueue(label: "AppLoggerQueue", qos: .utility)
    private let privacyRedactor: (String) -> String

    public init(privacyRedactor: @escaping (String) -> String = { _ in "[REDACTED]" }) {
        self.privacyRedactor = privacyRedactor
    }

    public func log(_ message: @autoclosure () -> String, category: LogCategory, file: StaticString = #filePath, line: UInt = #line) {
        queue.async {
            #if DEBUG
            print("ℹ️ [\(category.rawValue.uppercased())] \(message())")
            #endif
        }
    }

    public func error(_ message: @autoclosure () -> String, category: LogCategory, file: StaticString = #filePath, line: UInt = #line) {
        queue.async {
            #if DEBUG
            print("❗️ [\(category.rawValue.uppercased())] \(privacyRedactor(message()))")
            #endif
        }
    }
}
