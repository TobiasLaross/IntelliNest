//
//  LogExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-03-11.
//

import Foundation
import ShipBookSDK

extension Log {
    @MainActor
    static var user: String {
        UserManager.currentUser.rawValue
    }

    static func info(_ message: String,
                     tag: String? = nil,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line) {
        Task { @MainActor in
            Log.i("\(user): \(message)",
                  tag: tag,
                  function: function,
                  file: file,
                  line: line)
        }
    }

    static func error(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        Task { @MainActor in
            Log.e("\(user): \(message)",
                  tag: tag,
                  function: function,
                  file: file,
                  line: line)
        }
    }

    static func warning(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        Task { @MainActor in
            Log.w("\(user): \(message)",
                  tag: tag,
                  function: function,
                  file: file,
                  line: line)
        }
    }

    static func debug(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        Task { @MainActor in
            Log.d("\(user): \(message)",
                  tag: tag,
                  function: function,
                  file: file,
                  line: line)
        }
    }

    static func verbose(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        Task { @MainActor in
            Log.v("\(user): \(message)",
                  tag: tag,
                  function: function,
                  file: file,
                  line: line)
        }
    }
}
