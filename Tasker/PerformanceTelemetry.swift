import Foundation
import os

enum PerformanceTelemetry {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Tasker"
    private static let logger = Logger(subsystem: subsystem, category: "Performance")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "Performance")

    static func measure<T>(_ name: StaticString, _ operation: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let signpostState = signposter.beginInterval(name)
        let value = operation()
        signposter.endInterval(name, signpostState)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("\(name, privacy: .public) took \(elapsedMs, format: .fixed(precision: 2)) ms")
        return value
    }

    static func event(_ message: StaticString) {
        logger.debug("\(message, privacy: .public)")
    }

    static func countEvent(_ message: StaticString, count: Int) {
        logger.debug("\(message, privacy: .public): \(count)")
    }
}
