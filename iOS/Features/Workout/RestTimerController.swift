import Foundation
import Observation
import UIKit
import UserNotifications

/// Rest countdown between sets. Based on an end date so it keeps running in the background;
/// a local notification announces the end of the rest when the app is not in the foreground.
@MainActor
@Observable
final class RestTimerController {
    private(set) var endDate: Date?
    private(set) var totalSeconds: Int = 0
    private var finishTask: Task<Void, Never>?
    private static let notificationID = "fittrack.rest"

    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(date))
    }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        totalSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        schedule()
    }

    func add(_ seconds: Int) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= .now { stop(); return }
        self.endDate = newEnd
        totalSeconds = max(1, totalSeconds + seconds)
        schedule()
    }

    func stop() {
        endDate = nil
        finishTask?.cancel()
        finishTask = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func schedule() {
        finishTask?.cancel()
        let remaining = self.remaining()
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.endDate = nil
        }
        scheduleNotification(after: remaining)
    }

    private func scheduleNotification(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard seconds >= 1, !Persistence.isAnyUITest else { return }
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Repos terminé"
            content.body = "C'est reparti pour la série suivante 💪"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
        }
    }
}
