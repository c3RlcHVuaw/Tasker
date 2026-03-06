import SwiftUI

enum AppAnimations {
    // Primary motion used for most UI state changes.
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.10)
    // Slightly faster spring for taps/selection.
    static let quick = Animation.spring(response: 0.24, dampingFraction: 0.90, blendDuration: 0.08)
    // Gentle fade/opacity transitions.
    static let fade = Animation.easeInOut(duration: 0.18)
    // Context menu presentation / dismissal.
    static let menuPresent = Animation.interactiveSpring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.12)
    static let menuDismiss = Animation.interactiveSpring(response: 0.24, dampingFraction: 0.96, blendDuration: 0.08)
    // Tab switch feels closer to UIKit tab bars.
    static let tabSwitch = Animation.spring(response: 0.34, dampingFraction: 0.92, blendDuration: 0.10)
    // Press feedback.
    static let press = Animation.spring(response: 0.20, dampingFraction: 0.82, blendDuration: 0.06)
}
