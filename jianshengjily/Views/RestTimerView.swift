import SwiftUI

enum RestAutomaticDestination: Equatable {
    case currentExercise
    case nextExercise
}

struct RestTimerView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var completedExerciseName: String? = nil
    // Read-only tutorial clock. Nil preserves the normal workout timer.
    var tutorialRemainingSeconds: Int? = nil
    var completedSetNumber: Int? = nil
    var completedSetDetail: String? = nil
    var targetSetCount: Int? = nil
    var nextExerciseName: String? = nil
    var automaticDestination: RestAutomaticDestination = .currentExercise
    var completedSetEditor: AnyView? = nil
    var onContinueCurrentExercise: () -> Void = {}
    var onMoveToNextExercise: (() -> Void)? = nil
    var onFinishWithoutNextExercise: () -> Void = {}
    var onCompletedSetEditorDismissed: () -> Void = {}
    var onRestFinished: (_ restStartedAt: Date, _ durationSeconds: TimeInterval) -> Void = { _, _ in }

    @State private var selectedSeconds = 90
    @State private var remainingSeconds = 90
    @State private var isRunning = true
    @State private var didComplete = false
    @State private var restStartedAt = Date()
    @State private var targetEndAt: Date? = Date().addingTimeInterval(90)
    @State private var didReportRest = false
    @State private var completionHaloExpanded = false
    @State private var isLeaving = false
    @State private var automaticContinuationTask: Task<Void, Never>?
    @State private var showingCompletedSetEditor = false

    private let presets = [60, 90, 120, 180]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TrainingGlassBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text(didComplete ? L10n.string("节奏很好") : L10n.string("休息"))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.opacity)

                    if let headerDetailText {
                        Text(headerDetailText)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                    }

                    timerDial

                    if let completedSetDetail {
                        Text(completedSetDetail)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.primary.opacity(0.12), in: Capsule())
                    }
                }
                .offset(y: -42)

                if didComplete {
                    completionControls
                        .offset(y: -14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 12) {
                        Button {
                            performRestPrimaryAction()
                        } label: {
                            Label(restPrimaryActionTitle, systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .trainingButtonStyle(
                            prominent: true, tint: remainingSeconds == 0 ? theme.success : theme.primary)

                        if completedSetEditor != nil {
                            Button {
                                automaticContinuationTask?.cancel()
                                HapticsService.openPanel()
                                showingCompletedSetEditor = true
                            } label: {
                                Label("修改刚才这组", systemImage: "pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .offset(y: -14)
                    .transition(.opacity)
                }

                Spacer()
            }
            .padding(24)

            timerMenu
                .padding(.top, 24)
                .padding(.trailing, 24)
        }
        .preferredColorScheme(.dark)
        .sheet(
            isPresented: $showingCompletedSetEditor,
            onDismiss: resumeRestAfterCompletedSetEdit
        ) {
            completedSetEditor
        }
        .onAppear {
            if let tutorialRemainingSeconds {
                remainingSeconds = tutorialRemainingSeconds
                return
            }
            restStartedAt = Date()
            didReportRest = false
            restartCountdown(seconds: selectedSeconds)
        }
        .onDisappear {
            automaticContinuationTask?.cancel()
            guard tutorialRemainingSeconds == nil else { return }
            reportRestIfNeeded()
        }
        .onChange(of: tutorialRemainingSeconds) { _, value in
            if let value { remainingSeconds = value }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && tutorialRemainingSeconds == nil {
                updateCountdownFromClock(animated: false)
            }
        }
        .task {
            guard tutorialRemainingSeconds == nil else { return }
            await runCountdownLoop()
        }
    }

    private var timerDial: some View {
        ZStack {
            if didComplete {
                Circle()
                    .fill(theme.success.opacity(0.10))
                    .scaleEffect(completionHaloExpanded ? 1.13 : 0.94)
                    .opacity(completionHaloExpanded ? 0.24 : 0.72)

                Circle()
                    .stroke(theme.success.opacity(0.22), lineWidth: 1)
                    .scaleEffect(completionHaloExpanded ? 1.23 : 1.02)
                    .opacity(completionHaloExpanded ? 0.05 : 0.55)
            }

            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 16)

            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    remainingSeconds == 0 ? theme.success : theme.primary,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: (remainingSeconds == 0 ? theme.success : theme.primary).opacity(0.42), radius: 16,
                    x: 0, y: 8)

            if didComplete {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.success)

                    Text(L10n.string("呼吸一下"))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                }
                .transition(.scale(scale: 0.82).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Text(timeText)
                        .font(.system(size: 78, weight: .black, design: .rounded))
                        .tracking(-2.0)
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.68)

                    Text(timerStateText)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.secondary)
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(width: 250, height: 250)
        .padding(12)
        .background(.white.opacity(0.055), in: Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            didComplete
                ? L10n.string("休息完成，正在进入下一步")
                : L10n.format("rest.countdown_accessibility", timeText)
        )
    }

    private var completionControls: some View {
        VStack(spacing: 14) {
            Text(completionMessage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.success)

                Text(transitionMessage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Button {
                continueAutomatically()
            } label: {
                Label(automaticActionTitle, systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .trainingButtonStyle(prominent: true, tint: theme.success)

            Button {
                restartCountdown(seconds: selectedSeconds)
            } label: {
                Text(L10n.string("再休息一轮"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var timerProgress: Double {
        guard selectedSeconds > 0 else {
            return 1
        }

        let elapsed = selectedSeconds - remainingSeconds
        return min(max(Double(elapsed) / Double(selectedSeconds), 0), 1)
    }

    private var timerStateText: String {
        return isRunning ? L10n.string("休息中") : L10n.string("已暂停")
    }

    private var timerMenu: some View {
        Menu {
            Button {
                HapticsService.timerPausedOrResumed()
                if remainingSeconds == 0 {
                    restartCountdown(seconds: selectedSeconds)
                } else if isRunning {
                    updateCountdownFromClock(animated: false)
                    isRunning = false
                    targetEndAt = nil
                } else {
                    isRunning = true
                    targetEndAt = Date().addingTimeInterval(TimeInterval(remainingSeconds))
                }
            } label: {
                Label(timerControlTitle, systemImage: timerControlIcon)
            }

            Section("休息时间") {
                ForEach(presets, id: \.self) { seconds in
                    Button("\(seconds / 60):\(String(format: "%02d", seconds % 60))") {
                        HapticsService.timerPresetChanged()
                        selectedSeconds = seconds
                        restartCountdown(seconds: seconds)
                    }
                }
            }

            if automaticDestination == .nextExercise {
                Button {
                    finishRestAndDismiss {
                        HapticsService.openPanel()
                        onContinueCurrentExercise()
                    }
                } label: {
                    Label(
                        L10n.format("rest.add_set", (completedSetNumber ?? 0) + 1),
                        systemImage: "plus.circle"
                    )
                }
            } else if let nextExerciseName, let onMoveToNextExercise {
                Button {
                    finishRestAndDismiss {
                        HapticsService.switchExercise()
                        onMoveToNextExercise()
                    }
                } label: {
                    Label(
                        L10n.format("rest.move_to_exercise", nextExerciseName),
                        systemImage: "arrow.right"
                    )
                }
            }

            Button {
                finishRestAndDismiss {
                    HapticsService.closePanel()
                    onFinishWithoutNextExercise()
                }
            } label: {
                Label("回到训练总览", systemImage: "list.bullet")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("更多")
    }

    private var restPrimaryActionTitle: String {
        switch automaticDestination {
        case .currentExercise:
            return L10n.format("rest.end_rest_start_set", (completedSetNumber ?? 0) + 1)
        case .nextExercise:
            guard let nextExerciseName else {
                return L10n.string("现在继续")
            }
            return L10n.format("rest.end_rest_start_exercise", nextExerciseName)
        }
    }

    private var timerControlTitle: String {
        if remainingSeconds == 0 {
            return L10n.string("再休息一轮")
        }

        return isRunning ? L10n.string("暂停计时") : L10n.string("继续计时")
    }

    private var timerControlIcon: String {
        if remainingSeconds == 0 {
            return "gobackward"
        }

        return isRunning ? "pause.fill" : "play.fill"
    }

    private var contextText: String? {
        guard let completedExerciseName else {
            return nil
        }

        if automaticDestination == .nextExercise,
           let completedSetNumber,
           let targetSetCount {
            return L10n.format(
                "rest.target_completed",
                completedExerciseName,
                completedSetNumber,
                targetSetCount
            )
        }

        if let completedSetNumber {
            return L10n.format("rest.completed_set", completedExerciseName, completedSetNumber)
        }

        return L10n.format("rest.completed_exercise", completedExerciseName)
    }

    private var headerDetailText: String? {
        didComplete ? completionDestinationTitle : contextText
    }

    private var completionDestinationTitle: String? {
        switch automaticDestination {
        case .currentExercise:
            guard let completedSetNumber else {
                return completedExerciseName
            }
            return L10n.format("rest.next_set_title", completedSetNumber + 1)
        case .nextExercise:
            return nextExerciseName
        }
    }

    private var completionMessage: String {
        switch automaticDestination {
        case .currentExercise:
            let nextSetNumber = (completedSetNumber ?? 0) + 1
            return L10n.format("rest.next_set_message", nextSetNumber)
        case .nextExercise:
            guard let nextExerciseName else {
                return L10n.string("休息完成，准备继续训练。")
            }
            return L10n.format("rest.next_exercise_message", nextExerciseName)
        }
    }

    private var transitionMessage: String {
        switch automaticDestination {
        case .currentExercise:
            return L10n.format("rest.transitioning_to_set", (completedSetNumber ?? 0) + 1)
        case .nextExercise:
            guard let nextExerciseName else {
                return L10n.string("正在回到训练")
            }
            return L10n.format("rest.transitioning_to_exercise", nextExerciseName)
        }
    }

    private var automaticActionTitle: String {
        switch automaticDestination {
        case .currentExercise:
            return L10n.format("rest.start_set", (completedSetNumber ?? 0) + 1)
        case .nextExercise:
            guard let nextExerciseName else {
                return L10n.string("现在继续")
            }
            return L10n.format("rest.start_exercise", nextExerciseName)
        }
    }

    private func runCountdownLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                updateCountdownFromClock(animated: true)
            }
        }
    }

    private func restartCountdown(seconds: Int) {
        automaticContinuationTask?.cancel()
        remainingSeconds = seconds
        isRunning = true
        didComplete = false
        completionHaloExpanded = false
        isLeaving = false
        targetEndAt = Date().addingTimeInterval(TimeInterval(seconds))
    }

    private func updateCountdownFromClock(animated: Bool) {
        guard isRunning, let targetEndAt else {
            return
        }

        let nextRemainingSeconds = max(0, Int(ceil(targetEndAt.timeIntervalSinceNow)))
        let applyChange = {
            remainingSeconds = nextRemainingSeconds
        }

        if animated {
            withAnimation(.snappy(duration: 0.18), applyChange)
        } else {
            applyChange()
        }

        if nextRemainingSeconds == 0, !didComplete {
            isRunning = false
            self.targetEndAt = nil
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.55)) {
                didComplete = true
            }
            withAnimation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 1.45).repeatForever(autoreverses: true)
            ) {
                completionHaloExpanded = true
            }
            HapticsService.timerCompleted()
            scheduleAutomaticContinuation()
        }
    }

    private func scheduleAutomaticContinuation() {
        automaticContinuationTask?.cancel()
        guard !showingCompletedSetEditor else {
            return
        }
        automaticContinuationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 900_000_000 : 2_400_000_000)
            guard !Task.isCancelled else {
                return
            }
            continueAutomatically()
        }
    }

    private func continueAutomatically() {
        switch automaticDestination {
        case .currentExercise:
            finishRestAndDismiss {
                onContinueCurrentExercise()
            }
        case .nextExercise:
            guard let onMoveToNextExercise else {
                finishRestAndDismiss {
                    onContinueCurrentExercise()
                }
                return
            }
            finishRestAndDismiss {
                HapticsService.switchExercise()
                onMoveToNextExercise()
            }
        }
    }

    private func performRestPrimaryAction() {
        switch automaticDestination {
        case .currentExercise:
            finishRestAndDismiss {
                HapticsService.closePanel()
                onContinueCurrentExercise()
            }
        case .nextExercise:
            guard let onMoveToNextExercise else {
                finishRestAndDismiss {
                    HapticsService.closePanel()
                    onContinueCurrentExercise()
                }
                return
            }
            finishRestAndDismiss {
                HapticsService.switchExercise()
                onMoveToNextExercise()
            }
        }
    }

    private func finishRestAndDismiss(_ action: @escaping () -> Void) {
        guard !isLeaving else {
            return
        }
        isLeaving = true
        automaticContinuationTask?.cancel()
        reportRestIfNeeded()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.28)) {
            action()
        }
    }

    private func resumeRestAfterCompletedSetEdit() {
        onCompletedSetEditorDismissed()
        updateCountdownFromClock(animated: false)
        if didComplete {
            scheduleAutomaticContinuation()
        }
    }

    private func reportRestIfNeeded() {
        guard !didReportRest else {
            return
        }

        didReportRest = true
        onRestFinished(restStartedAt, max(0, Date().timeIntervalSince(restStartedAt)))
    }

    private var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct WorkoutCompletionTransitionView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onComplete: () -> Void

    @State private var haloExpanded = false
    @State private var contentVisible = false
    @State private var didComplete = false

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(theme.success.opacity(0.11))
                        .scaleEffect(haloExpanded ? 1.24 : 0.88)
                        .opacity(haloExpanded ? 0.12 : 0.72)

                    Circle()
                        .stroke(theme.success.opacity(0.28), lineWidth: 1)
                        .scaleEffect(haloExpanded ? 1.12 : 0.96)
                        .opacity(haloExpanded ? 0.18 : 0.70)

                    Circle()
                        .fill(.white.opacity(0.055))
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.11), lineWidth: 1)
                        }

                    Image(systemName: "checkmark")
                        .font(.system(size: 62, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.success)
                }
                .frame(width: 210, height: 210)

                VStack(spacing: 12) {
                    Text(L10n.string("训练完成"))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(-1.0)
                        .foregroundStyle(.white)

                    Text(L10n.string("每一组都算数，今天稳稳完成了。"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 9) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.success)

                        Text(L10n.string("正在保存本次训练"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                Spacer()
            }
            .padding(28)
            .opacity(contentVisible ? 1 : 0)
            .scaleEffect(contentVisible ? 1 : 0.97)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.string("训练完成，每一组都算数，今天稳稳完成了。"))
        .task {
            HapticsService.finishWorkout()
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.55)) {
                contentVisible = true
            }
            withAnimation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 1.65).repeatForever(autoreverses: true)
            ) {
                haloExpanded = true
            }

            try? await Task.sleep(nanoseconds: reduceMotion ? 1_000_000_000 : 2_700_000_000)
            guard !Task.isCancelled, !didComplete else {
                return
            }
            didComplete = true
            onComplete()
        }
    }
}
