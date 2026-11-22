import Foundation
import Observation
import os

/// Central place where recoverable errors are logged and surfaced to the user (in French).
@MainActor
@Observable
final class ErrorReporter {
    static let shared = ErrorReporter()

    struct Item: Identifiable {
        let id = UUID()
        let message: String
        let detail: String
    }

    var current: Item?
    private let logger = Logger(subsystem: "com.sabri68.fittrack", category: "errors")

    func report(_ error: Error, message: String) {
        logger.error("\(message, privacy: .public) – \(error.localizedDescription, privacy: .public)")
        current = Item(message: message, detail: error.localizedDescription)
    }

    func report(message: String) {
        logger.error("\(message, privacy: .public)")
        current = Item(message: message, detail: "")
    }
}
