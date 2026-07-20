import Foundation
import Observation
import SwiftData

struct AppIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class AppErrorCenter {
    var issue: AppIssue?

    func report(_ error: Error, title: String = "Не удалось сохранить изменения") {
        issue = AppIssue(
            title: title,
            message: "Попробуйте ещё раз. Если ошибка повторится, перезапустите приложение.\n\n\(error.localizedDescription)"
        )
    }

    func report(title: String, message: String) {
        issue = AppIssue(title: title, message: message)
    }
}

@MainActor
extension ModelContext {
    @discardableResult
    func save(reportingTo errors: AppErrorCenter) -> Bool {
        do {
            try save()
            return true
        } catch {
            errors.report(error)
            return false
        }
    }
}
