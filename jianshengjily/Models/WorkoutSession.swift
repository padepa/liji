import Foundation
import SwiftData

enum WorkoutSessionStatus: String, CaseIterable, Codable {
    case active
    case finished
}

@Model
final class WorkoutSession: Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var note: String?
    var statusValue: String
    var activeExerciseId: UUID?
    var createdAt: Date
    var exerciseIdsData: Data
    var targetSetCountsData: Data?
    var targetRepCountsData: Data?

    var status: WorkoutSessionStatus {
        get { WorkoutSessionStatus(rawValue: statusValue) ?? .active }
        set { statusValue = newValue.rawValue }
    }

    var exerciseIds: [UUID] {
        get {
            guard !exerciseIdsData.isEmpty else {
                return []
            }
            return (try? JSONDecoder().decode([UUID].self, from: exerciseIdsData)) ?? []
        }
        set {
            exerciseIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var targetSetCounts: [UUID: Int] {
        get { WorkoutTargetSets.decode(targetSetCountsData) }
        set { targetSetCountsData = WorkoutTargetSets.encode(newValue) }
    }

    func targetSetCount(for exerciseId: UUID) -> Int? {
        targetSetCounts[exerciseId]
    }

    var targetRepCounts: [UUID: Int] {
        get { WorkoutTargetReps.decode(targetRepCountsData) }
        set { targetRepCountsData = WorkoutTargetReps.encode(newValue) }
    }

    func targetRepCount(for exerciseId: UUID) -> Int? {
        targetRepCounts[exerciseId]
    }

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        note: String? = nil,
        status: WorkoutSessionStatus = .active,
        activeExerciseId: UUID? = nil,
        createdAt: Date = Date(),
        exerciseIds: [UUID] = [],
        targetSetCounts: [UUID: Int] = [:],
        targetRepCounts: [UUID: Int] = [:]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.statusValue = status.rawValue
        self.activeExerciseId = activeExerciseId
        self.createdAt = createdAt
        self.exerciseIdsData = (try? JSONEncoder().encode(exerciseIds)) ?? Data()
        self.targetSetCountsData = WorkoutTargetSets.encode(targetSetCounts)
        self.targetRepCountsData = WorkoutTargetReps.encode(targetRepCounts)
    }
}
