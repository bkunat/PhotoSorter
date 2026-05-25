//
//  PhotoSorter
//

import Foundation
import OSLog

enum AppLogLevel {
    case debug
    case info
    case notice
    case error
    case fault
}

enum AppLogCategory: Hashable, Sendable {
    case app
    case session
    case ui
    case fileSystem
    case performance
    case custom(String)

    var name: String {
        switch self {
        case .app:
            "App"
        case .session:
            "Session"
        case .ui:
            "UI"
        case .fileSystem:
            "FileSystem"
        case .performance:
            "Performance"
        case let .custom(value):
            value
        }
    }
}

private final class LoggerCache: @unchecked Sendable {
    private let subsystem: String
    private let queue = DispatchQueue(label: "PhotoSorter.AppLogger.Cache")
    private var cache: [String: Logger] = [:]

    init(subsystem: String) {
        self.subsystem = subsystem
    }

    func logger(for category: AppLogCategory) -> Logger {
        let name = category.name
        return queue.sync {
            if let logger = cache[name] {
                return logger
            }

            let logger = Logger(subsystem: subsystem, category: name)
            cache[name] = logger
            return logger
        }
    }
}

enum AppLogger {
    struct Stopwatch: Sendable {
        private let start = DispatchTime.now()

        var elapsedMilliseconds: Int {
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            return Int(elapsedNanoseconds / 1_000_000)
        }
    }

    struct Measurement<T> {
        let value: T
        let durationMilliseconds: Int
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bkunat.PhotoSorter"
    private static let cache = LoggerCache(subsystem: subsystem)

    static func debug(
        _ message: @autoclosure () -> String,
        category: AppLogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message(), category: category, file: file, function: function, line: line)
    }

    static func info(
        _ message: @autoclosure () -> String,
        category: AppLogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message(), category: category, file: file, function: function, line: line)
    }

    static func notice(
        _ message: @autoclosure () -> String,
        category: AppLogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.notice, message(), category: category, file: file, function: function, line: line)
    }

    static func error(
        _ message: @autoclosure () -> String,
        category: AppLogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message(), category: category, file: file, function: function, line: line)
    }

    static func fault(
        _ message: @autoclosure () -> String,
        category: AppLogCategory = .app,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.fault, message(), category: category, file: file, function: function, line: line)
    }

    static func measure<T>(
        _ name: StaticString,
        category: AppLogCategory = .performance,
        _ operation: () throws -> T
    ) rethrows -> Measurement<T> {
        let stopwatch = Stopwatch()
        let value = try operation()
        let durationMilliseconds = stopwatch.elapsedMilliseconds
        log(
            .debug,
            "\(name) completed in \(durationMilliseconds) ms",
            category: category,
            file: #fileID,
            function: #function,
            line: #line
        )
        return Measurement(value: value, durationMilliseconds: durationMilliseconds)
    }

    private static func log(
        _ level: AppLogLevel,
        _ message: String,
        category: AppLogCategory,
        file: String,
        function: String,
        line: Int
    ) {
        let logger = cache.logger(for: category)

        #if DEBUG
            let payload = "\(message) [\(file):\(line) \(function)]"
        #else
            let payload = message
        #endif

        switch level {
        case .debug:
            logger.debug("\(payload, privacy: .public)")
        case .info:
            logger.info("\(payload, privacy: .public)")
        case .notice:
            logger.notice("\(payload, privacy: .public)")
        case .error:
            logger.error("\(payload, privacy: .public)")
        case .fault:
            logger.fault("\(payload, privacy: .public)")
        }
    }
}
