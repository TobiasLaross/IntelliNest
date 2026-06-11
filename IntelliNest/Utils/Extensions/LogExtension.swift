//
//  LogExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-03-11.
//

import Foundation
import OSLog

enum Log {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "IntelliNest", category: "App")

    /// Forwards error and warning logs to Home Assistant so the app's logs live in the
    /// same place as HA's own. Wired up by `Navigator` once `RestAPIService` exists; the
    /// level is an HA `system_log` level string ("error"/"warning") and the message is the
    /// same formatted line sent to os.log.
    @MainActor
    static var remoteReporter: ((_ level: String, _ message: String) -> Void)?

    /// An identical message is only forwarded once per this window, so a failure that
    /// recurs on every 5-second reload doesn't flood Home Assistant's log.
    private static let remoteReportCooldown: TimeInterval = 60
    @MainActor
    private static var recentRemoteReports: [String: Date] = [:]

    @MainActor
    static var user: String {
        UserManager.currentUser.rawValue
    }

    static func info(_ message: String,
                     tag: String? = nil,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line) {
        output(.info, message, tag: tag, source: Source(function: function, file: file, line: line))
    }

    static func error(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        output(.error, message, tag: tag, source: Source(function: function, file: file, line: line))
    }

    static func warning(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        output(.warning, message, tag: tag, source: Source(function: function, file: file, line: line))
    }

    static func debug(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        output(.debug, message, tag: tag, source: Source(function: function, file: file, line: line))
    }

    static func verbose(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        output(.verbose, message, tag: tag, source: Source(function: function, file: file, line: line))
    }

    private struct Source {
        let function: String
        let file: String
        let line: Int
    }

    private enum Level: String {
        case info = "INFO"
        case error = "ERROR"
        case warning = "WARNING"
        case debug = "DEBUG"
        case verbose = "VERBOSE"

        var osLogType: OSLogType {
            switch self {
            case .info: .info
            case .error: .error
            case .warning: .default
            case .debug: .debug
            case .verbose: .debug
            }
        }

        /// The matching Home Assistant `system_log` level, or nil for levels that are not
        /// forwarded to HA (info/debug/verbose).
        var homeAssistantLevel: String? {
            switch self {
            case .error: "error"
            case .warning: "warning"
            default: nil
            }
        }
    }

    private static func output(_ level: Level, _ message: String, tag: String?, source: Source) {
        Task { @MainActor in
            let fileName = (source.file as NSString).lastPathComponent
            let tagPart = tag.map { value in "[\(value)] " } ?? ""
            let formatted = "[\(level.rawValue)] \(tagPart)\(fileName):\(source.line) \(source.function) - \(user): \(message)"
            logger.log(level: level.osLogType, "\(formatted, privacy: .public)")
            reportToHomeAssistantIfNeeded(level: level, formatted: formatted)
        }
    }

    @MainActor
    private static func reportToHomeAssistantIfNeeded(level: Level, formatted: String) {
        guard let homeAssistantLevel = level.homeAssistantLevel,
              let remoteReporter,
              shouldForwardRemotely(formatted) else {
            return
        }
        remoteReporter(homeAssistantLevel, formatted)
    }

    @MainActor
    private static func shouldForwardRemotely(_ message: String) -> Bool {
        let now = Date()
        recentRemoteReports = recentRemoteReports.filter { now.timeIntervalSince($0.value) < remoteReportCooldown }
        if let lastSent = recentRemoteReports[message], now.timeIntervalSince(lastSent) < remoteReportCooldown {
            return false
        }
        recentRemoteReports[message] = now
        return true
    }

    /// Test seam: clears the remote reporter and dedupe cache between tests.
    @MainActor
    static func resetRemoteReporting() {
        remoteReporter = nil
        recentRemoteReports.removeAll()
    }
}
