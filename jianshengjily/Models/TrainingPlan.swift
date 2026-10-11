import Foundation
import SwiftData

@Model
final class TrainingPlan: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var isOfficial: Bool
    var isActive: Bool
    var selectedDayIndex: Int
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isOfficial: Bool = false,
        isActive: Bool = false,
        selectedDayIndex: Int = 0,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isOfficial = isOfficial
        self.isActive = isActive
        self.selectedDayIndex = selectedDayIndex
        self.sortIndex = sortIndex
    }
}

@Model
final class TrainingPlanDay: Identifiable {
    var id: UUID
    var planId: UUID
    var name: String
    var sortIndex: Int
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
        planId: UUID,
        name: String,
        sortIndex: Int,
        createdAt: Date = Date(),
        exerciseIds: [UUID] = [],
        targetSetCounts: [UUID: Int] = [:],
        targetRepCounts: [UUID: Int] = [:]
    ) {
        self.id = id
        self.planId = planId
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.exerciseIdsData = (try? JSONEncoder().encode(exerciseIds)) ?? Data()
        self.targetSetCountsData = WorkoutTargetSets.encode(targetSetCounts)
        self.targetRepCountsData = WorkoutTargetReps.encode(targetRepCounts)
    }
}

struct TrainingPlanDayDraft: Identifiable, Equatable {
    var id: UUID
    var name: String
    var exerciseIds: [UUID]
    var targetSetCounts: [UUID: Int]
    var targetRepCounts: [UUID: Int]

    init(
        id: UUID = UUID(),
        name: String,
        exerciseIds: [UUID] = [],
        targetSetCounts: [UUID: Int] = [:],
        targetRepCounts: [UUID: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.exerciseIds = exerciseIds
        self.targetSetCounts = targetSetCounts
        self.targetRepCounts = targetRepCounts
    }

    func targetSetCount(for exerciseId: UUID) -> Int {
        targetSetCounts[exerciseId] ?? WorkoutTargetSets.defaultCount
    }

    func targetRepCount(for exerciseId: UUID) -> Int? {
        targetRepCounts[exerciseId]
    }
}
