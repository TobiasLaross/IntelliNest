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
    }

    private static func output(_ level: Level, _ message: String, tag: String?, source: Source) {
        Task { @MainActor in
            let fileName = (source.file as NSString).lastPathComponent
            let tagPart = tag.map { value in "[\(value)] " } ?? ""
            let formatted = "[\(level.rawValue)] \(tagPart)\(fileName):\(source.line) \(source.function) - \(user): \(message)"
            logger.log(level: level.osLogType, "\(formatted, privacy: .public)")
        }
    }
}
