import Foundation
import SwiftData

enum ExerciseMeasurementMode: Equatable {
    case externalLoadAndReps
    case bodyweightAndReps
    case bodyweightAndDuration
    case duration
    case externalLoadAndDuration

    var acceptsLoad: Bool {
        switch self {
        case .externalLoadAndReps, .bodyweightAndReps, .bodyweightAndDuration, .externalLoadAndDuration:
            return true
        case .duration:
            return false
        }
    }

    var loadIsAdditional: Bool {
        switch self {
        case .bodyweightAndReps, .bodyweightAndDuration:
            return true
        case .externalLoadAndReps, .duration, .externalLoadAndDuration:
            return false
        }
    }

    var recordsReps: Bool {
        switch self {
        case .externalLoadAndReps, .bodyweightAndReps:
            return true
        case .bodyweightAndDuration, .duration, .externalLoadAndDuration:
            return false
        }
    }

    var recordsDuration: Bool {
        !recordsReps
    }
}

enum ExerciseMeasurementProfile {
    private static let bodyweightRepExercises: Set<String> = [
        "俯卧撑",
        "窄距俯卧撑",
        "双杠臂屈伸",
        "引体向上",
        "中立握引体向上",
        "反手引体向上",
        "反向划船",
        "卷腹",
        "反向卷腹",
        "悬垂举腿",
        "俄罗斯转体",
        "死虫",
        "鸟狗",
        "罗马椅挺身",
    ]

    private static let durationExercises: Set<String> = [
        "平板支撑",
        "侧桥",
        "战绳",
    ]

    private static let externalLoadDurationExercises: Set<String> = [
        "农夫行走",
        "雪橇推",
    ]

    static func mode(for exerciseName: String) -> ExerciseMeasurementMode {
        if bodyweightRepExercises.contains(exerciseName) {
            return .bodyweightAndReps
        }
        if durationExercises.contains(exerciseName) {
            return .duration
        }
        if externalLoadDurationExercises.contains(exerciseName) {
            return .externalLoadAndDuration
        }

        let normalized = exerciseName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if containsAny(normalized, ["pull-up", "pullup", "chin-up", "chinup", "push-up", "pushup", "引体", "俯卧撑", "双杠", "卷腹", "悬垂举腿", "反向划船"]) {
            return .bodyweightAndReps
        }
        if containsAny(normalized, ["plank", "side bridge", "平板", "侧桥"]) {
            return .duration
        }
        if containsAny(normalized, ["battle rope", "战绳"]) {
            return .duration
        }
        if containsAny(normalized, ["farmer walk", "farmer carry", "sled push", "农夫行走", "雪橇推"]) {
            return .externalLoadAndDuration
        }

        return .externalLoadAndReps
    }

    private static func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains { value.contains($0) }
    }
}

@Model
final class Exercise: Identifiable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.createdAt = createdAt
    }
}

extension Exercise {
    var measurementMode: ExerciseMeasurementMode {
        ExerciseMeasurementProfile.mode(for: name)
    }
}
