import Foundation
import SwiftData

enum SetLogSource: String, CaseIterable, Codable {
    case iphone
    case appleWatch
}

enum SetLogSyncStatus: String, CaseIterable, Codable {
    case synced
    case pending
    case failed
}

@Model
final class SetLog: Identifiable {
    var id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var setNumber: Int
    var weightKg: Double?
    var reps: Int?
    var targetReps: Int?
    var startedAt: Date?
    var durationSeconds: Double?
    var restStartedAt: Date?
    var restDurationSeconds: Double?
    var createdAt: Date
    var sourceValue: String
    var syncStatusValue: String

    var source: SetLogSource {
        get { SetLogSource(rawValue: sourceValue) ?? .iphone }
        set { sourceValue = newValue.rawValue }
    }

    var syncStatus: SetLogSyncStatus {
        get { SetLogSyncStatus(rawValue: syncStatusValue) ?? .synced }
        set { syncStatusValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        targetReps: Int? = nil,
        startedAt: Date? = nil,
        durationSeconds: Double? = nil,
        restStartedAt: Date? = nil,
        restDurationSeconds: Double? = nil,
        createdAt: Date = Date(),
        source: SetLogSource = .iphone,
        syncStatus: SetLogSyncStatus = .synced
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.targetReps = targetReps
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.restStartedAt = restStartedAt
        self.restDurationSeconds = restDurationSeconds
        self.createdAt = createdAt
        self.sourceValue = source.rawValue
        self.syncStatusValue = syncStatus.rawValue
    }
}
