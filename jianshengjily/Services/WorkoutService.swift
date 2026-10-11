import Foundation
import SwiftData

struct WorkoutStatistics {
    struct Day: Identifiable {
        let date: Date
        let workouts: Int
        var id: Date { date }
    }
    let workoutCount: Int
    let setCount: Int
    let durationMinutes: Int
    let volumeKg: Double
    let days: [Day]

    init(sessions: [WorkoutSession], logs: [SetLog], exercises: [Exercise], dayCount: Int, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(max(1, dayCount) - 1), to: today)!
        let finished = sessions.filter { $0.status == .finished && $0.startedAt >= start && $0.startedAt <= now }
        let ids = Set(finished.map(\.id))
        let sets = logs.filter { ids.contains($0.sessionId) }
        let weightedRepIDs = Set(exercises.filter { $0.measurementMode.acceptsLoad && $0.measurementMode.recordsReps }.map(\.id))
        workoutCount = finished.count
        setCount = sets.count
        durationMinutes = Int(finished.reduce(0.0) { total, session in
            total + max(0, (session.endedAt ?? session.startedAt).timeIntervalSince(session.startedAt))
        } / 60)
        volumeKg = sets.reduce(0) { total, set in
            guard weightedRepIDs.contains(set.exerciseId), let weight = set.weightKg, weight.isFinite,
                  weight > 0, let reps = set.reps, reps > 0 else { return total }
            return total + weight * Double(reps)
        }
        days = (0..<max(1, dayCount)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return Day(date: date, workouts: finished.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.count)
        }
    }
}

struct WorkoutInsights {
    struct PeriodSummary {
        let workoutCount: Int
        let setCount: Int
        let volumeKg: Double
    }

    enum TrendMetric {
        case weightKg
        case reps
        case durationSeconds

        var title: String {
            switch self {
            case .weightKg: "最佳单组重量"
            case .reps: "最多次数"
            case .durationSeconds: "最长持续时间"
            }
        }

        var unit: String {
            switch self {
            case .weightKg: "kg"
            case .reps: L10n.string("次")
            case .durationSeconds: L10n.string("秒")
            }
        }
    }

    struct TrendPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
        let reps: Int?
        let loadKg: Double?
    }

    struct ExerciseTrend: Identifiable {
        let id: UUID
        let name: String
        let metric: TrendMetric
        let loadIsAdditional: Bool
        let points: [TrendPoint]
    }

    let recent: PeriodSummary
    let previous: PeriodSummary
    let trends: [ExerciseTrend]

    init(sessions: [WorkoutSession], logs: [SetLog], exercises: [Exercise], now: Date = Date(), calendar: Calendar = .current) {
        let recentStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 86_400)
        let previousStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 86_400)
        let finished = sessions.filter { $0.status == .finished && $0.startedAt <= now }
        let finishedByID = Dictionary(uniqueKeysWithValues: finished.map { ($0.id, $0) })
        let validLogs = logs.filter { finishedByID[$0.sessionId] != nil }
        let measurementByExercise = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.measurementMode) })

        func summary(from start: Date, to end: Date) -> PeriodSummary {
            let periodSessions = finished.filter { $0.startedAt >= start && $0.startedAt < end }
            let ids = Set(periodSessions.map(\.id))
            let periodLogs = validLogs.filter { ids.contains($0.sessionId) }
            let volume = periodLogs.reduce(0.0) { total, log in
                guard let mode = measurementByExercise[log.exerciseId], mode.acceptsLoad, mode.recordsReps,
                      let weight = log.weightKg, weight.isFinite, weight > 0,
                      let reps = log.reps, reps > 0 else { return total }
                return total + weight * Double(reps)
            }
            return PeriodSummary(workoutCount: periodSessions.count, setCount: periodLogs.count, volumeKg: volume)
        }

        recent = summary(from: recentStart, to: now.addingTimeInterval(0.001))
        previous = summary(from: previousStart, to: recentStart)

        trends = Self.makeTrends(exercises: exercises, logs: validLogs, finishedByID: finishedByID)
    }

    private static func makeTrends(exercises: [Exercise], logs: [SetLog], finishedByID: [UUID: WorkoutSession]) -> [ExerciseTrend] {
        let logsByExercise = Dictionary(grouping: logs, by: \.exerciseId)
        var result: [ExerciseTrend] = []
        for exercise in exercises {
            guard let exerciseLogs = logsByExercise[exercise.id] else { continue }
            let mode = exercise.measurementMode
            let metric: TrendMetric = switch mode {
            case .externalLoadAndReps: .weightKg
            case .bodyweightAndReps: .reps
            case .bodyweightAndDuration, .duration, .externalLoadAndDuration: .durationSeconds
            }
            let grouped = Dictionary(grouping: exerciseLogs, by: \.sessionId)
            var points: [TrendPoint] = []
            for (sessionID, setLogs) in grouped {
                guard let session = finishedByID[sessionID],
                      let point = Self.bestPoint(session: session, logs: setLogs, metric: metric) else { continue }
                points.append(point)
            }
            points.sort { left, right in
                left.date == right.date ? left.id.uuidString < right.id.uuidString : left.date < right.date
            }
            guard !points.isEmpty else { continue }
            result.append(ExerciseTrend(id: exercise.id, name: exercise.displayName, metric: metric,
                                        loadIsAdditional: mode.loadIsAdditional, points: Array(points.suffix(12))))
        }
        result.sort { left, right in
            let leftDate = left.points.last?.date ?? .distantPast
            let rightDate = right.points.last?.date ?? .distantPast
            return leftDate == rightDate ? left.name < right.name : leftDate > rightDate
        }
        return result
    }

    private static func bestPoint(session: WorkoutSession, logs: [SetLog], metric: TrendMetric) -> TrendPoint? {
        var bestValue: Double?
        var bestReps: Int?
        var bestLoadKg: Double?
        for log in logs {
            let candidate: Double
            let candidateReps: Int?
            switch metric {
            case .weightKg:
                guard let weight = log.weightKg, weight.isFinite, weight > 0,
                      let reps = log.reps, reps > 0 else { continue }
                candidate = weight
                candidateReps = reps
            case .reps:
                guard let reps = log.reps, reps > 0 else { continue }
                candidate = Double(reps)
                candidateReps = nil
            case .durationSeconds:
                guard let seconds = log.durationSeconds, seconds.isFinite, seconds > 0 else { continue }
                candidate = seconds
                candidateReps = nil
            }
            let shouldReplace: Bool
            if let bestValue {
                shouldReplace = candidate > bestValue ||
                    (candidate == bestValue && (candidateReps ?? 0) > (bestReps ?? 0))
            } else {
                shouldReplace = true
            }
            if shouldReplace {
                bestValue = candidate
                bestReps = candidateReps
                bestLoadKg = log.weightKg.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            }
        }
        guard let bestValue else { return nil }
        return TrendPoint(id: session.id, date: session.startedAt, value: bestValue, reps: bestReps, loadKg: bestLoadKg)
    }
}

enum SetDefaultSource {
    case currentSession
    case history
}

struct SetDefaultValues {
    let weightKg: Double?
    let reps: Int?
    let source: SetDefaultSource?

    var hasAnyValue: Bool {
        weightKg != nil || reps != nil
    }
}

struct TrainingPlanDayDefinition {
    let name: String
    let exerciseNames: [String]
}

struct TrainingPlanDefinition {
    let name: String
    let dayDefinitions: [TrainingPlanDayDefinition]
}

enum WorkoutService {
    enum RepeatError: LocalizedError {
        case activeWorkout, noExercises
        var errorDescription: String? {
            L10n.string(self == .activeWorkout ? "请先完成或结束当前训练，再开始一键再练。" : "这次训练没有可复用的动作。")
        }
    }

    /// Copies the routine, never the completed logs or old timestamps.
    static func repeatWorkout(_ source: WorkoutSession, in context: ModelContext) throws -> WorkoutSession {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        guard !sessions.contains(where: { $0.status == .active }) else { throw RepeatError.activeWorkout }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let logs = try context.fetch(FetchDescriptor<SetLog>()).filter { $0.sessionId == source.id }
            .sorted { $0.createdAt < $1.createdAt }
        let available = Set(exercises.map(\.id))
        let ids = uniqueIds(source.exerciseIds + logs.map(\.exerciseId)).filter { available.contains($0) }
        guard !ids.isEmpty else { throw RepeatError.noExercises }
        var counts: [UUID: Int] = [:]
        var reps: [UUID: Int] = [:]
        for id in ids {
            let sets = logs.filter { $0.exerciseId == id }
            counts[id] = max(1, sets.isEmpty ? (source.targetSetCount(for: id) ?? 3) : sets.count)
            reps[id] = source.targetRepCount(for: id) ?? sets.last?.reps
        }
        let session = WorkoutSession(exerciseIds: ids, targetSetCounts: counts, targetRepCounts: reps)
        session.activeExerciseId = ids.first
        context.insert(session)
        do { try context.save() } catch {
            context.delete(session)
            throw error
        }
        return session
    }

    private static let threeSetExerciseNames: Set<String> = [
        "哑铃飞鸟", "绳索夹胸", "低位绳索夹胸", "蝴蝶机夹胸",
        "髋外展", "直臂下拉", "哑铃上拉", "侧平举", "绳索侧平举",
        "哑铃前平举", "俯身飞鸟", "反向蝴蝶机", "面拉", "杠铃耸肩",
        "哑铃耸肩", "二头弯举", "杠铃弯举", "锤式弯举", "上斜哑铃弯举",
        "绳索弯举", "反握弯举", "集中弯举", "三头下压", "绳索下压",
        "单臂绳索下压", "过顶臂屈伸", "绳索过顶臂屈伸", "仰卧臂屈伸",
        "腿屈伸", "腿弯举", "站姿小腿提踵", "坐姿小腿提踵", "小腿提踵",
        "平板支撑", "卷腹", "反向卷腹", "绳索卷腹", "悬垂举腿",
        "俄罗斯转体", "死虫", "鸟狗", "侧桥", "Pallof抗旋转", "罗马椅挺身",
        "壶铃摆动", "农夫行走", "药球砸地", "雪橇推", "战绳"
    ]

    static let defaultExercises = [
        "卧推",
        "上斜卧推",
        "下斜卧推",
        "窄握卧推",
        "史密斯卧推",
        "哑铃卧推",
        "上斜哑铃卧推",
        "下斜哑铃卧推",
        "器械推胸",
        "俯卧撑",
        "窄距俯卧撑",
        "双杠臂屈伸",
        "哑铃飞鸟",
        "绳索夹胸",
        "低位绳索夹胸",
        "蝴蝶机夹胸",
        "深蹲",
        "前蹲",
        "高脚杯深蹲",
        "箱式深蹲",
        "史密斯深蹲",
        "哈克深蹲",
        "保加利亚分腿蹲",
        "弓步蹲",
        "反向箭步蹲",
        "台阶上步",
        "硬拉",
        "相扑硬拉",
        "罗马尼亚硬拉",
        "臀推",
        "臀桥",
        "髋外展",
        "引体向上",
        "中立握引体向上",
        "反手引体向上",
        "反向划船",
        "高位下拉",
        "反握高位下拉",
        "窄握下拉",
        "直臂下拉",
        "坐姿划船",
        "单臂哑铃划船",
        "杠铃划船",
        "T杠划船",
        "胸托划船",
        "哑铃上拉",
        "肩推",
        "军用推举",
        "史密斯肩推",
        "哑铃肩推",
        "阿诺德推举",
        "侧平举",
        "绳索侧平举",
        "哑铃前平举",
        "俯身飞鸟",
        "反向蝴蝶机",
        "面拉",
        "杠铃耸肩",
        "哑铃耸肩",
        "二头弯举",
        "杠铃弯举",
        "锤式弯举",
        "上斜哑铃弯举",
        "绳索弯举",
        "反握弯举",
        "集中弯举",
        "牧师椅弯举",
        "三头下压",
        "过顶臂屈伸",
        "仰卧臂屈伸",
        "绳索下压",
        "单臂绳索下压",
        "绳索过顶臂屈伸",
        "腿举",
        "腿屈伸",
        "腿弯举",
        "小腿提踵",
        "站姿小腿提踵",
        "坐姿小腿提踵",
        "平板支撑",
        "卷腹",
        "反向卷腹",
        "绳索卷腹",
        "悬垂举腿",
        "俄罗斯转体",
        "死虫",
        "鸟狗",
        "侧桥",
        "Pallof抗旋转",
        "罗马椅挺身",
        "壶铃摆动",
        "农夫行走",
        "药球砸地",
        "雪橇推",
        "战绳"
    ]

    static let defaultExerciseNames = Set(defaultExercises)

    static let defaultTemplateDefinitions: [(name: String, exerciseNames: [String])] = [
        ("三大项力量", ["卧推", "深蹲", "硬拉"]),
        ("上肢推拉", ["卧推", "杠铃划船", "肩推", "引体向上"]),
        ("手臂训练", ["二头弯举", "三头下压", "哑铃卧推"]),
        ("腿部力量", ["深蹲", "腿举", "硬拉"]),
        ("全身 A", ["深蹲", "卧推", "高位下拉", "罗马尼亚硬拉", "肩推", "平板支撑"]),
        ("全身 B", ["腿举", "哑铃卧推", "坐姿划船", "臀推", "侧平举", "卷腹"]),
        ("PPL 推日", ["卧推", "上斜卧推", "肩推", "侧平举", "三头下压", "双杠臂屈伸"]),
        ("PPL 拉日", ["引体向上", "杠铃划船", "高位下拉", "坐姿划船", "面拉", "二头弯举"]),
        ("PPL 腿日", ["深蹲", "罗马尼亚硬拉", "腿举", "腿屈伸", "腿弯举", "小腿提踵"]),
        ("上肢力量", ["卧推", "杠铃划船", "肩推", "引体向上", "上斜卧推", "面拉", "二头弯举", "三头下压"]),
        ("下肢力量", ["深蹲", "硬拉", "前蹲", "罗马尼亚硬拉", "腿举", "小腿提踵"]),
        ("胸背对抗", ["卧推", "引体向上", "上斜卧推", "坐姿划船", "哑铃飞鸟", "面拉"]),
        ("肩手臂", ["肩推", "侧平举", "俯身飞鸟", "杠铃弯举", "锤式弯举", "三头下压", "过顶臂屈伸"]),
        ("臀腿", ["臀推", "保加利亚分腿蹲", "罗马尼亚硬拉", "腿举", "腿弯举", "小腿提踵"]),
        ("核心稳定", ["平板支撑", "悬垂举腿", "卷腹", "俄罗斯转体", "农夫行走"]),
        ("经典 5x5", ["深蹲", "卧推", "杠铃划船", "肩推", "硬拉"]),
        ("全身入门", ["高脚杯深蹲", "器械推胸", "坐姿划船", "臀桥", "哑铃肩推", "死虫"]),
        ("全身肌肥大", ["前蹲", "哑铃卧推", "胸托划船", "罗马尼亚硬拉", "绳索侧平举", "绳索卷腹"]),
        ("PPL 推日胸重点", ["上斜卧推", "哑铃卧推", "器械推胸", "绳索夹胸", "侧平举", "绳索下压"]),
        ("PPL 推日肩重点", ["肩推", "史密斯肩推", "上斜哑铃卧推", "绳索侧平举", "反向蝴蝶机", "过顶臂屈伸"]),
        ("PPL 拉日背宽", ["引体向上", "高位下拉", "反握高位下拉", "直臂下拉", "单臂哑铃划船", "锤式弯举"]),
        ("PPL 拉日背厚", ["硬拉", "杠铃划船", "T杠划船", "胸托划船", "面拉", "杠铃弯举"]),
        ("PPL 腿日股四", ["深蹲", "前蹲", "哈克深蹲", "腿举", "腿屈伸", "站姿小腿提踵"]),
        ("PPL 腿日后链", ["罗马尼亚硬拉", "臀推", "腿弯举", "保加利亚分腿蹲", "罗马椅挺身", "坐姿小腿提踵"]),
        ("上肢 A", ["卧推", "杠铃划船", "上斜哑铃卧推", "高位下拉", "侧平举", "三头下压", "二头弯举"]),
        ("上肢 B", ["肩推", "引体向上", "器械推胸", "胸托划船", "反向蝴蝶机", "过顶臂屈伸", "锤式弯举"]),
        ("下肢 A", ["深蹲", "罗马尼亚硬拉", "腿举", "腿屈伸", "腿弯举", "站姿小腿提踵"]),
        ("下肢 B", ["硬拉", "前蹲", "臀推", "反向箭步蹲", "髋外展", "坐姿小腿提踵"]),
        ("胸部强化", ["卧推", "上斜哑铃卧推", "下斜卧推", "器械推胸", "蝴蝶机夹胸", "窄距俯卧撑"]),
        ("背部强化", ["引体向上", "杠铃划船", "高位下拉", "胸托划船", "直臂下拉", "面拉"]),
        ("肩部强化", ["肩推", "哑铃肩推", "绳索侧平举", "哑铃前平举", "反向蝴蝶机", "杠铃耸肩"]),
        ("手臂泵感", ["杠铃弯举", "上斜哑铃弯举", "绳索弯举", "仰卧臂屈伸", "单臂绳索下压", "绳索过顶臂屈伸"]),
        ("臀腿强化", ["臀推", "罗马尼亚硬拉", "保加利亚分腿蹲", "髋外展", "臀桥", "腿弯举"]),
        ("核心抗旋", ["平板支撑", "侧桥", "死虫", "鸟狗", "Pallof抗旋转", "农夫行走"]),
        ("体能收尾", ["壶铃摆动", "药球砸地", "战绳", "雪橇推", "农夫行走", "俄罗斯转体"])
    ]

    static let defaultTrainingPlanDefinitions: [TrainingPlanDefinition] = [
        TrainingPlanDefinition(
            name: "三分化基础",
            dayDefinitions: [
                TrainingPlanDayDefinition(name: "推日", exerciseNames: ["卧推", "上斜哑铃卧推", "肩推", "侧平举", "三头下压", "绳索过顶臂屈伸"]),
                TrainingPlanDayDefinition(name: "拉日", exerciseNames: ["引体向上", "杠铃划船", "高位下拉", "面拉", "二头弯举", "锤式弯举"]),
                TrainingPlanDayDefinition(name: "腿日", exerciseNames: ["深蹲", "罗马尼亚硬拉", "腿举", "腿屈伸", "腿弯举", "小腿提踵"])
            ]
        ),
        TrainingPlanDefinition(
            name: "四分化基础",
            dayDefinitions: [
                TrainingPlanDayDefinition(name: "胸三头", exerciseNames: ["卧推", "上斜卧推", "器械推胸", "绳索夹胸", "三头下压", "过顶臂屈伸"]),
                TrainingPlanDayDefinition(name: "背二头", exerciseNames: ["引体向上", "杠铃划船", "坐姿划船", "直臂下拉", "杠铃弯举", "锤式弯举"]),
                TrainingPlanDayDefinition(name: "腿臀", exerciseNames: ["深蹲", "哈克深蹲", "罗马尼亚硬拉", "臀推", "腿弯举", "站姿小腿提踵"]),
                TrainingPlanDayDefinition(name: "肩核心", exerciseNames: ["肩推", "侧平举", "反向蝴蝶机", "面拉", "平板支撑", "Pallof抗旋转"])
            ]
        ),
        TrainingPlanDefinition(
            name: "PPL 循环",
            dayDefinitions: [
                TrainingPlanDayDefinition(name: "Push", exerciseNames: ["卧推", "上斜卧推", "肩推", "侧平举", "三头下压", "双杠臂屈伸"]),
                TrainingPlanDayDefinition(name: "Pull", exerciseNames: ["引体向上", "杠铃划船", "高位下拉", "坐姿划船", "面拉", "二头弯举"]),
                TrainingPlanDayDefinition(name: "Legs", exerciseNames: ["深蹲", "罗马尼亚硬拉", "腿举", "腿屈伸", "腿弯举", "小腿提踵"])
            ]
        ),
        TrainingPlanDefinition(
            name: "上下肢循环",
            dayDefinitions: [
                TrainingPlanDayDefinition(name: "上肢 A", exerciseNames: ["卧推", "杠铃划船", "上斜哑铃卧推", "高位下拉", "侧平举", "三头下压", "二头弯举"]),
                TrainingPlanDayDefinition(name: "下肢 A", exerciseNames: ["深蹲", "罗马尼亚硬拉", "腿举", "腿屈伸", "腿弯举", "站姿小腿提踵"]),
                TrainingPlanDayDefinition(name: "上肢 B", exerciseNames: ["肩推", "引体向上", "器械推胸", "胸托划船", "反向蝴蝶机", "过顶臂屈伸", "锤式弯举"]),
                TrainingPlanDayDefinition(name: "下肢 B", exerciseNames: ["硬拉", "前蹲", "臀推", "反向箭步蹲", "髋外展", "坐姿小腿提踵"])
            ]
        ),
        TrainingPlanDefinition(
            name: "全身三练",
            dayDefinitions: [
                TrainingPlanDayDefinition(name: "全身 A", exerciseNames: ["深蹲", "卧推", "高位下拉", "罗马尼亚硬拉", "肩推", "平板支撑"]),
                TrainingPlanDayDefinition(name: "全身 B", exerciseNames: ["腿举", "哑铃卧推", "坐姿划船", "臀推", "侧平举", "卷腹"]),
                TrainingPlanDayDefinition(name: "全身 C", exerciseNames: ["前蹲", "器械推胸", "胸托划船", "腿弯举", "面拉", "Pallof抗旋转"])
            ]
        )
    ]

    static var defaultTemplateNames: Set<String> {
        Set(defaultTemplateDefinitions.map(\.name))
    }

    static var defaultTrainingPlanNames: Set<String> {
        Set(defaultTrainingPlanDefinitions.map(\.name))
    }

    static func officialTargetSetCount(templateName: String? = nil, exerciseName: String) -> Int {
        if templateName == "经典 5x5" {
            return 5
        }
        if templateName == "三大项力量" {
            return exerciseName == "硬拉" ? 3 : 5
        }
        return threeSetExerciseNames.contains(exerciseName) ? 3 : 4
    }

    static func officialTargetRepCount(templateName: String? = nil, exerciseName: String) -> Int? {
        guard ExerciseMeasurementProfile.mode(for: exerciseName).recordsReps else {
            return nil
        }
        if templateName == "经典 5x5" || templateName == "三大项力量" {
            return 5
        }
        if threeSetExerciseNames.contains(exerciseName) {
            return 12
        }
        return 8
    }

    static func seedDefaultExercisesIfNeeded(in context: ModelContext) {
        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var existingNames = Set(existingExercises.map { normalizedName($0.name) })
        var didInsert = false

        for name in defaultExercises where !existingNames.contains(normalizedName(name)) {
            context.insert(Exercise(name: name))
            existingNames.insert(normalizedName(name))
            didInsert = true
        }

        if didInsert {
            save(context)
        }
    }

    static func createWorkout(in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession()
        context.insert(session)
        save(context)
        return session
    }

    static func createWorkout(from template: WorkoutTemplate, in context: ModelContext) -> WorkoutSession {
        let targetSetCounts = WorkoutTargetSets.normalized(
            template.targetSetCounts,
            for: template.exerciseIds,
            fallbackCount: WorkoutTargetSets.defaultCount
        )
        let session = WorkoutSession(
            exerciseIds: template.exerciseIds,
            targetSetCounts: targetSetCounts,
            targetRepCounts: WorkoutTargetReps.normalized(
                template.targetRepCounts,
                for: template.exerciseIds
            )
        )
        session.activeExerciseId = template.exerciseIds.first
        context.insert(session)
        save(context)
        return session
    }

    static func createWorkout(from planDay: TrainingPlanDay, plan: TrainingPlan, in context: ModelContext) -> WorkoutSession {
        let exerciseIds = planDay.exerciseIds
        let targetSetCounts = WorkoutTargetSets.normalized(
            planDay.targetSetCounts,
            for: exerciseIds,
            fallbackCount: WorkoutTargetSets.defaultCount
        )
        let session = WorkoutSession(
            exerciseIds: exerciseIds,
            targetSetCounts: targetSetCounts,
            targetRepCounts: WorkoutTargetReps.normalized(
                planDay.targetRepCounts,
                for: exerciseIds
            )
        )
        session.activeExerciseId = exerciseIds.first
        context.insert(session)

        markOnlyTrainingPlanActive(plan, in: context)
        let planDays = (try? context.fetch(FetchDescriptor<TrainingPlanDay>())) ?? []
        advanceTrainingPlan(plan, after: planDay, allDays: planDays)
        save(context)
        return session
    }

    static func finish(_ session: WorkoutSession, endedAt: Date = Date(), in context: ModelContext) {
        session.status = .finished
        session.endedAt = endedAt
        save(context)
    }

    static func finish(sessionId: UUID, endedAt: Date = Date(), in context: ModelContext) {
        let allSessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        guard let session = allSessions.first(where: { $0.id == sessionId }) else {
            return
        }

        finish(session, endedAt: endedAt, in: context)
    }

    static func discard(_ session: WorkoutSession, setLogs: [SetLog], in context: ModelContext) {
        discard(sessionId: session.id, in: context)
    }

    static func discard(sessionId: UUID, in context: ModelContext) {
        let allSetLogs = (try? context.fetch(FetchDescriptor<SetLog>())) ?? []
        for setLog in allSetLogs where setLog.sessionId == sessionId {
            context.delete(setLog)
        }

        let allSessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        if let session = allSessions.first(where: { $0.id == sessionId }) {
            context.delete(session)
        }

        save(context)
    }

    static func addExercise(_ exercise: Exercise, to session: WorkoutSession, in context: ModelContext) {
        var exerciseIds = session.exerciseIds
        var targetSetCounts = session.targetSetCounts

        if !exerciseIds.contains(exercise.id) {
            if !targetSetCounts.isEmpty,
               let activeExerciseId = session.activeExerciseId,
               let activeIndex = exerciseIds.firstIndex(of: activeExerciseId) {
                exerciseIds.insert(exercise.id, at: exerciseIds.index(after: activeIndex))
            } else {
                exerciseIds.append(exercise.id)
            }
            session.exerciseIds = exerciseIds
        }

        if !targetSetCounts.isEmpty, targetSetCounts[exercise.id] == nil {
            targetSetCounts[exercise.id] = WorkoutTargetSets.defaultCount
            session.targetSetCounts = targetSetCounts
        }

        if !targetSetCounts.isEmpty,
           exercise.measurementMode.recordsReps,
           session.targetRepCount(for: exercise.id) == nil {
            var targetRepCounts = session.targetRepCounts
            targetRepCounts[exercise.id] = WorkoutTargetReps.defaultCount
            session.targetRepCounts = targetRepCounts
        }

        session.activeExerciseId = exercise.id
        save(context)
    }

    static func createCustomExercise(named rawName: String, in context: ModelContext) -> Exercise? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        if let existingExercise = existingExercises.first(where: { isSameExerciseName($0.name, name) }) {
            return existingExercise
        }

        let exercise = Exercise(name: name)
        context.insert(exercise)
        save(context)
        return exercise
    }

    static func seedDefaultTemplatesIfNeeded(in context: ModelContext) {
        let existingTemplates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var exerciseByName: [String: UUID] = [:]
        for exercise in exercises where exerciseByName[normalizedName(exercise.name)] == nil {
            exerciseByName[normalizedName(exercise.name)] = exercise.id
        }

        var existingTemplateByName = Dictionary(uniqueKeysWithValues: existingTemplates.map { ($0.name, $0) })
        var didChange = false

        for template in defaultTemplateDefinitions {
            let resolvedExercises = template.exerciseNames.compactMap { exerciseName -> (id: UUID, name: String)? in
                guard let id = exerciseByName[normalizedName(exerciseName)] else {
                    return nil
                }
                return (id, exerciseName)
            }
            let ids = resolvedExercises.map(\.id)
            guard !ids.isEmpty else {
                continue
            }

            let counts = Dictionary(uniqueKeysWithValues: resolvedExercises.map { resolvedExercise in
                (
                    resolvedExercise.id,
                    officialTargetSetCount(templateName: template.name, exerciseName: resolvedExercise.name)
                )
            })
            let repCounts = Dictionary(
                uniqueKeysWithValues: resolvedExercises.compactMap { resolvedExercise in
                    officialTargetRepCount(
                        templateName: template.name,
                        exerciseName: resolvedExercise.name
                    ).map { (resolvedExercise.id, $0) }
                }
            )

            if let existingTemplate = existingTemplateByName[template.name] {
                if existingTemplate.exerciseIds != ids {
                    existingTemplate.exerciseIds = ids
                    didChange = true
                }
                if existingTemplate.targetSetCounts != counts {
                    existingTemplate.targetSetCounts = counts
                    didChange = true
                }
                if existingTemplate.targetRepCounts != repCounts {
                    existingTemplate.targetRepCounts = repCounts
                    didChange = true
                }
            } else {
                let newTemplate = WorkoutTemplate(
                    name: template.name,
                    exerciseIds: ids,
                    targetSetCounts: counts,
                    targetRepCounts: repCounts
                )
                context.insert(newTemplate)
                existingTemplateByName[template.name] = newTemplate
                didChange = true
            }
        }
        if didChange {
            save(context)
        }
    }

    static func seedDefaultTrainingPlansIfNeeded(in context: ModelContext) {
        var plans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        var days = (try? context.fetch(FetchDescriptor<TrainingPlanDay>())) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var exerciseByName: [String: UUID] = [:]
        for exercise in exercises where exerciseByName[normalizedName(exercise.name)] == nil {
            exerciseByName[normalizedName(exercise.name)] = exercise.id
        }

        var planByName = Dictionary(uniqueKeysWithValues: plans.map { ($0.name, $0) })
        var didChange = false

        for (planIndex, definition) in defaultTrainingPlanDefinitions.enumerated() {
            let plan: TrainingPlan
            if let existingPlan = planByName[definition.name] {
                plan = existingPlan
                if !plan.isOfficial {
                    plan.isOfficial = true
                    didChange = true
                }
                if plan.sortIndex != planIndex {
                    plan.sortIndex = planIndex
                    didChange = true
                }
            } else {
                let newPlan = TrainingPlan(
                    name: definition.name,
                    isOfficial: true,
                    sortIndex: planIndex
                )
                context.insert(newPlan)
                plans.append(newPlan)
                planByName[definition.name] = newPlan
                plan = newPlan
                didChange = true
            }

            var existingDaysByName = Dictionary(uniqueKeysWithValues: days.filter { $0.planId == plan.id }.map { ($0.name, $0) })
            for (dayIndex, dayDefinition) in definition.dayDefinitions.enumerated() {
                let resolvedExercises = dayDefinition.exerciseNames.compactMap { exerciseName -> (id: UUID, name: String)? in
                    guard let id = exerciseByName[normalizedName(exerciseName)] else {
                        return nil
                    }
                    return (id, exerciseName)
                }
                let exerciseIds = resolvedExercises.map(\.id)
                guard !exerciseIds.isEmpty else {
                    continue
                }

                let targetSetCounts = Dictionary(
                    uniqueKeysWithValues: resolvedExercises.map { resolvedExercise in
                        (resolvedExercise.id, officialTargetSetCount(exerciseName: resolvedExercise.name))
                    }
                )
                let targetRepCounts = Dictionary(
                    uniqueKeysWithValues: resolvedExercises.compactMap { resolvedExercise in
                        officialTargetRepCount(exerciseName: resolvedExercise.name).map {
                            (resolvedExercise.id, $0)
                        }
                    }
                )

                if let existingDay = existingDaysByName[dayDefinition.name] {
                    if existingDay.sortIndex != dayIndex {
                        existingDay.sortIndex = dayIndex
                        didChange = true
                    }
                    if existingDay.exerciseIds != exerciseIds {
                        existingDay.exerciseIds = exerciseIds
                        didChange = true
                    }
                    if existingDay.targetSetCounts != targetSetCounts {
                        existingDay.targetSetCounts = targetSetCounts
                        didChange = true
                    }
                    if existingDay.targetRepCounts != targetRepCounts {
                        existingDay.targetRepCounts = targetRepCounts
                        didChange = true
                    }
                } else {
                    let day = TrainingPlanDay(
                        planId: plan.id,
                        name: dayDefinition.name,
                        sortIndex: dayIndex,
                        exerciseIds: exerciseIds,
                        targetSetCounts: targetSetCounts,
                        targetRepCounts: targetRepCounts
                    )
                    context.insert(day)
                    days.append(day)
                    existingDaysByName[day.name] = day
                    didChange = true
                }
            }
        }

        if didChange {
            save(context)
        }
    }

    static func activeTrainingPlan(from plans: [TrainingPlan]) -> TrainingPlan? {
        plans.first(where: \.isActive)
    }

    static func trainingPlanDays(for plan: TrainingPlan, from days: [TrainingPlanDay]) -> [TrainingPlanDay] {
        days
            .filter { $0.planId == plan.id }
            .sorted {
                if $0.sortIndex == $1.sortIndex {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortIndex < $1.sortIndex
            }
    }

    static func nextTrainingPlanDay(for plan: TrainingPlan, from days: [TrainingPlanDay]) -> TrainingPlanDay? {
        let orderedDays = trainingPlanDays(for: plan, from: days)
        guard !orderedDays.isEmpty else {
            return nil
        }

        let index = ((plan.selectedDayIndex % orderedDays.count) + orderedDays.count) % orderedDays.count
        return orderedDays[index]
    }

    static func setActiveTrainingPlan(_ plan: TrainingPlan, in context: ModelContext) {
        markOnlyTrainingPlanActive(plan, in: context)
        save(context)
    }

    static func createUserTrainingPlan(
        named rawName: String,
        dayDrafts: [TrainingPlanDayDraft],
        in context: ModelContext
    ) -> TrainingPlan? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let drafts = normalizedDayDrafts(dayDrafts)
        guard !name.isEmpty, !drafts.isEmpty else {
            return nil
        }

        let existingPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        guard !existingPlans.contains(where: { $0.name == name }) else {
            return nil
        }

        let userSortIndex = (existingPlans.map(\.sortIndex).max() ?? defaultTrainingPlanDefinitions.count) + 1
        let plan = TrainingPlan(name: name, sortIndex: userSortIndex)
        context.insert(plan)
        insertTrainingPlanDays(drafts, planId: plan.id, in: context)
        save(context)
        return plan
    }

    @discardableResult
    static func updateUserTrainingPlan(
        _ plan: TrainingPlan,
        name rawName: String,
        dayDrafts: [TrainingPlanDayDraft],
        existingDays: [TrainingPlanDay],
        in context: ModelContext
    ) -> Bool {
        guard !plan.isOfficial else {
            return false
        }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let drafts = normalizedDayDrafts(dayDrafts)
        guard !name.isEmpty, !drafts.isEmpty else {
            return false
        }

        let existingPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        guard !existingPlans.contains(where: { $0.id != plan.id && $0.name == name }) else {
            return false
        }

        plan.name = name
        for day in existingDays where day.planId == plan.id {
            context.delete(day)
        }
        insertTrainingPlanDays(drafts, planId: plan.id, in: context)
        plan.selectedDayIndex = min(max(plan.selectedDayIndex, 0), max(drafts.count - 1, 0))
        save(context)
        return true
    }

    static func deleteTrainingPlan(_ plan: TrainingPlan, days: [TrainingPlanDay], in context: ModelContext) {
        guard !plan.isOfficial else {
            return
        }

        for day in days where day.planId == plan.id {
            context.delete(day)
        }
        context.delete(plan)

        save(context)
    }

    static func saveCurrentWorkoutAsTemplate(
        session: WorkoutSession,
        name rawName: String,
        setLogs: [SetLog],
        in context: ModelContext
    ) -> WorkoutTemplate? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        let idsFromSets = setLogs
            .filter { $0.sessionId == session.id }
            .map(\.exerciseId)
        let exerciseIds = uniqueIds(session.exerciseIds + idsFromSets)
        guard !exerciseIds.isEmpty else {
            return nil
        }

        let completedSetCounts = Dictionary(grouping: setLogs.filter { $0.sessionId == session.id }, by: \.exerciseId)
            .mapValues(\.count)
        let targetSetCounts = Dictionary(uniqueKeysWithValues: exerciseIds.map { exerciseId in
            let count = session.targetSetCount(for: exerciseId)
                ?? completedSetCounts[exerciseId]
                ?? WorkoutTargetSets.defaultCount
            return (exerciseId, WorkoutTargetSets.normalizedCount(count))
        })
        let targetRepCounts = Dictionary(
            uniqueKeysWithValues: exerciseIds.compactMap { exerciseId in
                if let count = session.targetRepCount(for: exerciseId) {
                    return (exerciseId, WorkoutTargetReps.normalizedCount(count))
                }
                let lastCompletedReps = setLogs
                    .filter { $0.sessionId == session.id && $0.exerciseId == exerciseId }
                    .sorted { $0.setNumber > $1.setNumber }
                    .compactMap(\.reps)
                    .first
                return lastCompletedReps.map { (exerciseId, WorkoutTargetReps.normalizedCount($0)) }
            }
        )
        let template = WorkoutTemplate(
            name: name,
            exerciseIds: exerciseIds,
            targetSetCounts: targetSetCounts,
            targetRepCounts: targetRepCounts
        )
        context.insert(template)
        save(context)
        return template
    }

    @discardableResult
    static func addSet(
        session: WorkoutSession,
        exercise: Exercise,
        existingSets: [SetLog],
        in context: ModelContext,
        source: SetLogSource = .iphone,
        weightKg: Double? = nil,
        reps: Int? = nil,
        startedAt: Date? = nil,
        durationSeconds: Double? = nil
    ) -> SetLog {
        let orderedSets = setsForExercise(existingSets, session: session, exercise: exercise)
        let defaultValues = nextSetDefaultValues(
            session: session,
            exercise: exercise,
            existingSets: existingSets
        )

        let set = SetLog(
            sessionId: session.id,
            exerciseId: exercise.id,
            setNumber: WorkoutLogic.nextSetNumber(existingSetCount: orderedSets.count),
            weightKg: weightKg ?? defaultValues.weightKg,
            reps: reps ?? defaultValues.reps,
            targetReps: session.targetRepCount(for: exercise.id),
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            source: source,
            syncStatus: .synced
        )

        if !session.exerciseIds.contains(exercise.id) {
            var exerciseIds = session.exerciseIds
            exerciseIds.append(exercise.id)
            session.exerciseIds = exerciseIds
        }
        session.activeExerciseId = exercise.id
        context.insert(set)
        save(context)
        return set
    }

    static func nextSetDefaultValues(
        session: WorkoutSession,
        exercise: Exercise,
        existingSets: [SetLog]
    ) -> SetDefaultValues {
        if let previousSet = setsForExercise(existingSets, session: session, exercise: exercise).last {
            return SetDefaultValues(
                weightKg: previousSet.weightKg,
                reps: previousSet.reps,
                source: .currentSession
            )
        }

        let rememberedValues = rememberedSetValues(
            for: exercise,
            excluding: session,
            existingSets: existingSets
        )

        return SetDefaultValues(
            weightKg: rememberedValues.weightKg,
            reps: rememberedValues.reps,
            source: rememberedValues.weightKg != nil || rememberedValues.reps != nil ? .history : nil
        )
    }

    static func deleteLastSet(
        session: WorkoutSession,
        exercise: Exercise,
        existingSets: [SetLog],
        in context: ModelContext
    ) {
        let orderedSets = setsForExercise(existingSets, session: session, exercise: exercise)
        guard let lastSet = orderedSets.last else {
            return
        }

        context.delete(lastSet)
        renumber(orderedSets.dropLast())
        save(context)
    }

    static func renumberSets(
        session: WorkoutSession,
        exercise: Exercise,
        existingSets: [SetLog],
        in context: ModelContext
    ) {
        let orderedSets = setsForExercise(existingSets, session: session, exercise: exercise)
        renumber(orderedSets)
        save(context)
    }

    static func updateRestTiming(
        setId: UUID?,
        existingSets: [SetLog],
        in context: ModelContext,
        restStartedAt: Date,
        restDurationSeconds: Double
    ) {
        guard let setId else {
            return
        }

        let set = existingSets.first(where: { $0.id == setId })
            ?? ((try? context.fetch(FetchDescriptor<SetLog>())) ?? []).first(where: { $0.id == setId })
        guard let set else {
            return
        }

        set.restStartedAt = restStartedAt
        set.restDurationSeconds = max(0, restDurationSeconds)
        save(context)
    }

    static func setCount(for exercise: Exercise, in session: WorkoutSession, setLogs: [SetLog]) -> Int {
        setsForExercise(setLogs, session: session, exercise: exercise).count
    }

    static func exercisesUsed(in session: WorkoutSession, exercises: [Exercise], setLogs: [SetLog]) -> [Exercise] {
        let idsFromSets = setLogs
            .filter { $0.sessionId == session.id }
            .map(\.exerciseId)

        let orderedIds = uniqueIds(session.exerciseIds + idsFromSets)
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        return orderedIds.compactMap { byId[$0] }
    }

    static func exerciseCount(in session: WorkoutSession, setLogs: [SetLog]) -> Int {
        let idsFromSets = setLogs
            .filter { $0.sessionId == session.id }
            .map(\.exerciseId)
        return uniqueIds(session.exerciseIds + idsFromSets).count
    }

    static func totalSetCount(in session: WorkoutSession, setLogs: [SetLog]) -> Int {
        setLogs.filter { $0.sessionId == session.id }.count
    }

    static func durationText(for session: WorkoutSession, now: Date = Date()) -> String {
        WorkoutLogic.durationText(startedAt: session.startedAt, endedAt: session.endedAt, now: now)
    }

    static func setsForExercise(_ setLogs: [SetLog], session: WorkoutSession, exercise: Exercise) -> [SetLog] {
        setLogs
            .filter { $0.sessionId == session.id && $0.exerciseId == exercise.id }
            .sorted {
                if $0.setNumber == $1.setNumber {
                    return $0.createdAt < $1.createdAt
                }
                return $0.setNumber < $1.setNumber
            }
    }

    private static func renumber<S: Sequence>(_ sets: S) where S.Element == SetLog {
        for (index, set) in sets.enumerated() {
            set.setNumber = index + 1
        }
    }

    private static func rememberedSetValues(
        for exercise: Exercise,
        excluding session: WorkoutSession,
        existingSets: [SetLog]
    ) -> (weightKg: Double?, reps: Int?) {
        let historicalSet = existingSets
            .filter {
                $0.exerciseId == exercise.id
                    && $0.sessionId != session.id
                    && ($0.weightKg != nil || $0.reps != nil)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first

        return (historicalSet?.weightKg, historicalSet?.reps)
    }

    private static func uniqueIds(_ ids: [UUID]) -> [UUID] {
        WorkoutLogic.orderedUnique(ids)
    }

    private static func isSameExerciseName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func compareTrainingPlans(_ lhs: TrainingPlan, _ rhs: TrainingPlan) -> Bool {
        if lhs.isOfficial != rhs.isOfficial {
            return lhs.isOfficial && !rhs.isOfficial
        }

        if lhs.sortIndex == rhs.sortIndex {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.sortIndex < rhs.sortIndex
    }

    private static func markOnlyTrainingPlanActive(_ selectedPlan: TrainingPlan, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        for plan in plans {
            plan.isActive = plan.id == selectedPlan.id
        }
        selectedPlan.isActive = true
    }

    private static func advanceTrainingPlan(
        _ plan: TrainingPlan,
        after completedDay: TrainingPlanDay,
        allDays: [TrainingPlanDay]
    ) {
        let orderedDays = trainingPlanDays(for: plan, from: allDays)
        guard !orderedDays.isEmpty else {
            plan.selectedDayIndex = 0
            return
        }

        guard let completedIndex = orderedDays.firstIndex(where: { $0.id == completedDay.id }) else {
            plan.selectedDayIndex = min(plan.selectedDayIndex + 1, orderedDays.count - 1)
            return
        }

        plan.selectedDayIndex = (completedIndex + 1) % orderedDays.count
    }

    private static func normalizedDayDrafts(_ dayDrafts: [TrainingPlanDayDraft]) -> [TrainingPlanDayDraft] {
        dayDrafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let exerciseIds = uniqueIds(draft.exerciseIds)
            guard !name.isEmpty, !exerciseIds.isEmpty else {
                return nil
            }
            let targetSetCounts = WorkoutTargetSets.normalized(
                draft.targetSetCounts,
                for: exerciseIds,
                fallbackCount: WorkoutTargetSets.defaultCount
            )
            let targetRepCounts = WorkoutTargetReps.normalized(
                draft.targetRepCounts,
                for: exerciseIds
            )
            return TrainingPlanDayDraft(
                id: draft.id,
                name: name,
                exerciseIds: exerciseIds,
                targetSetCounts: targetSetCounts,
                targetRepCounts: targetRepCounts
            )
        }
    }

    private static func insertTrainingPlanDays(
        _ dayDrafts: [TrainingPlanDayDraft],
        planId: UUID,
        in context: ModelContext
    ) {
        for (index, draft) in dayDrafts.enumerated() {
            context.insert(
                TrainingPlanDay(
                    id: draft.id,
                    planId: planId,
                    name: draft.name,
                    sortIndex: index,
                    exerciseIds: draft.exerciseIds,
                    targetSetCounts: draft.targetSetCounts,
                    targetRepCounts: draft.targetRepCounts
                )
            )
        }
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}
