import AppIntents
import Foundation

struct AddReminderIntent: AppIntent {
  static var title: LocalizedStringResource = "Add a reminder"

  @Parameter(title: "Reminder")
  var reminder: String?

  func perform() async throws -> some ProvidesDialog {
    var text = self.reminder
    if text == nil {
      text = try await $reminder.requestValue("What would you like to be reminded about?")
    }
    _ = try await Backend.shared.commit(command: text!)
    return .result(dialog: "OK. I've added a reminder.")
  }
}

struct AddReminderShortcut: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddReminderIntent(),
      phrases: [
        "Add a reminder in \(.applicationName)",
        "Add a reminder to \(.applicationName)",
        "\(.applicationName) to \(\.$reminder)",
        "Remind me to \(\.$reminder) in \(.applicationName)"
      ],
      shortTitle: "Add Reminder",
      systemImageName: "plus.app"
    )
  }
}
