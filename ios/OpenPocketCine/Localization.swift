import Foundation
import OpenPocketViewCore

extension String {
    var opcLocalized: String {
        NSLocalizedString(self, bundle: .main, comment: "")
    }
}

extension ConnectionPhase {
    var opcLocalizedLabel: String {
        switch self {
        case .failed(let reason):
            String(format: "Failed: %@".opcLocalized, reason)
        default:
            label.opcLocalized
        }
    }
}

extension SessionRecoveryState {
    func opcLocalizedDetail(deviceName: String) -> String {
        let name = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let camera = name.isEmpty ? "The camera".opcLocalized : name
        switch self {
        case .idle:
            return ""
        case .retrying(let attempt, let maxAttempts):
            return String(
                format: "%@ dropped off. Holding the last frame — attempt %d of %d.".opcLocalized,
                camera, attempt, maxAttempts)
        case .waitingForOperator(let attemptsMade):
            return String(
                format: "%@ didn't come back after %d tries. The frame below is held, not live."
                    .opcLocalized,
                camera, attemptsMade)
        case .pausedAfterRepeatedDrops(let drops):
            return String(
                format:
                    "%@ reconnected but dropped %d times in quick succession. Automatic retries are paused to protect the camera. The frame below is held, not live."
                    .opcLocalized,
                camera, drops)
        }
    }
}
