import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \SetLog.createdAt) private var setLogs: [SetLog]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query(sort: \TrainingPlan.createdAt) private var trainingPlans: [TrainingPlan]
    @Query(sort: \TrainingPlanDay.sortIndex) private var trainingPlanDays: [TrainingPlanDay]

    @AppStorage("trainingTheme") private var selectedThemeRawValue = TrainingTheme.defaultTheme.rawValue
    @State private var activeSessionId: UUID?
    @State private var showingHistory = false
    @State private var showingTemplates = false
    @State private var showingTrainingPlans = false
    @State private var showingPR = false
    @State private var showingThemePicker = false
    @State private var showingAboutPrivacy = false
    @State private var showingQuickStart = false
    @AppStorage("onboarding.quickStartCompleted") private var quickStartCompleted = false
    @State private var recentlyOpenedSession: WorkoutSession?
    @State private var recapSession: WorkoutSession?

    private var currentSession: WorkoutSession? {
        sessions.first { $0.status == .active }
    }

    private var activeTrainingPlan: TrainingPlan? {
        WorkoutService.activeTrainingPlan(from: trainingPlans)
    }

    private var nextTrainingPlanDay: TrainingPlanDay? {
        guard let activeTrainingPlan else {
            return nil
        }

        return WorkoutService.nextTrainingPlanDay(for: activeTrainingPlan, from: trainingPlanDays)
    }

    private var activeTrainingPlanDays: [TrainingPlanDay] {
        guard let activeTrainingPlan else {
            return []
        }

        return trainingPlanDays
            .filter { $0.planId == activeTrainingPlan.id }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var weeklyWorkoutCount: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? .distantPast
        return sessions.filter { $0.status == .finished && $0.startedAt >= startOfWeek }.count
    }

    private var latestFinishedSession: WorkoutSession? {
        sessions.first { $0.status == .finished }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TrainingGlassBackground()

                VStack(alignment: .leading, spacing: 24) {
                    homeHeader
                        .padding(.top, 34)

                    Spacer(minLength: 12)

                    homeHeroCard

                    Spacer(minLength: 4)

                    VStack(spacing: 14) {
                        primaryHomeButton

                        if currentSession == nil {
                            if nextTrainingPlanDay != nil {
                                freeTrainingHomeButton
                            }
                            trainingPlanHomeButton
                            templateHomeButton
                        }
                    }
                }
                .padding(24)
            }
            .preferredColorScheme(.dark)
            .navigationDestination(item: $activeSessionId) { sessionId in
                if let session = sessionForNavigation(id: sessionId) {
                    ActiveWorkoutView(
                        session: session,
                        onWorkoutClosed: {
                            closeSessionNavigation()
                        },
                        onWorkoutFinished: { snapshot in
                            completeWorkoutFromSnapshot(snapshot)
                        }
                    )
                } else {
                    ContentUnavailableView("训练不存在", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationDestination(isPresented: $showingHistory) {
                HistoryView { session in
                    recentlyOpenedSession = session
                    showingHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { openSession(session) }
                }
            }
            .navigationDestination(isPresented: $showingTemplates) {
                TemplatesView { session in
                    openTemplateSession(session)
                }
            }
            .navigationDestination(isPresented: $showingTrainingPlans) {
                TrainingPlansView { session in
                    openTrainingPlanSession(session)
                }
            }
            .navigationDestination(isPresented: $showingPR) {
                PRView()
            }
            .navigationDestination(isPresented: $showingAboutPrivacy) {
                AboutPrivacyView()
            }
            .sheet(isPresented: $showingThemePicker) {
                NavigationStack {
                    ThemePickerView(selectedThemeRawValue: $selectedThemeRawValue)
                }
            }
            .sheet(item: $recapSession) { session in
                NavigationStack {
                    WorkoutRecapPreviewView(session: session, setLogs: setLogs, exercises: exercises)
                }
            }
            .sheet(isPresented: $showingQuickStart, onDismiss: {
                quickStartCompleted = true
            }) {
                QuickStartGuideView()
            }
            .task {
                if !quickStartCompleted {
                    showingQuickStart = true
                }
            }
            .task {
                WorkoutService.seedDefaultExercisesIfNeeded(in: modelContext)
                WorkoutService.seedDefaultTemplatesIfNeeded(in: modelContext)
                WorkoutService.seedDefaultTrainingPlansIfNeeded(in: modelContext)

            }
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                PowerTraceMarkView(size: 64, progress: 0.88)

                VStack(alignment: .leading, spacing: 3) {
                    Text("力迹")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .tracking(-1.6)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)

                    Text("力量训练记录")
                        .font(.subheadline.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    Button {
                        showingQuickStart = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("新手教程"))
                    homeMenu
                }
            }
        }
    }

    private var homeHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            TrainingStageLabel(text: currentSession == nil ? "今日训练" : "正在训练")

            VStack(alignment: .leading, spacing: 8) {
                Text(homeHeroTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(homeHeroSubtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let currentSession {
                homeActiveSessionMetrics(for: currentSession)
            } else {
                homeIdleSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .liquidGlassCard(cornerRadius: 32, tint: theme.primary)
    }

    private var homeHeroTitle: String {
        if let currentSession {
            return activeExerciseName(for: currentSession) ?? L10n.string("回到训练现场")
        }

        if let activeTrainingPlan, let nextTrainingPlanDay {
            return DefaultContentLocalization.trainingPlanDayName(nextTrainingPlanDay, plan: activeTrainingPlan)
        }

        return L10n.string("开始一场干净的记录")
    }

    private var homeHeroSubtitle: String {
        if currentSession == nil {
            if let activeTrainingPlan, nextTrainingPlanDay != nil {
                return L10n.format("home.plan_next_workout", activeTrainingPlan.displayName)
            }

            return L10n.string("记录重量、次数与组间休息。")
        }

        return L10n.string("训练进行中 · 继续记录下一组")
    }

    private func homeActiveSessionMetrics(for session: WorkoutSession) -> some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                homeMetricCell(
                    label: "时长",
                    value: WorkoutService.durationText(for: session, now: context.date)
                )
            }
            homeMetricDivider
            homeMetricCell(
                label: "动作",
                value: "\(WorkoutService.exerciseCount(in: session, setLogs: setLogs))"
            )
            homeMetricDivider
            homeMetricCell(
                label: "完成组",
                value: "\(WorkoutService.totalSetCount(in: session, setLogs: setLogs))"
            )
        }
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var homeIdleSummary: some View {
        HStack(spacing: 14) {
            if let nextTrainingPlanDay {
                homeSummaryItem(
                    label: "训练安排",
                    value: "\(L10n.count("count.exercises", nextTrainingPlanDay.exerciseIds.count))\n\(L10n.count("count.sets", nextTrainingPlanDay.exerciseIds.reduce(0) { $0 + nextTrainingPlanDay.targetSetCount(for: $1) }))",
                    systemImage: "list.bullet.rectangle"
                )

                Spacer(minLength: 12)

                Text(activePlanProgressText(for: nextTrainingPlanDay))
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.primary.opacity(0.11), in: Capsule())
            } else {
                homeSummaryItem(
                    label: "本周训练",
                    value: L10n.count("count.workouts", weeklyWorkoutCount),
                    systemImage: "calendar"
                )

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("最近记录")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(latestWorkoutText)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)
        }
    }

    private func homeSummaryItem(label: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(theme.primary)
                .frame(width: 32, height: 32)
                .background(theme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string(label))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func activePlanProgressText(for day: TrainingPlanDay) -> String {
        guard let index = activeTrainingPlanDays.firstIndex(where: { $0.id == day.id }) else {
            return L10n.string("下一练")
        }

        return L10n.format("home.plan_progress", index + 1, activeTrainingPlanDays.count)
    }

    private var latestWorkoutText: String {
        guard let latestFinishedSession else {
            return L10n.string("暂无")
        }

        if Calendar.current.isDateInToday(latestFinishedSession.startedAt) {
            return L10n.string("今天")
        }

        if Calendar.current.isDateInYesterday(latestFinishedSession.startedAt) {
            return L10n.string("昨天")
        }

        return latestFinishedSession.startedAt.formatted(.dateTime.month().day())
    }

    private func homeMetricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.black))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(L10n.string(label))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private var homeMetricDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 42)
    }

    private var primaryHomeButton: some View {
        Button {
            if let session = currentSession {
                HapticsService.continueWorkout()
                openSession(session)
            } else if let activeTrainingPlan, let nextTrainingPlanDay {
                HapticsService.startWorkout()
                openSession(WorkoutService.createWorkout(from: nextTrainingPlanDay, plan: activeTrainingPlan, in: modelContext))
            } else {
                HapticsService.startWorkout()
                openSession(WorkoutService.createWorkout(in: modelContext))
            }
        } label: {
            Label(primaryHomeButtonTitle, systemImage: primaryHomeButtonIcon)
                .frame(maxWidth: .infinity)
        }
        .trainingButtonStyle(prominent: true, tint: theme.primary)
    }

    private var primaryHomeButtonTitle: String {
        if currentSession != nil {
            return L10n.string("继续训练")
        }

        if nextTrainingPlanDay != nil {
            return L10n.string("开始下一练")
        }

        return L10n.string("开始训练")
    }

    private var primaryHomeButtonIcon: String {
        if currentSession != nil || nextTrainingPlanDay != nil {
            return "play.fill"
        }

        return "plus"
    }

    private var freeTrainingHomeButton: some View {
        Button {
            HapticsService.startWorkout()
            openSession(WorkoutService.createWorkout(in: modelContext))
        } label: {
            Label("自由训练", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .trainingButtonStyle(tint: .white)
    }

    private var trainingPlanHomeButton: some View {
        Button {
            HapticsService.openPanel()
            showingTrainingPlans = true
        } label: {
            Label("训练计划", systemImage: "calendar.badge.clock")
                .frame(maxWidth: .infinity)
        }
        .trainingButtonStyle(tint: .white)
    }

    private var templateHomeButton: some View {
        Button {
            HapticsService.openPanel()
            showingTemplates = true
        } label: {
            Label("从模板开始", systemImage: "square.grid.2x2")
                .frame(maxWidth: .infinity)
        }
        .trainingButtonStyle(tint: .white)
    }

    private func activeExerciseName(for session: WorkoutSession) -> String? {
        guard let activeExerciseId = session.activeExerciseId else {
            return nil
        }

        return exercises.first(where: { $0.id == activeExerciseId })?.displayName
    }

    private func openSession(_ session: WorkoutSession) {
        recentlyOpenedSession = session
        activeSessionId = session.id
    }

    private func openTemplateSession(_ session: WorkoutSession) {
        recentlyOpenedSession = session
        showingTemplates = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            openSession(session)
        }
    }

    private func openTrainingPlanSession(_ session: WorkoutSession) {
        recentlyOpenedSession = session
        showingTrainingPlans = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            openSession(session)
        }
    }

    private func closeSessionNavigation() {
        activeSessionId = nil
        recentlyOpenedSession = nil
    }

    private func completeWorkoutFromSnapshot(_ snapshot: WorkoutFinishSnapshot) {
        let completedSession = sessionForNavigation(id: snapshot.sessionId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if snapshot.hasRecordedSets {
                WorkoutService.finish(sessionId: snapshot.sessionId, endedAt: snapshot.endedAt, in: modelContext)
                recapSession = completedSession
            } else {
                WorkoutService.discard(sessionId: snapshot.sessionId, in: modelContext)
            }
        }
    }

    private func sessionForNavigation(id sessionId: UUID) -> WorkoutSession? {
        sessions.first(where: { $0.id == sessionId })
            ?? (recentlyOpenedSession?.id == sessionId ? recentlyOpenedSession : nil)
    }

    private var homeMenu: some View {
        Menu {
            Button {
                HapticsService.openPanel()
                showingTrainingPlans = true
            } label: {
                Label("训练计划", systemImage: "calendar.badge.clock")
            }

            Button {
                HapticsService.openPanel()
                showingTemplates = true
            } label: {
                Label("训练模板", systemImage: "square.grid.2x2")
            }

            Button {
                HapticsService.openPanel()
                showingPR = true
            } label: {
                Label("个人 PR", systemImage: "trophy")
            }

            Button {
                HapticsService.openPanel()
                showingHistory = true
            } label: {
                Label("历史记录", systemImage: "clock.arrow.circlepath")
            }


            Button {
                HapticsService.openPanel()
                showingThemePicker = true
            } label: {
                Label("主题外观", systemImage: "paintpalette.fill")
            }

            Divider()

            Button {
                HapticsService.openPanel()
                showingAboutPrivacy = true
            } label: {
                Label("关于与隐私", systemImage: "hand.raised.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.10), in: Circle())
        }
        .accessibilityLabel("更多")
    }
}

// Tutorial scenes have a separate in-memory database and no input access.
private struct QuickStartGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 0
    @State private var phase = 0
    @State private var cycle = 0
    @State private var showingHelp = false
    @State private var fixture: TutorialFixture?
    @State private var failed = false
    private let titles: [LocalizedStringKey] = ["选择一个动作", "完成后，记录这一组", "保存后，自动开始休息"]
    private let details: [LocalizedStringKey] = ["点添加动作，选择今天要练的动作。", "先开始这一组，练完点「做完了」，填写次数后确认。", "倒计时结束后继续下一组，也可以提前结束休息。"]
    var body: some View {
        NavigationStack {
            ZStack {
                TrainingGlassBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Capsule().fill(index == page ? theme.primary : .white.opacity(0.14)).frame(height: 4)
                            }
                        }.accessibilityLabel(Text("第 \(page + 1) 步，共 3 步"))
                        Text(titles[page]).font(.title.bold())
                        Text(details[page]).font(.subheadline).foregroundStyle(.secondary)
                        if let fixture {
                            TutorialMotionScene(fixture: fixture, page: page, phase: phase, cycle: cycle)
                                .frame(height: 430)
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.12)))
                                .accessibilityLabel(Text(details[page]))
                        } else if failed {
                            Text("演示暂时无法加载，请关闭后重试。")
                        } else { ProgressView().frame(maxWidth: .infinity, minHeight: 300) }
                        HStack {
                            if page > 0 {
                                Button("上一步") { page -= 1; phase = 0 }
                            }
                            Spacer()
                            Button(page == 2 ? "知道了" : "下一步") {
                                if page == 2 { dismiss() } else { page += 1; phase = 0 }
                            }.trainingButtonStyle(prominent: true, tint: theme.primary)
                        }
                        Button { showingHelp = true } label: {
                            Label("按功能查看帮助", systemImage: "questionmark.circle")
                        }.font(.subheadline)
                    }.padding(20)
                }
            }
            .navigationTitle("新手教程").navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("跳过") { dismiss() } } }
            .sheet(isPresented: $showingHelp) { QuickStartHelpView() }
            .task {
                if fixture == nil { do { fixture = try TutorialFixture() } catch { failed = true } }
            }
            .task(id: "\(page)-\(reduceMotion)-\(scenePhase == .active)") {
                guard !reduceMotion, scenePhase == .active else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(page == 2 ? 1 : 2.5)) } catch { return }
                    withAnimation(.easeInOut(duration: 0.3)) { phase = (phase + 1) % (page == 2 ? 8 : 3) }
                    if phase == 0 { cycle += 1 }
                }
            }
        }
    }
}

@MainActor
private final class TutorialFixture {
    let container: ModelContainer
    let session = WorkoutSession()
    let exercise = Exercise(name: "卧推")
    init() throws {
        container = try ModelContainer(for: Exercise.self, WorkoutSession.self, SetLog.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(session)
        container.mainContext.insert(exercise)
        for name in ["深蹲", "杠铃划船", "引体向上", "哑铃肩推"] { container.mainContext.insert(Exercise(name: name)) }
        session.exerciseIds = [exercise.id]
        session.targetSetCounts = [exercise.id: 3]
        session.targetRepCounts = [exercise.id: 8]
        try container.mainContext.save()
    }
}

private struct TutorialMotionScene: View {
    let fixture: TutorialFixture
    let page: Int
    let phase: Int
    let cycle: Int
    @Environment(\.trainingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 390, proxy.size.height / 720)
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if page == 0 && phase < 2 {
                        ExercisePickerView(session: fixture.session, tutorialOnly: true) { _ in }
                    } else if page == 2 {
                        RestTimerView(completedExerciseName: fixture.exercise.displayName, tutorialRemainingSeconds: 90 - phase, completedSetNumber: 1,
                                      completedSetDetail: "20 kg · 8", targetSetCount: 3)
                            .id(cycle)
                    } else {
                        ExerciseSetView(session: fixture.session, exercise: fixture.exercise, tutorialPhase: page == 0 ? 0 : phase)
                    }
                }
                .modelContainer(fixture.container)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                if page < 2 && phase == 1 {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 36)).foregroundStyle(theme.primary)
                        .padding(.trailing, page == 0 ? 110 : 36)
                        .padding(.bottom, page == 0 ? 485 : 35)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .frame(width: 390, height: 720)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 390 * scale, height: 720 * scale, alignment: .topLeading)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipped()
        }
    }
}

struct FirstUseHint: View {
    @AppStorage private var dismissed: Bool
    let message: LocalizedStringKey
    init(_ key: String, message: LocalizedStringKey) {
        self._dismissed = AppStorage(wrappedValue: false, "onboarding.hint." + key)
        self.message = message
    }
    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb")
                Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { dismissed = true } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.accessibilityLabel("关闭提示")
            }.padding(14).liquidGlassCard(cornerRadius: 18)
        }
    }
}

private struct QuickStartHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("记录训练") {
                    Text("选择训练计划，或开始自由训练并添加动作。练完点完成，再填写实际次数。")
                }
                Section("休息与结束") {
                    Text("保存一组后自动休息。计划训练最后一个动作完成后自动保存；自由训练从更多菜单结束。")
                }
                Section("计划与提醒") {
                    Text("在训练计划页选择官方计划或创建自己的计划，右上角可以设置训练提醒。")
                }
                Section("历史与个人 PR") {
                    Text("首页更多菜单可查看历史和个人 PR，也可以分享训练成绩。")
                }
                Section {
                    Text("随时点首页问号，重新体验教程。")
                }
            }
            .navigationTitle("功能帮助")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .preferredColorScheme(.dark)
        }
    }
}
