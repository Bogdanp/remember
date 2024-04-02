import Foundation
import SwiftUI

extension UIDevice {
  static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
      NotificationCenter.default.post(
        name: UIDevice.deviceDidShakeNotification,
        object: event)
    } else {
      super.motionEnded(motion, with: event)
    }
  }
}

struct DeviceShakeViewModifier: ViewModifier {
  let action: (UIEvent?) -> Void

  func body(content: Content) -> some View {
    content.onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { notification in
      action(notification.object as? UIEvent )
    }
  }
}

extension View {
  func onShake(perform action: @escaping (UIEvent?) -> Void) -> some View {
    self.modifier(DeviceShakeViewModifier(action: action))
  }
}
