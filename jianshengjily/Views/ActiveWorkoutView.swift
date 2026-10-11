import Combine
import SwiftData
import SwiftUI

struct WorkoutFinishSnapshot {
    let sessionId: UUID
    let startedAt: Date
    let endedAt: Date
    let setCount: Int

    var hasRecordedSets: Bool {
        setCount > 0
    }
}

private struct FinishWorkoutView: View {
    @Environment(\.trainingTheme) private var theme

    let title: String
    let message: String
    let actionTitle: String
    let isDiscarding: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Label("继续训练", systemImage: "arrow.left")
                            .frame(maxWidth: .infinity)
                    }
                    .trainingButtonStyle(prominent: true, tint: theme.primary)

                    Button(role: .destructive) {
                        onConfirm()
                    } label: {
                        Label(actionTitle, systemImage: isDiscarding ? "trash" : "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .trainingButtonStyle(tint: isDiscarding ? .red : theme.success)
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("结束训练")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

struct ActiveWorkoutView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query(sort: \SetLog.createdAt) private var setLogs: [SetLog]
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]

    let session: WorkoutSession
    var onWorkoutClosed: () -> Void = {}
    var onWorkoutFinished: (WorkoutFinishSnapshot) -> Void = { _ in }

    @State private var now = Date()
    @State private var showingExercisePicker = false
    @State private var selectedExerciseId: UUID?
    @State private var showingSaveTemplate = false
    @State private var showingNoteEditor = false
    @State private var showingFinishScreen = false
    @State private var pendingFinishSnapshot: WorkoutFinishSnapshot?
    @State private var templateName = ""
    @State private var isAutomaticallyFinishing = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var usedExercises: [Exercise] {
        WorkoutService.exercisesUsed(in: session, exercises: exercises, setLogs: setLogs)
    }

    private var focusedExercise: Exercise? {
        if let activeExerciseId = session.activeExerciseId,
            let activeExercise = usedExercises.first(where: { $0.id == activeExerciseId })
        {
            if !hasReachedTarget(for: activeExercise) {
                return activeExercise
            }

            if let activeIndex = usedExercises.firstIndex(where: { $0.id == activeExerciseId }) {
                let followingExercises = usedExercises[usedExercises.index(after: activeIndex)...]
                if let nextIncompleteExercise = followingExercises.first(where: { !hasReachedTarget(for: $0) }) {
                    return nextIncompleteExercise
                }
            }
        }

        return usedExercises.first(where: { !hasReachedTarget(for: $0) })
    }

    private var hasCompletedTargetedWorkout: Bool {
        !usedExercises.isEmpty
            && usedExercises.allSatisfy { exercise in
                session.targetSetCount(for: exercise.id) != nil && hasReachedTarget(for: exercise)
            }
    }

    private func hasReachedTarget(for exercise: Exercise) -> Bool {
        guard let targetSetCount = session.targetSetCount(for: exercise.id) else {
            return false
        }
        return WorkoutService.setCount(for: exercise, in: session, setLogs: setLogs) >= targetSetCount
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    workoutStatus

                    if usedExercises.isEmpty {
                        emptyWorkoutFocus
                    } else {
                        VStack(spacing: 12) {
                            ForEach(usedExercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("当前训练")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                workoutMenu
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            activeWorkoutBottomBar
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerView(session: session) { exercise in
                    selectedExerciseId = exercise.id
                }
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NavigationStack {
                WorkoutNoteEditorView(session: session)
            }
        }
        .navigationDestination(item: $selectedExerciseId) { exerciseId in
            if let exercise = exercises.first(where: { $0.id == exerciseId }) {
                ExerciseSetView(
                    session: session,
                    exercise: exercise,
                    onWorkoutCompleted: automaticallyFinishWorkout,
                    onAdvanceToExercise: { nextExerciseId in
                        withAnimation(.easeInOut(duration: 0.42)) {
                            selectedExerciseId = nextExerciseId
                        }
                    }
                )
                .id(exerciseId)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                ContentUnavailableView("动作不存在", systemImage: "exclamationmark.triangle")
            }
        }
        .onReceive(timer) { value in
            now = value
        }
        .alert("保存为模板", isPresented: $showingSaveTemplate) {
            TextField("模板名称", text: $templateName)
            Button("保存") {
                let template = WorkoutService.saveCurrentWorkoutAsTemplate(
                    session: session,
                    name: templateName,
                    setLogs: setLogs,
                    in: modelContext
                )
                if template == nil {
                    HapticsService.actionFailed()
                } else {
                    HapticsService.saveSucceeded()
                }
            }
            Button("取消", role: .cancel) {
                HapticsService.closePanel()
            }
        } message: {
            Text("下次可以直接从这个动作组合开始。")
        }
        .navigationDestination(isPresented: $showingFinishScreen) {
            FinishWorkoutView(
                title: finishConfirmationTitle,
                message: finishConfirmationMessage,
                actionTitle: finishConfirmationActionTitle,
                isDiscarding: !(pendingFinishSnapshot?.hasRecordedSets ?? hasRecordedSets),
                onCancel: {
                    pendingFinishSnapshot = nil
                    showingFinishScreen = false
                },
                onConfirm: {
                    finishOrDiscardWorkout()
                }
            )
        }
    }

    private var workoutStatus: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                TrainingStageLabel(text: "当前训练")

                Spacer()

                Text(workoutStatusText)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(WorkoutService.durationText(for: session, now: now))
                .font(.system(size: 58, weight: .black, design: .rounded))
                .tracking(-1.8)
                .foregroundStyle(theme.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.62)

            if let focusedExercise {
                focusedExerciseStrip(focusedExercise)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 30, tint: theme.primary)
    }

    private func focusedExerciseStrip(_ exercise: Exercise) -> some View {
        let completedCount = WorkoutService.setCount(for: exercise, in: session, setLogs: setLogs)

        return HStack(spacing: 12) {
            ExerciseGlyphView(exerciseName: exercise.name, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("下一步")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)

                Text(L10n.format("workout.continue_exercise", exercise.displayName))
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Text(
                session.targetSetCount(for: exercise.id).map { "\(completedCount)/\(L10n.count("count.sets", $0))" }
                    ?? L10n.count("count.sets", completedCount)
            )
            .font(.subheadline.weight(.black))
            .foregroundStyle(theme.primary)
            .monospacedDigit()

            if let targetReps = session.targetRepCount(for: exercise.id) {
                Text("× \(L10n.count("count.reps", targetReps))")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var workoutStatusText: String {
        if usedExercises.isEmpty {
            return L10n.string("还没有动作")
        }

        return L10n.format(
            "workout.exercise_set_summary",
            L10n.count("count.exercises", usedExercises.count),
            L10n.count("count.sets", totalSetCount)
        )
    }

    private var totalSetCount: Int {
        setLogs.filter { $0.sessionId == session.id }.count
    }

    private var hasRecordedSets: Bool {
        totalSetCount > 0
    }

    private var finishConfirmationTitle: String {
        (pendingFinishSnapshot?.hasRecordedSets ?? hasRecordedSets)
            ? L10n.string("结束本次训练？")
            : L10n.string("放弃本次训练？")
    }

    private var finishConfirmationActionTitle: String {
        (pendingFinishSnapshot?.hasRecordedSets ?? hasRecordedSets)
            ? L10n.string("结束训练")
            : L10n.string("放弃训练")
    }

    private var finishConfirmationMessage: String {
        if pendingFinishSnapshot?.hasRecordedSets ?? hasRecordedSets {
            return L10n.string("结束后会保存到历史记录；如果还在训练，可以继续回去记录下一组。")
        }

        return L10n.string("还没有记录任何组，放弃后不会出现在历史记录。")
    }

    private var emptyWorkoutFocus: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingStageLabel(text: "第一步")

            Text("添加第一个动作")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(.white)

            Text("从第一个动作开始。")
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .liquidGlassCard(cornerRadius: 24, tint: theme.primary)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let setCount = WorkoutService.setCount(for: exercise, in: session, setLogs: setLogs)
        let targetSetCount = session.targetSetCount(for: exercise.id)
        let isCompleted = targetSetCount.map { setCount >= $0 } ?? false
        let isActive = focusedExercise?.id == exercise.id

        return Button {
            HapticsService.switchExercise()
            selectedExerciseId = exercise.id
            session.activeExerciseId = exercise.id
        } label: {
            HStack(spacing: 14) {
                ExerciseGlyphView(exerciseName: exercise.name, size: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.displayName)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Text(
                        isCompleted
                            ? L10n.string("已完成")
                            : (isActive
                                ? L10n.string("当前动作 · 继续下一组")
                                : L10n.string("点进记录"))
                    )
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(isCompleted ? theme.success : (isActive ? theme.primary : .secondary))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(targetSetCount.map { "\(setCount)/\($0)" } ?? "\(setCount)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(theme.primary)
                        .monospacedDigit()

                    Text(L10n.string("组"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidGlassCard(cornerRadius: 24, tint: isActive ? theme.primary : nil, interactive: true)
    }

    private var primaryWorkoutButton: some View {
        Button {
            if hasCompletedTargetedWorkout {
                automaticallyFinishWorkout()
            } else if let focusedExercise {
                HapticsService.switchExercise()
                selectedExerciseId = focusedExercise.id
                session.activeExerciseId = focusedExercise.id
            } else {
                HapticsService.openPanel()
                showingExercisePicker = true
            }
        } label: {
            Label(primaryWorkoutButtonTitle, systemImage: primaryWorkoutButtonIcon)
                .frame(maxWidth: .infinity)
        }
        .trainingButtonStyle(prominent: true, tint: theme.primary)
    }

    private var activeWorkoutBottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 26)
            .allowsHitTesting(false)

            primaryWorkoutButton
                .padding(.horizontal, 16)
                .padding(.top, 5)
                .padding(.bottom, 2)
                .background {
                    Color.black
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                }
        }
        .offset(y: 7)
    }

    private var primaryWorkoutButtonTitle: String {
        if hasCompletedTargetedWorkout {
            return L10n.string("完成训练")
        }
        if let focusedExercise {
            return L10n.format("workout.continue_exercise", focusedExercise.displayName)
        }

        return L10n.string("添加动作")
    }

    private var primaryWorkoutButtonIcon: String {
        if hasCompletedTargetedWorkout {
            return "checkmark.circle.fill"
        }
        return focusedExercise == nil ? "plus" : "arrow.right"
    }

    private var workoutMenu: some View {
        Menu {
            Button {
                HapticsService.openPanel()
                showingExercisePicker = true
            } label: {
                Label("添加动作", systemImage: "plus")
            }

            Button {
                HapticsService.openPanel()
                showingNoteEditor = true
            } label: {
                Label("训练备注", systemImage: "note.text")
            }

            Button {
                requestSaveAsTemplate()
            } label: {
                Label("保存为模板", systemImage: "square.grid.2x2")
            }
            .disabled(usedExercises.isEmpty)

            Button(role: .destructive) {
                requestFinishConfirmation()
            } label: {
                Label("结束训练", systemImage: "checkmark")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("更多")
    }

    private func requestSaveAsTemplate() {
        HapticsService.openPanel()
        templateName = session.startedAt.formatted(date: .abbreviated, time: .omitted)
        showingSaveTemplate = true
    }

    private func requestFinishConfirmation() {
        pendingFinishSnapshot = WorkoutFinishSnapshot(
            sessionId: session.id,
            startedAt: session.startedAt,
            endedAt: Date(),
            setCount: totalSetCount
        )
        HapticsService.openPanel()
        showingFinishScreen = true
    }

    private func finishOrDiscardWorkout() {
        let snapshot =
            pendingFinishSnapshot
            ?? WorkoutFinishSnapshot(
                sessionId: session.id,
                startedAt: session.startedAt,
                endedAt: Date(),
                setCount: totalSetCount
            )
        pendingFinishSnapshot = nil
        onWorkoutFinished(snapshot)
        onWorkoutClosed()
    }

    private func automaticallyFinishWorkout() {
        guard !isAutomaticallyFinishing, session.status == .active else {
            return
        }
        isAutomaticallyFinishing = true
        let snapshot = WorkoutFinishSnapshot(
            sessionId: session.id,
            startedAt: session.startedAt,
            endedAt: Date(),
            setCount: totalSetCount
        )
        onWorkoutFinished(snapshot)
        onWorkoutClosed()
    }

}
