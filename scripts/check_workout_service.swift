import Foundation
import SwiftData

@main
enum WorkoutServiceCheck {
    static func main() throws {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            SetLog.self,
            WorkoutTemplate.self,
            TrainingPlan.self,
            TrainingPlanDay.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        WorkoutService.seedDefaultExercisesIfNeeded(in: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        assertEqual(exercises.count, WorkoutService.defaultExercises.count, "seed default exercises once")

        WorkoutService.seedDefaultExercisesIfNeeded(in: context)
        let reseededExercises = try context.fetch(FetchDescriptor<Exercise>())
        assertEqual(reseededExercises.count, WorkoutService.defaultExercises.count, "seed default exercises idempotent")

        let normalizedDefaultExerciseNames = WorkoutService.defaultExercises.map(normalizedName)
        assertEqual(
            Set(normalizedDefaultExerciseNames).count,
            WorkoutService.defaultExercises.count,
            "default exercises do not contain duplicate names"
        )

        let seededExerciseNames = Set(reseededExercises.map { normalizedName($0.name) })
        for template in WorkoutService.defaultTemplateDefinitions {
            let missingExercises = template.exerciseNames.filter { !seededExerciseNames.contains(normalizedName($0)) }
            assertTrue(missingExercises.isEmpty, "template \(template.name) references missing exercises: \(missingExercises)")
        }

        for plan in WorkoutService.defaultTrainingPlanDefinitions {
            for day in plan.dayDefinitions {
                let missingExercises = day.exerciseNames.filter { !seededExerciseNames.contains(normalizedName($0)) }
                assertTrue(missingExercises.isEmpty, "plan \(plan.name) day \(day.name) references missing exercises: \(missingExercises)")
            }
        }

        guard let bench = reseededExercises.first(where: { $0.name == "卧推" }) else {
            fail("missing default exercise")
        }
        guard let squat = reseededExercises.first(where: { $0.name == "深蹲" }) else {
            fail("missing default squat")
        }
        guard let deadlift = reseededExercises.first(where: { $0.name == "硬拉" }) else {
            fail("missing default deadlift")
        }

        assertEqual(bench.measurementMode, .externalLoadAndReps, "bench tracks external load and reps")
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "引体向上"),
            .bodyweightAndReps,
            "pull-up treats weight as optional added load"
        )
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "Weighted Pull-Up"),
            .bodyweightAndReps,
            "custom pull-up name infers bodyweight and reps"
        )
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "平板支撑"),
            .duration,
            "plank tracks duration without requiring a load"
        )
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "侧桥"),
            .duration,
            "side plank tracks duration without requiring a load"
        )
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "战绳"),
            .duration,
            "battle rope tracks duration"
        )
        assertEqual(
            ExerciseMeasurementProfile.mode(for: "农夫行走"),
            .externalLoadAndDuration,
            "farmer walk tracks load and duration"
        )

        let duplicateBench = WorkoutService.createCustomExercise(named: "  卧推  ", in: context)
        assertEqual(duplicateBench?.id, bench.id, "custom exercise reuses existing name")
        let afterDuplicateExercises = try context.fetch(FetchDescriptor<Exercise>())
        assertEqual(afterDuplicateExercises.count, WorkoutService.defaultExercises.count, "duplicate custom exercise does not insert")

        let customExercise = WorkoutService.createCustomExercise(named: "泽奇深蹲", in: context)
        assertEqual(customExercise?.name, "泽奇深蹲", "custom exercise is created")
        let afterCustomExercises = try context.fetch(FetchDescriptor<Exercise>())
        assertEqual(afterCustomExercises.count, WorkoutService.defaultExercises.count + 1, "new custom exercise inserts once")

        context.insert(WorkoutTemplate(name: "我的推日", exerciseIds: [bench.id]))
        try context.save()
        WorkoutService.seedDefaultTemplatesIfNeeded(in: context)
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        for defaultTemplate in WorkoutService.defaultTemplateDefinitions {
            assertTrue(templates.contains { $0.name == defaultTemplate.name }, "seeds official template \(defaultTemplate.name)")
        }
        assertTrue(templates.contains { $0.name == "我的推日" }, "seeding official templates keeps user templates")
        let officialTemplateCount = templates.filter { WorkoutService.defaultTemplateNames.contains($0.name) }.count
        assertEqual(officialTemplateCount, WorkoutService.defaultTemplateDefinitions.count, "official templates are seeded once")
        for template in templates where WorkoutService.defaultTemplateNames.contains(template.name) {
            assertTrue(
                template.exerciseIds.allSatisfy { template.targetSetCounts[$0] != nil },
                "official template \(template.name) stores a target set count for every exercise"
            )
            assertTrue(
                template.exerciseIds.allSatisfy { exerciseId in
                    guard let exercise = reseededExercises.first(where: { $0.id == exerciseId }) else {
                        return false
                    }
                    return !exercise.measurementMode.recordsReps || template.targetRepCount(for: exerciseId) != nil
                },
                "official template \(template.name) stores target reps for rep-based exercises"
            )
        }
        guard let classicFiveByFive = templates.first(where: { $0.name == "经典 5x5" }) else {
            fail("missing classic 5x5 template")
        }
        assertTrue(
            classicFiveByFive.exerciseIds.allSatisfy { classicFiveByFive.targetSetCount(for: $0) == 5 },
            "classic 5x5 uses five target sets"
        )
        assertTrue(
            classicFiveByFive.exerciseIds.allSatisfy { classicFiveByFive.targetRepCount(for: $0) == 5 },
            "classic 5x5 uses five target reps"
        )

        classicFiveByFive.targetSetCountsData = nil
        try context.save()

        WorkoutService.seedDefaultTemplatesIfNeeded(in: context)
        let reseededTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let reseededOfficialTemplateCount = reseededTemplates.filter { WorkoutService.defaultTemplateNames.contains($0.name) }.count
        assertEqual(reseededOfficialTemplateCount, WorkoutService.defaultTemplateDefinitions.count, "official templates are idempotent")
        assertTrue(
            classicFiveByFive.exerciseIds.allSatisfy { classicFiveByFive.targetSetCounts[$0] != nil },
            "seeding backfills target set counts for an existing official template"
        )

        WorkoutService.seedDefaultTrainingPlansIfNeeded(in: context)
        let trainingPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        let trainingPlanDays = try context.fetch(FetchDescriptor<TrainingPlanDay>())
        let officialPlanCount = trainingPlans.filter { WorkoutService.defaultTrainingPlanNames.contains($0.name) }.count
        assertEqual(officialPlanCount, WorkoutService.defaultTrainingPlanDefinitions.count, "official training plans are seeded once")
        assertEqual(trainingPlans.filter { $0.isActive }.count, 0, "seeding does not choose a training plan for the user")
        assertTrue(WorkoutService.activeTrainingPlan(from: trainingPlans) == nil, "no active plan before the user chooses one")

        for definition in WorkoutService.defaultTrainingPlanDefinitions {
            guard let plan = trainingPlans.first(where: { $0.name == definition.name }) else {
                fail("missing official training plan \(definition.name)")
            }

            let seededDays = WorkoutService.trainingPlanDays(for: plan, from: trainingPlanDays)
            assertEqual(seededDays.count, definition.dayDefinitions.count, "plan \(definition.name) seeds all days")
            for dayDefinition in definition.dayDefinitions {
                assertTrue(seededDays.contains { $0.name == dayDefinition.name }, "plan \(definition.name) seeds day \(dayDefinition.name)")
            }
            assertTrue(
                seededDays.allSatisfy { day in
                    day.exerciseIds.allSatisfy { day.targetSetCounts[$0] != nil }
                },
                "plan \(definition.name) stores target set counts for every exercise"
            )
        }

        WorkoutService.seedDefaultTrainingPlansIfNeeded(in: context)
        let reseededPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        let reseededDays = try context.fetch(FetchDescriptor<TrainingPlanDay>())
        assertEqual(reseededPlans.filter { WorkoutService.defaultTrainingPlanNames.contains($0.name) }.count, WorkoutService.defaultTrainingPlanDefinitions.count, "official training plans are idempotent")
        assertEqual(reseededDays.count, trainingPlanDays.count, "official training plan days are idempotent")

        guard let selectedPlan = reseededPlans.first(where: { $0.name == "三分化基础" }),
              let activePlanDay = WorkoutService.nextTrainingPlanDay(for: selectedPlan, from: reseededDays) else {
            fail("missing selectable training plan day")
        }
        let planSession = WorkoutService.createWorkout(from: activePlanDay, plan: selectedPlan, in: context)
        assertEqual(planSession.exerciseIds, activePlanDay.exerciseIds, "plan workout copies day exercises")
        assertEqual(planSession.targetSetCounts, activePlanDay.targetSetCounts, "plan workout copies target set counts")
        assertEqual(planSession.targetRepCounts, activePlanDay.targetRepCounts, "plan workout copies target rep counts")
        assertEqual(planSession.activeExerciseId, activePlanDay.exerciseIds.first, "plan workout sets active exercise")
        assertEqual(WorkoutService.activeTrainingPlan(from: try context.fetch(FetchDescriptor<TrainingPlan>()))?.id, selectedPlan.id, "starting a plan makes it active")
        let advancedPlanDays = try context.fetch(FetchDescriptor<TrainingPlanDay>())
        let nextPlanDay = WorkoutService.nextTrainingPlanDay(for: selectedPlan, from: advancedPlanDays)
        assertTrue(nextPlanDay?.id != activePlanDay.id, "starting plan day advances to next day")

        let userPlan = WorkoutService.createUserTrainingPlan(
            named: "  我的四分化  ",
            dayDrafts: [
                TrainingPlanDayDraft(
                    name: "推",
                    exerciseIds: [bench.id],
                    targetSetCounts: [bench.id: 5],
                    targetRepCounts: [bench.id: 8]
                ),
                TrainingPlanDayDraft(name: "腿", exerciseIds: [squat.id], targetSetCounts: [squat.id: 4])
            ],
            in: context
        )
        guard let userPlan else {
            fail("custom training plan is created")
        }
        assertEqual(userPlan.name, "我的四分化", "custom plan name is trimmed")
        assertTrue(!userPlan.isOfficial, "custom plan is not official")
        let duplicateUserPlan = WorkoutService.createUserTrainingPlan(
            named: "我的四分化",
            dayDrafts: [TrainingPlanDayDraft(name: "重复", exerciseIds: [bench.id])],
            in: context
        )
        assertTrue(duplicateUserPlan == nil, "duplicate custom plan does not insert")

        let userPlanDays = try context.fetch(FetchDescriptor<TrainingPlanDay>())
        let createdUserDays = WorkoutService.trainingPlanDays(for: userPlan, from: userPlanDays)
        assertEqual(createdUserDays.map(\.name), ["推", "腿"], "custom plan stores ordered days")
        assertEqual(createdUserDays.first?.targetSetCount(for: bench.id), 5, "custom plan stores user target set count")
        assertEqual(createdUserDays.first?.targetRepCount(for: bench.id), 8, "custom plan stores user target reps")

        let didUpdateUserPlan = WorkoutService.updateUserTrainingPlan(
            userPlan,
            name: "我的三分化",
            dayDrafts: [
                TrainingPlanDayDraft(
                    name: "胸三头",
                    exerciseIds: [bench.id],
                    targetSetCounts: [bench.id: 3],
                    targetRepCounts: [bench.id: 12]
                ),
                TrainingPlanDayDraft(
                    name: "腿臀",
                    exerciseIds: [squat.id, bench.id],
                    targetSetCounts: [squat.id: 5, bench.id: 4]
                )
            ],
            existingDays: userPlanDays,
            in: context
        )
        assertTrue(didUpdateUserPlan, "custom plan updates")
        let updatedUserPlanDays = try context.fetch(FetchDescriptor<TrainingPlanDay>())
        assertEqual(WorkoutService.trainingPlanDays(for: userPlan, from: updatedUserPlanDays).map(\.name), ["胸三头", "腿臀"], "custom plan replaces days")
        assertEqual(
            WorkoutService.trainingPlanDays(for: userPlan, from: updatedUserPlanDays).first?.targetSetCount(for: bench.id),
            3,
            "custom plan update keeps edited target set count"
        )
        assertEqual(
            WorkoutService.trainingPlanDays(for: userPlan, from: updatedUserPlanDays).first?.targetRepCount(for: bench.id),
            12,
            "custom plan update keeps edited target reps"
        )

        WorkoutService.deleteTrainingPlan(userPlan, days: updatedUserPlanDays, in: context)
        let afterDeletePlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        assertTrue(!afterDeletePlans.contains { $0.id == userPlan.id }, "custom plan deletes")

        let session = WorkoutService.createWorkout(in: context)
        var sets = try context.fetch(FetchDescriptor<SetLog>())
        let setStart = Date(timeIntervalSince1970: 10_000)
        let firstSet = WorkoutService.addSet(
            session: session,
            exercise: bench,
            existingSets: sets,
            in: context,
            startedAt: setStart,
            durationSeconds: 37
        )
        assertEqual(firstSet.setNumber, 1, "first set number")
        assertEqual(firstSet.weightKg, nil, "first set has no default weight without history")
        assertEqual(firstSet.reps, nil, "first set has no default reps without history")
        assertEqual(firstSet.startedAt, setStart, "first set stores start time")
        assertEqual(firstSet.durationSeconds, 37, "first set stores duration")
        assertEqual(session.activeExerciseId, bench.id, "addSet updates active exercise")
        assertTrue(session.exerciseIds.contains(bench.id), "addSet appends exercise to session")

        firstSet.weightKg = 80
        firstSet.reps = 5
        try context.save()

        sets = try context.fetch(FetchDescriptor<SetLog>())
        let restStartedAt = Date(timeIntervalSince1970: 10_100)
        WorkoutService.updateRestTiming(
            setId: firstSet.id,
            existingSets: sets,
            in: context,
            restStartedAt: restStartedAt,
            restDurationSeconds: 91
        )
        assertEqual(firstSet.restStartedAt, restStartedAt, "rest timing stores start time")
        assertEqual(firstSet.restDurationSeconds, 91, "rest timing stores duration")

        sets = try context.fetch(FetchDescriptor<SetLog>())
        let secondSet = WorkoutService.addSet(session: session, exercise: bench, existingSets: sets, in: context)
        assertEqual(secondSet.setNumber, 2, "second set number")
        assertEqual(secondSet.weightKg, 80, "current session inherits previous weight")
        assertEqual(secondSet.reps, 5, "current session inherits previous reps")

        secondSet.weightKg = 82.5
        secondSet.reps = 4
        try context.save()

        let nextSession = WorkoutService.createWorkout(in: context)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        let remembered = WorkoutService.nextSetDefaultValues(session: nextSession, exercise: bench, existingSets: sets)
        assertEqual(remembered.weightKg, 82.5, "new session remembers latest historical weight")
        assertEqual(remembered.reps, 4, "new session remembers latest historical reps")
        assertEqual(remembered.source, .history, "new session default source is history")

        let rememberedSet = WorkoutService.addSet(session: nextSession, exercise: bench, existingSets: sets, in: context)
        assertEqual(rememberedSet.weightKg, 82.5, "addSet applies remembered weight")
        assertEqual(rememberedSet.reps, 4, "addSet applies remembered reps")

        rememberedSet.weightKg = nil
        rememberedSet.reps = nil
        try context.save()

        sets = try context.fetch(FetchDescriptor<SetLog>())
        let blankCurrentDefaults = WorkoutService.nextSetDefaultValues(session: nextSession, exercise: bench, existingSets: sets)
        assertEqual(blankCurrentDefaults.weightKg, nil, "blank current set does not refill historical weight")
        assertEqual(blankCurrentDefaults.reps, nil, "blank current set does not refill historical reps")
        assertEqual(blankCurrentDefaults.source, .currentSession, "blank current set still counts as current source")

        _ = WorkoutService.addSet(session: nextSession, exercise: bench, existingSets: sets, in: context)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        WorkoutService.deleteLastSet(session: nextSession, exercise: bench, existingSets: sets, in: context)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        let remainingNextSessionSets = WorkoutService.setsForExercise(sets, session: nextSession, exercise: bench)
        assertEqual(remainingNextSessionSets.count, 1, "delete last set removes one set")
        assertEqual(remainingNextSessionSets.map(\.setNumber), [1], "delete last set renumbers remaining sets")

        let template = WorkoutService.saveCurrentWorkoutAsTemplate(
            session: session,
            name: "  推力日  ",
            setLogs: sets,
            in: context
        )
        assertEqual(template?.name, "推力日", "template name is trimmed")
        assertEqual(template?.exerciseIds, [bench.id], "template stores unique exercise ids")
        assertEqual(template?.targetSetCount(for: bench.id), 2, "saved workout uses completed sets as template target")

        guard let template else {
            fail("saved workout template is missing")
        }
        let templateSession = WorkoutService.createWorkout(from: template, in: context)
        assertEqual(templateSession.targetSetCount(for: bench.id), 2, "template workout copies target set count")
        assertEqual(templateSession.targetRepCount(for: bench.id), 4, "saved workout copies latest completed reps as target")

        let templateSets = try context.fetch(FetchDescriptor<SetLog>())
        let targetSnapshotSet = WorkoutService.addSet(
            session: templateSession,
            exercise: bench,
            existingSets: templateSets,
            in: context,
            weightKg: 80,
            reps: 3
        )
        assertEqual(targetSnapshotSet.targetReps, 4, "completed set snapshots planned target reps")
        templateSession.targetRepCounts[bench.id] = 10
        try context.save()
        assertEqual(targetSnapshotSet.targetReps, 4, "set target snapshot stays stable after plan changes")

        WorkoutService.addExercise(squat, to: templateSession, in: context)
        assertEqual(
            templateSession.exerciseIds,
            [bench.id, squat.id],
            "planned workout appends an exercise during training"
        )
        assertEqual(
            templateSession.targetSetCount(for: squat.id),
            WorkoutTargetSets.defaultCount,
            "planned workout gives an added exercise the default target sets"
        )
        assertEqual(
            templateSession.targetRepCount(for: squat.id),
            WorkoutTargetReps.defaultCount,
            "planned workout gives an added reps exercise the default target reps"
        )
        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: squat.id,
                completedSetCount: WorkoutTargetSets.defaultCount,
                exerciseIds: templateSession.exerciseIds,
                targetSetCounts: templateSession.targetSetCounts
            ),
            .finishWorkout,
            "added final exercise can finish a planned workout at its target"
        )

        let multiExercisePlannedWorkout = WorkoutSession(
            activeExerciseId: bench.id,
            exerciseIds: [bench.id, squat.id],
            targetSetCounts: [bench.id: 2, squat.id: 3]
        )
        context.insert(multiExercisePlannedWorkout)
        WorkoutService.addExercise(deadlift, to: multiExercisePlannedWorkout, in: context)
        assertEqual(
            multiExercisePlannedWorkout.exerciseIds,
            [bench.id, deadlift.id, squat.id],
            "planned workout inserts an added exercise after the current exercise"
        )
        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: deadlift.id,
                completedSetCount: WorkoutTargetSets.defaultCount,
                exerciseIds: multiExercisePlannedWorkout.exerciseIds,
                targetSetCounts: multiExercisePlannedWorkout.targetSetCounts
            ),
            .advanceToExercise(squat.id),
            "added exercise returns to the remaining planned sequence"
        )

        let freeWorkoutWithAddedExercise = WorkoutService.createWorkout(in: context)
        WorkoutService.addExercise(squat, to: freeWorkoutWithAddedExercise, in: context)
        assertEqual(
            freeWorkoutWithAddedExercise.targetSetCount(for: squat.id),
            nil,
            "free workout keeps added exercises manual"
        )
        assertEqual(
            freeWorkoutWithAddedExercise.targetRepCount(for: squat.id),
            nil,
            "free workout does not invent target reps"
        )

        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: bench.id,
                completedSetCount: 3,
                exerciseIds: [bench.id, squat.id],
                targetSetCounts: [bench.id: 4, squat.id: 4]
            ),
            .continueCurrentExercise,
            "workout stays on exercise below target sets"
        )
        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: bench.id,
                completedSetCount: 4,
                exerciseIds: [bench.id, squat.id],
                targetSetCounts: [bench.id: 4, squat.id: 4]
            ),
            .advanceToExercise(squat.id),
            "workout advances at target sets"
        )
        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: squat.id,
                completedSetCount: 4,
                exerciseIds: [bench.id, squat.id],
                targetSetCounts: [bench.id: 4, squat.id: 4]
            ),
            .finishWorkout,
            "workout finishes when final exercise reaches target sets"
        )
        assertEqual(
            WorkoutLogic.progression(
                afterCompleting: bench.id,
                completedSetCount: 4,
                exerciseIds: [bench.id, squat.id],
                targetSetCounts: [:]
            ),
            .continueCurrentExercise,
            "free workout without targets remains manual"
        )

        let emptySession = WorkoutService.createWorkout(in: context)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        WorkoutService.discard(emptySession, setLogs: sets, in: context)
        let remainingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        assertTrue(!remainingSessions.contains { $0.id == emptySession.id }, "discard removes empty active session")

        let discardSession = WorkoutService.createWorkout(in: context)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        _ = WorkoutService.addSet(session: discardSession, exercise: bench, existingSets: sets, in: context, weightKg: 60, reps: 8)
        sets = try context.fetch(FetchDescriptor<SetLog>())
        WorkoutService.discard(discardSession, setLogs: sets, in: context)
        let remainingSets = try context.fetch(FetchDescriptor<SetLog>())
        assertTrue(!remainingSets.contains { $0.sessionId == discardSession.id }, "discard removes session set logs")

        // Use an isolated store: replay must not mutate history or duplicate finished logs.
        let replayContainer = try ModelContainer(for: schema, configurations: [configuration])
        let replayContext = ModelContext(replayContainer)
        let replayExercise = Exercise(name: "卧推")
        replayContext.insert(replayExercise)
        let now = Date()
        let past = WorkoutSession(startedAt: now.addingTimeInterval(-3600), endedAt: now.addingTimeInterval(-1800), status: .finished, exerciseIds: [replayExercise.id])
        replayContext.insert(past)
        let logged = SetLog(sessionId: past.id, exerciseId: replayExercise.id, setNumber: 1, weightKg: 60, reps: 10)
        replayContext.insert(logged)
        try replayContext.save()
        let replay = try WorkoutService.repeatWorkout(past, in: replayContext)
        assertEqual(replay.exerciseIds, [replayExercise.id], "replay preserves exercise order")
        assertEqual(replay.targetSetCount(for: replayExercise.id), 1, "replay uses performed sets")
        assertEqual(replay.targetRepCount(for: replayExercise.id), 10, "replay uses rep target")
        assertEqual(past.status, .finished, "replay keeps source finished")
        assertEqual(try replayContext.fetch(FetchDescriptor<SetLog>()).count, 1, "replay never copies completed logs")
        do {
            _ = try WorkoutService.repeatWorkout(past, in: replayContext)
            fail("replay must reject an existing active session")
        } catch WorkoutService.RepeatError.activeWorkout { }
        let stats = WorkoutStatistics(sessions: [past, replay], logs: [logged], exercises: [replayExercise], dayCount: 7, now: now)
        assertEqual(stats.workoutCount, 1, "stats exclude active workouts")
        assertEqual(stats.setCount, 1, "stats count completed sets")
        assertEqual(stats.durationMinutes, 30, "stats duration")
        assertEqual(stats.volumeKg, 600, "stats use weight times actual reps")
        assertEqual(stats.days.count, 7, "stats fill empty days")
        assertEqual(stats.days.reduce(0) { $0 + $1.workouts }, 1, "chart matches total")
        let previousDate = Calendar.current.date(byAdding: .day, value: -9, to: now)!
        let previousWorkout = WorkoutSession(startedAt: previousDate, endedAt: previousDate.addingTimeInterval(1800), status: .finished)
        let previousSet = SetLog(sessionId: previousWorkout.id, exerciseId: replayExercise.id, setNumber: 1, weightKg: 50, reps: 8)
        let insights = WorkoutInsights(
            sessions: [past, previousWorkout, replay],
            logs: [logged, previousSet],
            exercises: [replayExercise],
            now: now
        )
        assertEqual(insights.recent.workoutCount, 1, "insights recent period excludes active workouts")
        assertEqual(insights.previous.workoutCount, 1, "insights compare previous seven days")
        assertEqual(insights.recent.setCount, 1, "insights recent set count")
        assertEqual(insights.previous.volumeKg, 400, "insights previous lifting volume")
        assertEqual(insights.trends.count, 1, "insights include logged exercise")
        assertEqual(insights.trends[0].metric, .weightKg, "weighted exercise trends heaviest set")
        assertEqual(insights.trends[0].points.map(\.value), [50, 60], "insights order sessions chronologically")
        let noFinishedInsights = WorkoutInsights(sessions: [replay], logs: [logged], exercises: [replayExercise], now: now)
        assertEqual(noFinishedInsights.trends.count, 0, "active sessions do not create progress points")
        let manySessions = (0..<13).map { index in
            WorkoutSession(startedAt: now.addingTimeInterval(Double(index - 13) * 3600), status: .finished)
        }
        let manyLogs = manySessions.enumerated().map { index, session in
            SetLog(sessionId: session.id, exerciseId: replayExercise.id, setNumber: 1, weightKg: Double(20 + index), reps: 8)
        }
        let cappedInsights = WorkoutInsights(sessions: manySessions, logs: manyLogs, exercises: [replayExercise], now: now)
        assertEqual(cappedInsights.trends[0].points.count, 12, "exercise chart is limited to 12 recent workouts")
        assertEqual(cappedInsights.trends[0].points.first?.value, 21, "exercise chart keeps the newest 12 points")
        let emptyStats = WorkoutStatistics(sessions: [], logs: [logged], exercises: [replayExercise], dayCount: 30, now: now)
        assertEqual(emptyStats.setCount, 0, "stats exclude orphan logs")
        assertEqual(emptyStats.volumeKg, 0, "empty stats do not fabricate volume")
        let timed = Exercise(name: "平板支撑")
        let bodyweight = Exercise(name: "俯卧撑")
        let timedLog = SetLog(sessionId: past.id, exerciseId: timed.id, setNumber: 1, weightKg: 10, reps: 60, durationSeconds: 60)
        let bodyweightLog = SetLog(sessionId: past.id, exerciseId: bodyweight.id, setNumber: 1, reps: 20)
        let extraStats = WorkoutStatistics(sessions: [past], logs: [logged, timedLog, bodyweightLog], exercises: [replayExercise, timed, bodyweight], dayCount: 7, now: now)
        assertEqual(extraStats.setCount, 3, "all measurement modes count as sets")
        assertEqual(extraStats.volumeKg, 600, "timed and unloaded bodyweight do not inflate volume")
        let mixedInsights = WorkoutInsights(sessions: [past], logs: [logged, timedLog, bodyweightLog], exercises: [replayExercise, timed, bodyweight], now: now)
        assertEqual(mixedInsights.trends.first { $0.id == timed.id }?.metric, .durationSeconds, "timed exercise trends duration")
        assertEqual(mixedInsights.trends.first { $0.id == bodyweight.id }?.metric, .reps, "bodyweight exercise trends repetitions")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let boundary = WorkoutSession(startedAt: start, status: .finished)
        let tooOld = WorkoutSession(startedAt: start.addingTimeInterval(-1), status: .finished)
        let future = WorkoutSession(startedAt: now.addingTimeInterval(1), status: .finished)
        let boundaryStats = WorkoutStatistics(sessions: [boundary, tooOld, future], logs: [], exercises: [], dayCount: 7, now: now, calendar: calendar)
        assertEqual(boundaryStats.workoutCount, 1, "date range includes first midnight and excludes past/future")
        WorkoutService.finish(replay, in: replayContext)
        let emptySource = WorkoutSession(status: .finished)
        do {
            _ = try WorkoutService.repeatWorkout(emptySource, in: replayContext)
            fail("empty source must not create a workout")
        } catch WorkoutService.RepeatError.noExercises { }

        print("Workout service checks passed.")
    }

    private static func assertTrue(_ condition: Bool, _ label: String) {
        guard condition else {
            fail(label)
        }
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        guard actual == expected else {
            fail("\(label): expected \(expected), got \(actual)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Workout service check failed: \(message)\n".utf8))
        exit(1)
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
