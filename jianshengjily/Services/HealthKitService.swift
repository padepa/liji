import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            return false
        }

        let workoutType = HKObjectType.workoutType()

        do {
            try await healthStore.requestAuthorization(toShare: [workoutType], read: [workoutType])
            return true
        } catch {
            return false
        }
    }

    func saveWorkoutIfAuthorized(session: WorkoutSession, setLogs: [SetLog]) async {
        await saveWorkoutIfAuthorized(
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            setCount: setLogs.filter { $0.sessionId == session.id }.count
        )
    }

    func saveWorkoutIfAuthorized(startedAt: Date, endedAt: Date, setCount: Int) async {
        guard isAvailable else {
            return
        }

        let authorized = await requestAuthorization()
        guard authorized else {
            return
        }

        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startedAt,
            end: endedAt,
            duration: endedAt.timeIntervalSince(startedAt),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyIndoorWorkout: true,
                "SetCount": setCount
            ]
        )

        do {
            try await healthStore.save(workout)
        } catch {
            #if DEBUG
            print("HealthKit save failed: \(error)")
            #endif
        }
    }
}
