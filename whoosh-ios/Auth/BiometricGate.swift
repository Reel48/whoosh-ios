import Foundation
import LocalAuthentication

/// Thin wrapper over Face ID / Touch ID for "tap to reveal" balance privacy.
enum BiometricGate {
    /// Attempt biometric (falls back to device passcode). Returns true on success.
    static func authenticate(reason: String = "Reveal your balance") async -> Bool {
        let context = LAContext()
        var error: NSError?
        // Allow passcode fallback so it still works on devices without Face ID.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        return await withCheckedContinuation { cont in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
}
