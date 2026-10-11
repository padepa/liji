import Foundation
import SwiftData

@Model
final class WorkoutTemplate: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var exerciseIdsData: Data
    var targetSetCountsData: Data?
    var targetRepCountsData: Data?

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

    func targetSetCount(for exerciseId: UUID) -> Int {
        targetSetCounts[exerciseId] ?? WorkoutTargetSets.defaultCount
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
        name: String,
        createdAt: Date = Date(),
        exerciseIds: [UUID] = [],
        targetSetCounts: [UUID: Int] = [:],
        targetRepCounts: [UUID: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.exerciseIdsData = (try? JSONEncoder().encode(exerciseIds)) ?? Data()
        self.targetSetCountsData = WorkoutTargetSets.encode(targetSetCounts)
        self.targetRepCountsData = WorkoutTargetReps.encode(targetRepCounts)
    }
}
