import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.trainingTheme) private var theme

    let session: WorkoutSession
    let setLogs: [SetLog]
    let exercises: [Exercise]
    var onRepeat: ((WorkoutSession) -> Void)? = nil
    @State private var repeatError: String?

    @State private var showingNoteEditor = false
    @State private var showingRecap = false

    private var sessionSets: [SetLog] {
        setLogs
            .filter { $0.sessionId == session.id }
            .sorted {
                if $0.exerciseId == $1.exerciseId {
                    if $0.setNumber == $1.setNumber {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.setNumber < $1.setNumber
                }
                return $0.createdAt < $1.createdAt
            }
    }

    private var exerciseGroups: [HistoryExerciseGroup] {
        let usedExercises = WorkoutService.exercisesUsed(in: session, exercises: exercises, setLogs: setLogs)

        return usedExercises.map { exercise in
            HistoryExerciseGroup(
                exercise: exercise,
                sets: WorkoutService.setsForExercise(setLogs, session: session, exercise: exercise)
            )
        }
    }

    private var totalExerciseDurationText: String {
        totalDurationText(sessionSets.compactMap(\.durationSeconds))
    }

    private var totalRestDurationText: String {
        totalDurationText(sessionSets.compactMap(\.restDurationSeconds))
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary

                    Button {
                        showingRecap = true
                    } label: {
                        Label("查看训练复盘", systemImage: "chart.bar.xaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .trainingButtonStyle(tint: theme.primary)

                    if onRepeat != nil {
                        Button {
                            do {
                                let next = try WorkoutService.repeatWorkout(session, in: modelContext)
                                HapticsService.startWorkout()
                                onRepeat?(next)
                            } catch { repeatError = error.localizedDescription }
                        } label: {
                            Label("一键再练", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .trainingButtonStyle(prominent: true, tint: theme.primary)
                        Text("复用动作顺序和组数；重量沿用最近记录，不复制已完成成绩。")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    FitnessSectionTitle(text: "动作明细")

                    if exerciseGroups.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(exerciseGroups) { group in
                                HistoryExerciseCard(group: group)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("无法开始训练", isPresented: Binding(get: { repeatError != nil }, set: { if !$0 { repeatError = nil } })) {
            Button("知道了", role: .cancel) { repeatError = nil }
        } message: { Text(repeatError ?? "") }
        .sheet(isPresented: $showingNoteEditor) {
            NavigationStack {
                WorkoutNoteEditorView(session: session)
            }
        }
        .sheet(isPresented: $showingRecap) {
            NavigationStack {
                WorkoutRecapPreviewView(session: session, setLogs: setLogs, exercises: exercises)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                HapticsService.openPanel()
                showingNoteEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    HStack(alignment: .top, spacing: 10) {
                        Text(notePreview)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        Spacer(minLength: 8)

                        Image(systemName: "square.and.pencil")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                GlassMetricView(
                    title: "训练时长",
                    value: WorkoutService.durationText(for: session)
                )

                Divider()
                    .frame(height: 54)

                GlassMetricView(
                    title: "动作",
                    value: "\(WorkoutService.exerciseCount(in: session, setLogs: setLogs))",
                    alignment: .trailing
                )

                Divider()
                    .frame(height: 54)

                GlassMetricView(
                    title: "总组数",
                    value: "\(sessionSets.count)",
                    alignment: .trailing
                )
            }

            HStack {
                GlassMetricView(
                    title: "动作总时长",
                    value: totalExerciseDurationText
                )

                Divider()
                    .frame(height: 54)

                GlassMetricView(
                    title: "休息总时长",
                    value: totalRestDurationText,
                    alignment: .trailing
                )
            }

            SharePosterButton(session: session, setLogs: setLogs, exercises: exercises)
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24, tint: theme.primary, interactive: true)
    }

    private var notePreview: String {
        let trimmed = session.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L10n.string("已完成训练 · 点这里补备注") : trimmed
    }

    private func totalDurationText(_ durations: [Double]) -> String {
        guard !durations.isEmpty else {
            return "-"
        }

        return WorkoutLogic.shortDurationText(seconds: durations.reduce(0, +)) ?? "-"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            SetCountGlyphView(size: 54)

            Text("没有组记录")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("这次训练没有保存任何组。")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .liquidGlassCard(cornerRadius: 26)
    }
}

private struct HistoryExerciseGroup: Identifiable {
    let exercise: Exercise
    let sets: [SetLog]

    var id: UUID {
        exercise.id
    }
}

private struct HistoryExerciseCard: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    let group: HistoryExerciseGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
            HStack(alignment: .center, spacing: 12) {
                ExerciseGlyphView(exerciseName: group.exercise.name, size: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(group.exercise.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    if let muscleGroup = group.exercise.muscleGroup, !muscleGroup.isEmpty {
                        Text(muscleGroup)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(L10n.count("count.sets", group.sets.count))
                    .font(.title3.bold())
                    .foregroundStyle(theme.primary)
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? "已展开" : "已收起"))
            .accessibilityHint(Text(isExpanded ? "点击收起动作明细" : "点击展开动作明细"))

            if isExpanded {
                VStack(spacing: 8) {
                    if group.sets.isEmpty {
                        Text("没有组记录")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(group.sets) { set in
                            HistorySetRow(set: set, measurementMode: group.exercise.measurementMode)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22)
    }
}

private struct HistorySetRow: View {
    @Environment(\.trainingTheme) private var theme

    let set: SetLog
    let measurementMode: ExerciseMeasurementMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("#\(set.setNumber)")
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
                    .frame(width: 44, alignment: .leading)
                    .monospacedDigit()

                if measurementMode.acceptsLoad {
                    metric(
                        title: measurementMode.loadIsAdditional ? "附加负重" : "重量",
                        value: weightText
                    )
                }

                if measurementMode.recordsReps {
                    metric(title: "实际 / 目标", value: repsText)
                } else {
                    metric(title: "持续时间", value: durationText)
                }

                Spacer(minLength: 8)

                Image(systemName: set.source == .appleWatch ? "applewatch" : "iphone")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(set.source == .appleWatch ? theme.primary : .secondary)
                    .frame(width: 28)
            }

            if let timingText {
                Label(timingText, systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let repComparison {
                Label(repComparison.text, systemImage: repComparison.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(repComparison.color)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weightText: String {
        guard let weightKg = set.weightKg, weightKg > 0 else {
            if measurementMode.loadIsAdditional {
                return L10n.string("自重")
            }
            return "-"
        }
        let formatted = L10n.format("weight.kg", WorkoutLogic.formattedWeight(weightKg))
        return measurementMode.loadIsAdditional ? "+\(formatted)" : formatted
    }

    private var repsText: String {
        guard let reps = set.reps else {
            return "-"
        }
        guard let targetReps = set.targetReps else {
            return "\(reps)"
        }
        return "\(reps) / \(targetReps)"
    }

    private var durationText: String {
        WorkoutLogic.shortDurationText(seconds: set.durationSeconds) ?? "-"
    }

    private var timingText: String? {
        var parts: [String] = []

        if !measurementMode.recordsDuration,
           let setDurationText = WorkoutLogic.shortDurationText(seconds: set.durationSeconds) {
            parts.append(L10n.format("history.exercise_duration", setDurationText))
        }

        if let restDurationText = WorkoutLogic.shortDurationText(seconds: set.restDurationSeconds) {
            parts.append(L10n.format("history.rest_duration", restDurationText))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var repComparison: (text: String, icon: String, color: Color)? {
        guard let reps = set.reps,
              let targetReps = set.targetReps else {
            return nil
        }

        switch WorkoutLogic.repTargetComparison(actualReps: reps, targetReps: targetReps) {
        case .below(let remaining):
            return (L10n.format("set.reps_below_target", remaining), "arrow.down.right", .secondary)
        case .achieved:
            return (L10n.string("完成目标"), "checkmark.circle.fill", theme.success)
        case .exceeded(let extra):
            return (L10n.format("set.reps_above_target", extra), "arrow.up.right", theme.success)
        case nil:
            return nil
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.string(title))
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 78, alignment: .leading)
    }
}
