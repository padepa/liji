import UIKit

enum HapticsService {
    static func startWorkout() {
        impact(.medium)
    }

    static func continueWorkout() {
        impact(.medium)
    }

    static func openPanel() {
        impact(.light)
    }

    static func closePanel() {
        impact(.light)
    }

    static func themeChanged() {
        selection()
    }

    static func switchExercise() {
        selection()
    }

    static func selectExercise() {
        selection()
    }

    static func recordSet() {
        impact(.heavy)
    }

    static func recordSetFromWatch() {
        notification(.success)
    }

    static func deleteSet() {
        notification(.warning)
    }

    static func adjustWeight() {
        impact(.light)
    }

    static func adjustReps() {
        impact(.light)
    }

    static func startRestTimer() {
        impact(.light)
    }

    static func timerPresetChanged() {
        selection()
    }

    static func timerPausedOrResumed() {
        impact(.light)
    }

    static func timerCompleted() {
        calmConfirmation()
    }

    static func finishWorkout() {
        calmConfirmation(finishing: true)
    }

    static func saveSucceeded() {
        notification(.success)
    }

    static func destructiveAction() {
        notification(.warning)
    }

    static func sharePosterReady() {
        notification(.success)
    }

    static func shareStarted() {
        selection()
    }

    static func actionFailed() {
        notification(.error)
    }

    private static func selection() {
        runOnMain {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        runOnMain {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        runOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    private static func calmConfirmation(finishing: Bool = false) {
        runOnMain {
            let firstPulse = UIImpactFeedbackGenerator(style: .soft)
            firstPulse.prepare()
            firstPulse.impactOccurred(intensity: finishing ? 0.72 : 0.56)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                let secondPulse = UIImpactFeedbackGenerator(style: .light)
                secondPulse.prepare()
                secondPulse.impactOccurred(intensity: finishing ? 0.56 : 0.38)
            }
        }
    }

    private static func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
