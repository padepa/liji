import Foundation

enum WorkoutTargetSets {
    static let defaultCount = 4
    static let allowedRange = 1...10

    static func normalizedCount(_ count: Int) -> Int {
        min(max(count, allowedRange.lowerBound), allowedRange.upperBound)
    }

    static func normalized(
        _ counts: [UUID: Int],
        for exerciseIds: [UUID],
        fallbackCount: Int? = nil
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for exerciseId in WorkoutLogic.orderedUnique(exerciseIds) {
            if let count = counts[exerciseId] {
                result[exerciseId] = normalizedCount(count)
            } else if let fallbackCount {
                result[exerciseId] = normalizedCount(fallbackCount)
            }
        }
        return result
    }

    static func encode(_ counts: [UUID: Int]) -> Data {
        let stringKeyedCounts = Dictionary(
            uniqueKeysWithValues: counts.map { ($0.key.uuidString, normalizedCount($0.value)) }
        )
        return (try? JSONEncoder().encode(stringKeyedCounts)) ?? Data()
    }

    static func decode(_ data: Data?) -> [UUID: Int] {
        guard let data, !data.isEmpty,
              let stringKeyedCounts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }

        return Dictionary(
            uniqueKeysWithValues: stringKeyedCounts.compactMap { key, value in
                guard let id = UUID(uuidString: key) else {
                    return nil
                }
                return (id, normalizedCount(value))
            }
        )
    }
}

enum WorkoutTargetReps {
    static let defaultCount = 12
    static let allowedRange = 1...100

    static func normalizedCount(_ count: Int) -> Int {
        min(max(count, allowedRange.lowerBound), allowedRange.upperBound)
    }

    static func normalized(_ counts: [UUID: Int], for exerciseIds: [UUID]) -> [UUID: Int] {
        let validExerciseIds = Set(exerciseIds)
        return Dictionary(
            uniqueKeysWithValues: counts.compactMap { exerciseId, count in
                guard validExerciseIds.contains(exerciseId) else {
                    return nil
                }
                return (exerciseId, normalizedCount(count))
            }
        )
    }

    static func encode(_ counts: [UUID: Int]) -> Data {
        let stringKeyedCounts = Dictionary(
            uniqueKeysWithValues: counts.map { ($0.key.uuidString, normalizedCount($0.value)) }
        )
        return (try? JSONEncoder().encode(stringKeyedCounts)) ?? Data()
    }

    static func decode(_ data: Data?) -> [UUID: Int] {
        guard let data, !data.isEmpty,
              let stringKeyedCounts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }

        return Dictionary(
            uniqueKeysWithValues: stringKeyedCounts.compactMap { key, value in
                guard let id = UUID(uuidString: key) else {
                    return nil
                }
                return (id, normalizedCount(value))
            }
        )
    }
}

enum RepTargetComparison: Equatable {
    case below(remaining: Int)
    case achieved
    case exceeded(extra: Int)
}

enum WorkoutProgression: Equatable {
    case continueCurrentExercise
    case advanceToExercise(UUID)
    case finishWorkout
}

enum WorkoutLogic {
    static func durationText(startedAt: Date, endedAt: Date?, now: Date = Date()) -> String {
        let end = endedAt ?? now
        let seconds = max(0, Int(end.timeIntervalSince(startedAt)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func shortDurationText(seconds rawSeconds: Double?) -> String? {
        guard let rawSeconds else {
            return nil
        }

        let seconds = max(0, Int(rawSeconds.rounded()))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 {
            return L10n.format(
                "duration.minutes_seconds",
                fallback: "%1$d分%2$d秒",
                minutes,
                remainingSeconds
            )
        }
        return L10n.format("duration.seconds", fallback: "%1$d秒", remainingSeconds)
    }

    static func estimatedOneRepMax(weightKg: Double?, reps: Int?) -> Double? {
        guard let weightKg else {
            return nil
        }

        let safeReps = max(reps ?? 1, 1)
        return weightKg * (1 + Double(safeReps) / 30)
    }

    static func nextSetNumber(existingSetCount: Int) -> Int {
        existingSetCount + 1
    }

    static func repTargetComparison(actualReps: Int?, targetReps: Int?) -> RepTargetComparison? {
        guard let actualReps, let targetReps, actualReps >= 0, targetReps > 0 else {
            return nil
        }

        if actualReps < targetReps {
            return .below(remaining: targetReps - actualReps)
        }
        if actualReps > targetReps {
            return .exceeded(extra: actualReps - targetReps)
        }
        return .achieved
    }

    static func progression(
        afterCompleting exerciseId: UUID,
        completedSetCount: Int,
        exerciseIds: [UUID],
        targetSetCounts: [UUID: Int]
    ) -> WorkoutProgression {
        guard let targetSetCount = targetSetCounts[exerciseId],
              completedSetCount >= WorkoutTargetSets.normalizedCount(targetSetCount),
              let currentIndex = exerciseIds.firstIndex(of: exerciseId) else {
            return .continueCurrentExercise
        }

        let nextIndex = exerciseIds.index(after: currentIndex)
        guard nextIndex < exerciseIds.endIndex else {
            return .finishWorkout
        }
        return .advanceToExercise(exerciseIds[nextIndex])
    }

    static func renumberedSetNumbers(count: Int) -> [Int] {
        guard count > 0 else {
            return []
        }
        return Array(1...count)
    }

    static func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    static func formattedWeight(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0...1))
                .locale(Locale.current)
        )
    }
}
