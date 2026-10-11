import Foundation

@main
enum CoreLogicCheck {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)

        assertEqual(
            WorkoutLogic.durationText(startedAt: start, endedAt: start.addingTimeInterval(65)),
            "01:05",
            "duration below one hour"
        )

        assertEqual(
            WorkoutLogic.durationText(startedAt: start, endedAt: start.addingTimeInterval(3661)),
            "1:01:01",
            "duration above one hour"
        )

        assertEqual(WorkoutLogic.nextSetNumber(existingSetCount: 3), 4, "next set number")
        assertEqual(WorkoutLogic.renumberedSetNumbers(count: 4), [1, 2, 3, 4], "renumber four sets")
        assertEqual(WorkoutLogic.renumberedSetNumbers(count: 0), [], "renumber zero sets")
        assertEqual(WorkoutLogic.orderedUnique([1, 2, 1, 3, 2]), [1, 2, 3], "ordered unique")
        assertEqual(WorkoutLogic.formattedWeight(80), "80", "integer weight format")
        assertEqual(WorkoutLogic.formattedWeight(80.5), "80.5", "decimal weight format")
        assertEqual(WorkoutLogic.shortDurationText(seconds: nil), nil, "nil short duration")
        assertEqual(WorkoutLogic.shortDurationText(seconds: 42), "42秒", "short duration seconds")
        assertEqual(WorkoutLogic.shortDurationText(seconds: 75), "1分15秒", "short duration minutes")
        assertEqual(
            WorkoutLogic.repTargetComparison(actualReps: 8, targetReps: 12),
            .below(remaining: 4),
            "reps below target"
        )
        assertEqual(
            WorkoutLogic.repTargetComparison(actualReps: 12, targetReps: 12),
            .achieved,
            "reps achieve target"
        )
        assertEqual(
            WorkoutLogic.repTargetComparison(actualReps: 14, targetReps: 12),
            .exceeded(extra: 2),
            "reps exceed target"
        )
        assertEqual(
            WorkoutLogic.repTargetComparison(actualReps: 8, targetReps: nil),
            nil,
            "free workout has no rep comparison"
        )

        let estimated = WorkoutLogic.estimatedOneRepMax(weightKg: 100, reps: 5)
        assertClose(estimated, 116.666_666_7, "estimated 1RM")
        assertEqual(WorkoutLogic.estimatedOneRepMax(weightKg: nil, reps: 5), nil, "nil weight has no 1RM")

        print("Core logic checks passed.")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        guard actual == expected else {
            fail("\(label): expected \(expected), got \(actual)")
        }
    }

    private static func assertClose(_ actual: Double?, _ expected: Double, _ label: String) {
        guard let actual, abs(actual - expected) < 0.0001 else {
            fail("\(label): expected \(expected), got \(String(describing: actual))")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Core logic check failed: \(message)\n".utf8))
        exit(1)
    }
}
