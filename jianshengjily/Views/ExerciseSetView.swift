import SwiftData
import SwiftUI
import UIKit

private enum SetCompletionFlowPhase: Equatable {
    case reps
    case rest
    case workoutCompletion
}

struct ExerciseSetView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query(sort: \SetLog.createdAt) private var setLogs: [SetLog]

    let session: WorkoutSession
    let exercise: Exercise
    var tutorialPhase: Int? = nil
    var onWorkoutCompleted: () -> Void = {}
    var onAdvanceToExercise: (UUID) -> Void = { _ in }

    @State private var showingSetCompletionFlow = false
    @State private var setCompletionFlowPhase: SetCompletionFlowPhase = .reps
    @State private var restAutomaticDestination: RestAutomaticDestination = .currentExercise
    @State private var feedbackText: String?
    @State private var feedbackID = UUID()
    @State private var completedSetNumberForRest: Int?
    @State private var completedSetDetailForRest: String?
    @State private var plannedWeightText = ""
    @State private var completedRepsText = ""
    @State private var didSeedPlannedValues = false
    @State private var weightValidationMessage: String?
    @State private var pendingCompletedWeight: Double?
    @State private var currentSetStartedAt: Date?
    @State private var currentSetFinishedAt: Date?
    @State private var completedSetIDForRest: UUID?
    @State private var isSetInProgress = false
    @State private var showingSetHistory = false
    @State private var isAddingExtraSet = false

    private var sets: [SetLog] {
        WorkoutService.setsForExercise(setLogs, session: session, exercise: exercise)
    }

    private var measurementMode: ExerciseMeasurementMode {
        exercise.measurementMode
    }

    private var usedExercises: [Exercise] {
        WorkoutService.exercisesUsed(in: session, exercises: exercises, setLogs: setLogs)
    }

    private var currentSetNumber: Int {
        sets.count + 1
    }

    private var targetSetCount: Int? {
        session.targetSetCount(for: exercise.id)
    }

    private var targetRepCount: Int? {
        guard measurementMode.recordsReps else {
            return nil
        }
        return session.targetRepCount(for: exercise.id)
    }

    private var hasReachedTarget: Bool {
        guard let targetSetCount else {
            return false
        }
        return sets.count >= targetSetCount
    }

    private var shouldShowTargetCompletion: Bool {
        hasReachedTarget && !isAddingExtraSet && !isSetInProgress
    }

    private var nextExercise: Exercise? {
        guard let currentIndex = usedExercises.firstIndex(where: { $0.id == exercise.id }) else {
            return nil
        }

        let nextIndex = usedExercises.index(after: currentIndex)
        guard nextIndex < usedExercises.endIndex else {
            return nil
        }

        return usedExercises[nextIndex]
    }

    private var nextDefaultValues: SetDefaultValues {
        WorkoutService.nextSetDefaultValues(
            session: session,
            exercise: exercise,
            existingSets: setLogs
        )
    }

    var body: some View {
        Group {
            if let tutorialPhase { tutorialFrame(phase: tutorialPhase) }
            else { workoutBody }
        }
    }

    private var workoutBody: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    focusHeader
                    quickSwitch

                    if isSetInProgress {
                        activeSetFocus
                    } else if shouldShowTargetCompletion {
                        targetCompletedFocus
                    } else {
                        weightEntryFocus
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 34)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                overflowMenu
            }
        }
        .sheet(isPresented: $showingSetHistory) {
            setHistorySheet
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
                .liquidGlassSafeAreaBar()
        }
        .onAppear {
            session.activeExerciseId = exercise.id
            seedPlannedValuesIfNeeded()
        }
        .onChange(of: plannedWeightText) { _, _ in
            weightValidationMessage = nil
        }
        .onDisappear {
            WorkoutService.renumberSets(
                session: session, exercise: exercise, existingSets: setLogs, in: modelContext)
        }
    }

    private var focusHeader: some View {
        HStack(spacing: 14) {
            ExerciseGlyphView(exerciseName: exercise.name, size: 58)

            VStack(alignment: .leading, spacing: 8) {
                TrainingStageLabel(
                    text: isSetInProgress ? "进行中" : (shouldShowTargetCompletion ? "目标达成" : "准备")
                )

                Text(exercise.displayName)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    statusChip(
                        shouldShowTargetCompletion
                            ? L10n.string("已完成")
                            : L10n.format("set.number", currentSetNumber),
                        foreground: .black,
                        background: theme.primary)
                    statusChip(
                        targetSetCount.map { "\(L10n.string("已完成")) \(sets.count)/\(L10n.count("count.sets", $0))" }
                            ?? L10n.format("set.completed_count", sets.count),
                        foreground: .secondary,
                        background: Color.white.opacity(0.08)
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 28, tint: theme.primary)
    }

    // Read-only tutorial rendering reuses the production components, but never
    // runs this screen's model-mutating lifecycle or action handlers.
    private func tutorialFrame(phase: Int) -> some View {
        ZStack {
            TrainingGlassBackground()
            if phase == 2 {
                RepsConfirmationView(
                    exerciseName: exercise.displayName, setNumber: 1, completedSetCount: 0,
                    targetSetCount: 3, setSummary: "20 kg", targetReps: 8, defaultSource: nil,
                    repsText: .constant("8"), confirmTitle: L10n.string("完成本组"),
                    confirmIcon: "checkmark", dismissAfterConfirm: false,
                    onCancel: {}, onConfirm: { false })
            } else {
                VStack(spacing: 24) {
                    focusHeader
                    if phase == 1 { activeSetFocus } else { weightEntryFocus }
                    Spacer(minLength: 0)
                    actionBar
                }.padding(20)
            }
        }
        .onAppear {
            plannedWeightText = "20"
            isSetInProgress = phase == 1
        }
        .onChange(of: phase) { _, value in isSetInProgress = value == 1 }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func statusChip(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background, in: Capsule())
    }

    private var weightEntryFocus: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                TrainingStageLabel(text: "下一步")

                Text(weightEntryTitle)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
            }

            if let targetRepCount {
                Label(
                    L10n.format("set.target_reps", targetRepCount),
                    systemImage: "scope"
                )
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(theme.primary.opacity(0.12), in: Capsule())
            }

            if measurementMode.acceptsLoad {
                VStack(spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        TextField("—", text: $plannedWeightText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 82, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.55)

                        Text("kg")
                            .font(.title.bold())
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, minHeight: 136)
                    .background(
                        Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

                    HStack(spacing: 12) {
                        weightStepButton(label: "-2.5", accessibilityLabel: "减少 2.5 kg") {
                            adjustPlannedWeight(by: -2.5)
                        }
                        .disabled((parseDouble(plannedWeightText) ?? 0) <= 0)

                        weightStepButton(label: "+2.5", accessibilityLabel: "增加 2.5 kg") {
                            adjustPlannedWeight(by: 2.5)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(theme.primary)

                    Text("本动作按持续时间记录")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("开始后正常完成动作，结束时会自动保存本组时长。")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }

            if let weightValidationMessage {
                Text(weightValidationMessage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red.opacity(0.9))
            } else if let defaultText = defaultValuesText(nextDefaultValues) {
                Text(defaultText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.primary.opacity(0.12), in: Capsule())
            } else {
                Text(weightEntryHint)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var targetCompletedFocus: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(theme.success)

            Text("计划组数已完成")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(-0.6)
                .foregroundStyle(.white)

            Text(
                nextExercise.map { L10n.format("workout.next_exercise", $0.displayName) }
                    ?? L10n.string("准备完成本次训练")
            )
            .font(.headline.weight(.bold))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .liquidGlassCard(cornerRadius: 28, tint: theme.success)
    }

    private var activeSetFocus: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                TrainingStageLabel(text: "专注")

                Text("正在做")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)

                Text(activeSetInstruction)
                    .font(.headline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
            }
            if let targetRepCount {
                Text(L10n.format("set.target_reps", targetRepCount))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(activeLoadText)
                .font(.system(size: 72, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.primary)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var weightEntryHint: String {
        if measurementMode.loadIsAdditional {
            return L10n.string("徒手完成填 0；负重时只填额外增加的重量。")
        }
        if measurementMode.recordsDuration {
            return L10n.string("重量记录器械或负重，完成后自动记录持续时间。")
        }
        return L10n.string("记录杠铃、哑铃或器械的实际重量。")
    }

    private var weightEntryTitle: String {
        if !measurementMode.acceptsLoad {
            return L10n.string("计时成绩")
        }
        return measurementMode.loadIsAdditional ? L10n.string("附加负重") : L10n.string("本组重量")
    }

    private var activeSetInstruction: String {
        if measurementMode.recordsReps {
            return L10n.format("set.finish_then_reps", currentSetNumber)
        }
        return L10n.format("第 %lld 组 · 完成后自动记录时长", currentSetNumber)
    }

    private var activeLoadText: String {
        guard measurementMode.acceptsLoad else {
            return L10n.string("计时中")
        }

        let weight = pendingCompletedWeight ?? parseDouble(plannedWeightText)
        return loadDisplayText(weightKg: weight)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                showingSetHistory = true
            } label: {
                Label("已完成组", systemImage: "list.bullet.rectangle")
            }
            .disabled(sets.isEmpty)

            Button(role: .destructive) {
                deleteLastSet()
            } label: {
                Label("撤销上一组", systemImage: "arrow.uturn.backward")
            }
            .disabled(sets.isEmpty)

            if hasReachedTarget, !isSetInProgress {
                Button {
                    prepareExtraSet()
                } label: {
                    Label(
                        L10n.format("rest.add_set", currentSetNumber),
                        systemImage: "plus.circle"
                    )
                }
            }

            if let nextExercise {
                Button {
                    finishExerciseAndAdvance(to: nextExercise)
                } label: {
                    Label(
                        L10n.format("workout.next_exercise", nextExercise.displayName),
                        systemImage: "arrow.right")
                }
            }

            if usedExercises.count > 1 {
                Section("切换动作") {
                    ForEach(usedExercises) { item in
                        if item.id != exercise.id {
                            Button(item.displayName) {
                                finishExerciseAndAdvance(to: item)
                            }
                        }
                    }
                }
            }

            Button {
                HapticsService.closePanel()
                dismiss()
            } label: {
                Label("回到训练", systemImage: "list.bullet")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("更多")
    }

    private var setHistorySheet: some View {
        NavigationStack {
            ZStack {
                TrainingGlassBackground()

                if sets.isEmpty {
                    ContentUnavailableView("还没有记录", systemImage: "list.bullet.rectangle")
                        .foregroundStyle(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(sets) { set in
                                SetLogRow(set: set, measurementMode: measurementMode)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("已完成组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        showingSetHistory = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var quickSwitch: some View {
        if usedExercises.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("本次动作")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(usedExercises) { item in
                            if item.id == exercise.id {
                                quickSwitchLabel(for: item, isSelected: true)
                            } else {
                                Button {
                                    finishExerciseAndAdvance(to: item)
                                } label: {
                                    quickSwitchLabel(for: item, isSelected: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func quickSwitchLabel(for item: Exercise, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
            } else {
                ExerciseGlyphView(exerciseName: item.name, size: 22)
            }

            Text(item.displayName)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isSelected ? .black : .white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? theme.primary : Color.white.opacity(0.10), in: Capsule())
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            if let feedbackText {
                Text(feedbackText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                handlePrimaryAction()
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .trainingButtonStyle(prominent: true, tint: isSetInProgress ? theme.success : theme.primary)

            if isSetInProgress {
                Button {
                    returnToWeightEntry()
                } label: {
                    Text(measurementMode.acceptsLoad ? L10n.string("改重量") : L10n.string("重新开始"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $showingSetCompletionFlow) {
            setCompletionFlow
        }
    }

    @ViewBuilder
    private var setCompletionFlow: some View {
        ZStack {
            switch setCompletionFlowPhase {
            case .reps:
                RepsConfirmationView(
                    exerciseName: exercise.displayName,
                    setNumber: currentSetNumber,
                    completedSetCount: sets.count,
                    targetSetCount: targetSetCount,
                    setSummary: loadDisplayText(weightKg: pendingCompletedWeight),
                    targetReps: targetRepCount,
                    defaultSource: nextDefaultValues.source,
                    repsText: $completedRepsText,
                    confirmTitle: repsConfirmationAction.title,
                    confirmIcon: repsConfirmationAction.icon,
                    dismissAfterConfirm: false,
                    onCancel: {
                        showingSetCompletionFlow = false
                    },
                    onConfirm: {
                        confirmCompletedSetAndStartRest()
                    }
                )
                .transition(.opacity)

            case .rest:
                restTimer
                    .transition(.opacity)

            case .workoutCompletion:
                WorkoutCompletionTransitionView {
                    onWorkoutCompleted()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: setCompletionFlowPhase)
    }

    private var restTimer: some View {
        RestTimerView(
            completedExerciseName: exercise.displayName,
            completedSetNumber: completedSetNumberForRest,
            completedSetDetail: completedSetDetailForRest,
            targetSetCount: targetSetCount,
            nextExerciseName: nextExercise?.displayName,
            automaticDestination: restAutomaticDestination,
            completedSetEditor: completedSetForRest.map { set in
                AnyView(
                    LastCompletedSetEditorView(
                        set: set,
                        measurementMode: measurementMode
                    )
                )
            },
            onContinueCurrentExercise: {
                if restAutomaticDestination == .nextExercise {
                    prepareExtraSet()
                } else {
                    showFeedback(L10n.format("rest.continue_exercise", exercise.displayName))
                }
            },
            onMoveToNextExercise: nextExercise.map { next in
                {
                    finishExerciseAndAdvance(to: next)
                }
            },
            onFinishWithoutNextExercise: {
                dismiss()
            },
            onCompletedSetEditorDismissed: {
                refreshCompletedSetAfterEditing()
            },
            onRestFinished: { restStartedAt, durationSeconds in
                recordRestForCompletedSet(restStartedAt: restStartedAt, durationSeconds: durationSeconds)
            }
        )
    }

    private var primaryActionTitle: String {
        if isSetInProgress {
            return L10n.string("做完了")
        }
        if shouldShowTargetCompletion {
            return nextExercise.map { L10n.format("rest.start_exercise", $0.displayName) }
                ?? L10n.string("完成训练")
        }
        return L10n.string("开始这一组")
    }

    private var primaryActionIcon: String {
        if isSetInProgress {
            return "checkmark"
        }
        return shouldShowTargetCompletion
            ? (nextExercise == nil ? "checkmark.circle.fill" : "arrow.right")
            : "play.fill"
    }

    private var repsConfirmationAction: (title: String, icon: String) {
        guard let targetSetCount, currentSetNumber >= targetSetCount else {
            return (L10n.string("记录并开始休息"), "timer")
        }
        if nextExercise != nil {
            return (L10n.string("记录并进入下一动作"), "arrow.right")
        }
        return (L10n.string("记录并完成训练"), "checkmark.circle.fill")
    }

    private func weightStepButton(
        label: String, accessibilityLabel: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string(accessibilityLabel))
    }

    private func handlePrimaryAction() {
        if isSetInProgress {
            finishCurrentSet()
        } else if shouldShowTargetCompletion {
            if let nextExercise {
                finishExerciseAndAdvance(to: nextExercise)
            } else {
                setCompletionFlowPhase = .workoutCompletion
                showingSetCompletionFlow = true
            }
        } else {
            startCurrentSet()
        }
    }

    private func prepareExtraSet() {
        isAddingExtraSet = true
        seedPlannedValuesIfNeeded()
        HapticsService.openPanel()
        showFeedback(L10n.format("rest.add_set", currentSetNumber))
    }

    private func startCurrentSet() {
        guard let plannedWeight = validatedPlannedWeight() else {
            return
        }

        pendingCompletedWeight = plannedWeight
        currentSetStartedAt = Date()
        currentSetFinishedAt = nil
        completedRepsText = ""
        isSetInProgress = true
        HapticsService.openPanel()
        showFeedback(
            L10n.format(
                "set.started",
                currentSetNumber,
                loadDisplayText(weightKg: plannedWeight)
            )
        )
    }

    private func finishCurrentSet() {
        if pendingCompletedWeight == nil {
            guard let plannedWeight = validatedPlannedWeight() else {
                isSetInProgress = false
                return
            }
            pendingCompletedWeight = plannedWeight
        }

        currentSetFinishedAt = Date()
        if measurementMode.recordsReps {
            completedRepsText = nextDefaultValues.reps.map(String.init) ?? ""
            setCompletionFlowPhase = .reps
            showingSetCompletionFlow = true
        } else {
            _ = recordCompletedSet(reps: nil)
        }
    }

    private func returnToWeightEntry() {
        pendingCompletedWeight = nil
        currentSetStartedAt = nil
        currentSetFinishedAt = nil
        completedRepsText = ""
        isSetInProgress = false
        HapticsService.closePanel()
        showFeedback(measurementMode.acceptsLoad ? L10n.string("可以重新输入重量") : L10n.string("可以重新开始这一组"))
    }

    private func validatedPlannedWeight() -> Double? {
        guard measurementMode.acceptsLoad else {
            weightValidationMessage = nil
            return 0
        }

        let trimmedWeight = plannedWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWeight.isEmpty, let plannedWeight = parseDouble(trimmedWeight), plannedWeight >= 0
        else {
            weightValidationMessage =
                measurementMode.loadIsAdditional
                ? L10n.string("徒手完成填 0；负重时只填额外增加的重量。")
                : L10n.string("先输入这一组重量。")
            HapticsService.actionFailed()
            showFeedback(
                measurementMode.loadIsAdditional ? L10n.string("先填写附加负重") : L10n.string("先输入本组重量"))
            return nil
        }

        weightValidationMessage = nil
        return plannedWeight
    }

    private func confirmCompletedSetAndStartRest() -> Bool {
        guard pendingCompletedWeight != nil else {
            showingSetCompletionFlow = false
            return false
        }

        guard let completedReps = parseInt(completedRepsText), completedReps > 0 else {
            HapticsService.actionFailed()
            return false
        }

        return recordCompletedSet(reps: completedReps)
    }

    private func recordCompletedSet(reps: Int?) -> Bool {
        guard let pendingCompletedWeight else {
            showingSetCompletionFlow = false
            return false
        }

        let fallbackFinishedAt = Date()
        let setFinishedAt = currentSetFinishedAt ?? fallbackFinishedAt
        let setStartedAt = currentSetStartedAt ?? setFinishedAt
        let durationSeconds = max(0, setFinishedAt.timeIntervalSince(setStartedAt))
        let newSet = WorkoutService.addSet(
            session: session,
            exercise: exercise,
            existingSets: setLogs,
            in: modelContext,
            weightKg: pendingCompletedWeight,
            reps: reps,
            startedAt: setStartedAt,
            durationSeconds: durationSeconds
        )
        self.pendingCompletedWeight = nil
        currentSetStartedAt = nil
        currentSetFinishedAt = nil
        completedSetIDForRest = newSet.id
        isSetInProgress = false
        isAddingExtraSet = false
        HapticsService.recordSet()
        completedSetNumberForRest = newSet.setNumber
        completedSetDetailForRest = completedSetDetailText(for: newSet)

        if let detail = completedSetDetailForRest {
            showFeedback(L10n.format("set.completed_detail", newSet.setNumber, detail))
        } else {
            showFeedback(L10n.format("set.completed", newSet.setNumber))
        }

        seedPlannedValues(from: newSet)
        let progression = WorkoutLogic.progression(
            afterCompleting: exercise.id,
            completedSetCount: newSet.setNumber,
            exerciseIds: usedExercises.map(\.id),
            targetSetCounts: session.targetSetCounts
        )

        switch progression {
        case .continueCurrentExercise:
            restAutomaticDestination = .currentExercise
            setCompletionFlowPhase = .rest
            showingSetCompletionFlow = true
        case .advanceToExercise(let nextExerciseId):
            guard exercises.contains(where: { $0.id == nextExerciseId }) else {
                restAutomaticDestination = .currentExercise
                setCompletionFlowPhase = .rest
                showingSetCompletionFlow = true
                return true
            }
            restAutomaticDestination = .nextExercise
            setCompletionFlowPhase = .rest
            showingSetCompletionFlow = true
        case .finishWorkout:
            setCompletionFlowPhase = .workoutCompletion
            showingSetCompletionFlow = true
        }
        return true
    }

    private func deleteLastSet() {
        guard let lastSet = sets.last else {
            return
        }

        WorkoutService.deleteLastSet(
            session: session, exercise: exercise, existingSets: setLogs, in: modelContext)
        HapticsService.deleteSet()
        showFeedback(L10n.format("set.undone", lastSet.setNumber))
    }

    private func finishExerciseAndAdvance(to nextExercise: Exercise) {
        session.activeExerciseId = nextExercise.id
        HapticsService.switchExercise()
        onAdvanceToExercise(nextExercise.id)
        showFeedback(L10n.format("workout.switched_to", nextExercise.displayName))
    }

    private func recordRestForCompletedSet(restStartedAt: Date, durationSeconds: TimeInterval) {
        WorkoutService.updateRestTiming(
            setId: completedSetIDForRest,
            existingSets: setLogs,
            in: modelContext,
            restStartedAt: restStartedAt,
            restDurationSeconds: durationSeconds
        )
    }

    private var completedSetForRest: SetLog? {
        guard let completedSetIDForRest else {
            return nil
        }
        return setLogs.first(where: { $0.id == completedSetIDForRest })
    }

    private func refreshCompletedSetAfterEditing() {
        guard let completedSetForRest else {
            return
        }
        completedSetNumberForRest = completedSetForRest.setNumber
        completedSetDetailForRest = completedSetDetailText(for: completedSetForRest)
        seedPlannedValues(from: completedSetForRest)
        showFeedback(L10n.string("刚才这组已更新"))
    }

    private func showFeedback(_ text: String) {
        let id = UUID()
        feedbackID = id

        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            feedbackText = text
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard feedbackID == id else {
                return
            }

            withAnimation(.easeOut(duration: 0.18)) {
                feedbackText = nil
            }
        }
    }

    private func seedPlannedValuesIfNeeded() {
        guard !didSeedPlannedValues else {
            return
        }

        didSeedPlannedValues = true
        seedPlannedValues(from: nextDefaultValues)
    }

    private func seedPlannedValues(from values: SetDefaultValues) {
        if measurementMode.acceptsLoad {
            plannedWeightText =
                values.weightKg.map(WorkoutLogic.formattedWeight)
                ?? (measurementMode.loadIsAdditional ? "0" : "")
        } else {
            plannedWeightText = "0"
        }
    }

    private func seedPlannedValues(from set: SetLog) {
        plannedWeightText = set.weightKg.map(WorkoutLogic.formattedWeight) ?? plannedWeightText
    }

    private func adjustPlannedWeight(by delta: Double) {
        let currentWeight = parseDouble(plannedWeightText) ?? 0
        let nextWeight = max(0, currentWeight + delta)
        plannedWeightText = WorkoutLogic.formattedWeight(nextWeight)
        weightValidationMessage = nil
        HapticsService.adjustWeight()
    }

    private func parseDouble(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : Double(normalized)
    }

    private func parseInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private func defaultValuesText(_ values: SetDefaultValues) -> String? {
        guard values.hasAnyValue,
            let detail = setValuesText(weightKg: values.weightKg, reps: values.reps)
        else {
            return nil
        }

        switch values.source {
        case .currentSession:
            return L10n.format("set.defaults_previous_set", detail)
        case .history:
            return L10n.format("set.defaults_previous_workout", detail)
        case nil:
            return nil
        }
    }

    private func completedSetDetailText(for set: SetLog) -> String? {
        var parts: [String] = []

        if measurementMode.acceptsLoad,
           let loadText = optionalLoadDisplayText(weightKg: set.weightKg) {
            parts.append(loadText)
        }

        if let reps = set.reps {
            if let targetReps = set.targetReps {
                parts.append(L10n.format("set.actual_target_reps", reps, targetReps))
                if let comparisonText = repComparisonText(actualReps: reps, targetReps: targetReps) {
                    parts.append(comparisonText)
                }
            } else {
                parts.append(L10n.count("count.reps", reps))
            }
        }

        if let durationText = WorkoutLogic.shortDurationText(seconds: set.durationSeconds) {
            parts.append(L10n.format("set.duration_value", durationText))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func setValuesText(weightKg: Double?, reps: Int?) -> String? {
        var parts: [String] = []

        if measurementMode.acceptsLoad,
            let loadText = optionalLoadDisplayText(weightKg: weightKg)
        {
            parts.append(loadText)
        }

        if let reps {
            parts.append(L10n.count("count.reps", reps))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func loadDisplayText(weightKg: Double?) -> String {
        optionalLoadDisplayText(weightKg: weightKg)
            ?? (measurementMode.loadIsAdditional ? L10n.string("自重") : L10n.string("计时中"))
    }

    private func optionalLoadDisplayText(weightKg: Double?) -> String? {
        guard measurementMode.acceptsLoad else {
            return nil
        }

        let weightKg = max(weightKg ?? 0, 0)
        if measurementMode.loadIsAdditional {
            guard weightKg > 0 else {
                return L10n.string("自重")
            }
            let formatted = L10n.format("weight.kg", WorkoutLogic.formattedWeight(weightKg))
            return L10n.format("附加负重 +%@", formatted)
        }

        return L10n.format("weight.kg", WorkoutLogic.formattedWeight(weightKg))
    }

    private func repComparisonText(actualReps: Int, targetReps: Int) -> String? {
        switch WorkoutLogic.repTargetComparison(actualReps: actualReps, targetReps: targetReps) {
        case .below(let remaining):
            return L10n.format("set.reps_below_target", remaining)
        case .achieved:
            return L10n.string("完成目标")
        case .exceeded(let extra):
            return L10n.format("set.reps_above_target", extra)
        case nil:
            return nil
        }
    }
}

private struct RepsConfirmationView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let setNumber: Int
    let completedSetCount: Int
    let targetSetCount: Int?
    let setSummary: String
    let targetReps: Int?
    let defaultSource: SetDefaultSource?
    @Binding var repsText: String
    let confirmTitle: String
    let confirmIcon: String
    var dismissAfterConfirm = true
    var onCancel: () -> Void
    var onConfirm: () -> Bool

    @State private var validationMessage: String?
    @State private var seededRepsText = ""

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                onCancel()
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("还没做完")

                            Spacer()

                            Text("完成本组")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Color.clear
                                .frame(width: 42, height: 42)
                        }

                        VStack(spacing: 8) {
                            Text(exerciseName)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .tracking(-0.7)
                                .foregroundStyle(.white)

                            Text(setProgressText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(setSummary)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(theme.primary)
                                .padding(.top, 8)
                        }
                        .padding(.top, 16)

                        Spacer(minLength: 30)

                        if let targetReps {
                            HStack(alignment: .lastTextBaseline, spacing: 7) {
                                Text("本组目标")
                                    .foregroundStyle(.secondary)
                                Text(L10n.count("count.reps", targetReps))
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(theme.primary)
                            }
                            .font(.subheadline.weight(.bold))
                        }

                        Text("实际完成")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 30)

                        HStack(spacing: 18) {
                            repsStepButton(systemImage: "minus", accessibilityLabel: "-1") {
                                adjustReps(by: -1)
                            }
                            .disabled(currentReps <= 0)

                            TextField("—", text: $repsText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 82, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(maxWidth: 170)

                            repsStepButton(systemImage: "plus", accessibilityLabel: "+1") {
                                adjustReps(by: 1)
                            }
                        }
                        .padding(.top, 8)

                        if let sourceText {
                            Text(sourceText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary.opacity(0.75))
                                .padding(.top, 8)
                        }

                        Group {
                            if let comparisonText {
                                Label(comparisonText.text, systemImage: comparisonText.icon)
                                    .foregroundStyle(comparisonText.color)
                            } else if let validationMessage {
                                Text(validationMessage)
                                    .foregroundStyle(.red.opacity(0.9))
                            } else {
                                Text(" ")
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(.headline.weight(.bold))
                        .frame(minHeight: 26)
                        .padding(.top, 24)

                        Spacer(minLength: 30)

                        VStack(spacing: 10) {
                    Button {
                        if onConfirm() {
                            if dismissAfterConfirm {
                                dismiss()
                            }
                        } else {
                                    validationMessage = L10n.string("先输入这组做了几次。")
                                }
                            } label: {
                                Label(confirmTitle, systemImage: confirmIcon)
                                    .frame(maxWidth: .infinity)
                            }
                            .trainingButtonStyle(prominent: true, tint: theme.primary)

                            Button {
                                onCancel()
                                dismiss()
                            } label: {
                                Text("还没做完")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(24)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.always)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            seededRepsText = repsText
        }
        .onChange(of: repsText) { _, _ in
            validationMessage = nil
        }
    }

    private var currentReps: Int {
        Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private var setProgressText: String {
        if let targetSetCount {
            return "\(L10n.format("set.number", setNumber)) · \(L10n.string("已完成")) \(completedSetCount)/\(L10n.count("count.sets", targetSetCount))"
        }
        return L10n.format("set.number", setNumber)
    }

    private var sourceText: String? {
        guard !repsText.isEmpty, repsText == seededRepsText else {
            return nil
        }
        switch defaultSource {
        case .currentSession:
            return L10n.string("沿用上一组实际次数")
        case .history:
            return L10n.string("沿用上次训练实际次数")
        case nil:
            return nil
        }
    }

    private func repsStepButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.black))
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(accessibilityLabel)
    }

    private func adjustReps(by delta: Int) {
        let currentReps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        repsText = String(max(0, currentReps + delta))
        HapticsService.adjustReps()
    }

    private var comparisonText: (text: String, icon: String, color: Color)? {
        guard let actualReps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let targetReps else {
            return nil
        }

        switch WorkoutLogic.repTargetComparison(actualReps: actualReps, targetReps: targetReps) {
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
}

private struct LastCompletedSetEditorView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let set: SetLog
    let measurementMode: ExerciseMeasurementMode

    var body: some View {
        NavigationStack {
            ZStack {
                TrainingGlassBackground()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        TrainingStageLabel(text: "刚刚完成")

                        Text(L10n.format("set.edit_recent_title", set.setNumber))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .tracking(-0.5)
                            .foregroundStyle(.white)

                        Text(L10n.string("这里只修改刚完成的一组，完成后会回到休息计时。"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SetLogRow(set: set, measurementMode: measurementMode)

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle(L10n.string("修改刚才这组"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("回到休息")) {
                        HapticsService.closePanel()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(theme.primary)
                }
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct SetLogRow: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    @Bindable var set: SetLog
    let measurementMode: ExerciseMeasurementMode
    @State private var weightText = ""
    @State private var repsText = ""
    private let weightStepKg = 2.5
    private let repsStep = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.format("set.number", set.setNumber))
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                Spacer()
                Text(set.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                if measurementMode.acceptsLoad {
                    WeightInputField(
                        title: measurementMode.loadIsAdditional ? "附加负重 kg" : "重量 kg",
                        placeholder: "-",
                        value: $weightText,
                        canDecrease: (parseDouble(weightText) ?? 0) > 0,
                        onDecrease: {
                            adjustWeight(by: -weightStepKg)
                        },
                        onIncrease: {
                            adjustWeight(by: weightStepKg)
                        }
                    )
                }

                if measurementMode.recordsReps {
                    StepperInputField(
                        title: "实际次数",
                        placeholder: "-",
                        value: $repsText,
                        keyboardType: .numberPad,
                        decreaseLabel: "-1",
                        increaseLabel: "+1",
                        canDecrease: (parseInt(repsText) ?? 0) > 0,
                        onDecrease: {
                            adjustReps(by: -repsStep)
                        },
                        onIncrease: {
                            adjustReps(by: repsStep)
                        }
                    )

                    if let targetReps = set.targetReps {
                        Label(
                            L10n.format("set.target_reps", targetReps),
                            systemImage: "scope"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if measurementMode.recordsDuration {
                    HStack {
                        Label("本组时长", systemImage: "timer")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(WorkoutLogic.shortDurationText(seconds: set.durationSeconds) ?? "-")
                            .font(.title3.weight(.black))
                            .foregroundStyle(theme.primary)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .background(
                        .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22)
        .onAppear {
            weightText = set.weightKg.map(WorkoutLogic.formattedWeight) ?? ""
            repsText = set.reps.map(String.init) ?? ""
        }
        .onChange(of: weightText) { _, newValue in
            set.weightKg = parseDouble(newValue)
            save()
        }
        .onChange(of: repsText) { _, newValue in
            set.reps = parseInt(newValue)
            save()
        }
    }

    private func adjustWeight(by delta: Double) {
        let currentWeight = parseDouble(weightText) ?? 0
        let nextWeight = max(0, currentWeight + delta)
        weightText = WorkoutLogic.formattedWeight(nextWeight)
        HapticsService.adjustWeight()
    }

    private func adjustReps(by delta: Int) {
        let currentReps = parseInt(repsText) ?? 0
        let nextReps = max(0, currentReps + delta)
        repsText = String(nextReps)
        HapticsService.adjustReps()
    }

    private func parseDouble(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : Double(normalized)
    }

    private func parseInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}

private struct WeightInputField: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    var canDecrease: Bool
    var onDecrease: () -> Void
    var onIncrease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string(title))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                quickWeightButton(label: "-2.5", accessibilityLabel: "减少 2.5 kg", action: onDecrease)
                    .disabled(!canDecrease)

                TextField(L10n.string(placeholder), text: $value)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(minWidth: 62)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(
                        Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

                quickWeightButton(label: "+2.5", accessibilityLabel: "增加 2.5 kg", action: onIncrease)
            }
        }
    }

    private func quickWeightButton(
        label: String, accessibilityLabel: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .frame(width: 48, height: 42)
                .foregroundStyle(.white)
                .background(
                    Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string(accessibilityLabel))
    }
}

private struct StepperInputField: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    var keyboardType: UIKeyboardType
    var decreaseLabel: String
    var increaseLabel: String
    var canDecrease: Bool
    var onDecrease: () -> Void
    var onIncrease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string(title))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                quickButton(label: decreaseLabel, action: onDecrease)
                    .disabled(!canDecrease)

                TextField(L10n.string(placeholder), text: $value)
                    .keyboardType(keyboardType)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(minWidth: 46)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(
                        Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

                quickButton(label: increaseLabel, action: onIncrease)
            }
        }
    }

    private func quickButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 40, height: 42)
                .background(
                    Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
