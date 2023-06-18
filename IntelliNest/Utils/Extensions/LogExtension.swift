//
//  LogExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-03-11.
//

import Foundation
import ShipBookSDK

extension Log {
    static var user: String {
        return UserDefaults.standard.string(forKey: "UserShort") ?? "Unknown user"
    }

    static func info(_ message: String,
                     tag: String? = nil,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line) {
        Log.i("\(user): \(message)",
              tag: tag,
              function: function,
              file: file,
              line: line)
    }

    static func error(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        Log.e("\(user): \(message)",
              tag: tag,
              function: function,
              file: file,
              line: line)
    }

    static func warning(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        Log.w("\(user): \(message)",
              tag: tag,
              function: function,
              file: file,
              line: line)
    }

    static func debug(_ message: String,
                      tag: String? = nil,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line) {
        Log.d("\(user): \(message)",
              tag: tag,
              function: function,
              file: file,
              line: line)
    }

    static func verbose(_ message: String,
                        tag: String? = nil,
                        function: String = #function,
                        file: String = #file,
                        line: Int = #line) {
        Log.v("\(user): \(message)",
              tag: tag,
              function: function,
              file: file,
              line: line)
    }
}
