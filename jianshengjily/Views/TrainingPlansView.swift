import SwiftData
import SwiftUI

struct TrainingPlansView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TrainingPlan.createdAt) private var plans: [TrainingPlan]
    @Query(sort: \TrainingPlanDay.sortIndex) private var planDays: [TrainingPlanDay]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    var onStart: (WorkoutSession) -> Void

    @State private var searchText = ""
    @State private var selectedFilter = TrainingPlanListFilter.all
    @State private var showingPlanBuilder = false
    @State private var editingPlan: TrainingPlan?
    @State private var showingPlanDeleteConfirmation = false
    @State private var pendingPlanDeletion: TrainingPlan?
    @State private var showingTrainingReminder = false

    private var exerciseById: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    private var pinnedActivePlan: (plan: TrainingPlan, nextDay: TrainingPlanDay)? {
        guard selectedFilter == .all,
              searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let plan = WorkoutService.activeTrainingPlan(from: plans),
              let nextDay = WorkoutService.nextTrainingPlanDay(for: plan, from: planDays) else {
            return nil
        }

        return (plan, nextDay)
    }

    private var visibleOfficialPlans: [TrainingPlan] {
        visibleSectionPlans(plans.filter(\.isOfficial))
    }

    private var visibleUserPlans: [TrainingPlan] {
        visibleSectionPlans(plans.filter { !$0.isOfficial })
    }

    private var hasVisiblePlans: Bool {
        pinnedActivePlan != nil || !visibleOfficialPlans.isEmpty || !visibleUserPlans.isEmpty
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FirstUseHint("plans", message: "不确定怎么安排？先选一个官方计划，查看动作后再开始。右上角铃铛可设置提醒。")
                    TrainingSearchField(text: $searchText, prompt: "搜索计划、训练日或动作")
                    planFilterBar

                    if plans.isEmpty {
                        emptyState
                    } else if !hasVisiblePlans {
                        emptyFilteredState
                    } else {
                        if let pinnedActivePlan {
                            nextWorkoutCard(plan: pinnedActivePlan.plan, nextDay: pinnedActivePlan.nextDay)
                        }

                        if !visibleOfficialPlans.isEmpty {
                            planSection(title: "官方分化", plans: visibleOfficialPlans)
                        }

                        if !visibleUserPlans.isEmpty {
                            planSection(title: "我的 DIY", plans: visibleUserPlans)
                        } else if (selectedFilter == .all || selectedFilter == .mine),
                                  !plans.contains(where: { !$0.isOfficial }) {
                            diyHint
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("训练计划")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingTrainingReminder = true
                    HapticsService.openPanel()
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.headline.weight(.bold))
                }
                .accessibilityLabel("设置训练提醒")

                Button {
                    beginCreatingPlan()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                }
                .accessibilityLabel("新建 DIY 计划")
            }
        }
        .sheet(isPresented: $showingPlanBuilder, onDismiss: {
            editingPlan = nil
        }) {
            NavigationStack {
                TrainingPlanBuilderView(
                    exercises: exercises,
                    existingPlanNames: existingPlanNamesForBuilder,
                    existingPlan: editingPlan,
                    existingDays: editingPlan.map { WorkoutService.trainingPlanDays(for: $0, from: planDays) } ?? []
                ) { name, dayDrafts in
                    savePlan(name: name, dayDrafts: dayDrafts)
                }
            }
        }
        .sheet(isPresented: $showingTrainingReminder) {
            NavigationStack {
                TrainingReminderSettingsView()
            }
        }
        .confirmationDialog(
            "删除这个训练计划？",
            isPresented: $showingPlanDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除计划", role: .destructive) {
                deletePendingPlan()
            }
            Button("取消", role: .cancel) {
                pendingPlanDeletion = nil
            }
        } message: {
            Text("计划和其中的训练日会被删除，已经完成的历史训练不会受到影响。")
        }
        .task {
            WorkoutService.seedDefaultExercisesIfNeeded(in: modelContext)
            WorkoutService.seedDefaultTrainingPlansIfNeeded(in: modelContext)
        }
    }

    private var existingPlanNamesForBuilder: Set<String> {
        Set(plans.filter { plan in
            guard let editingPlan else {
                return true
            }
            return plan.id != editingPlan.id
        }.map(\.name))
    }

    private func beginCreatingPlan() {
        editingPlan = nil
        showingPlanBuilder = true
        HapticsService.openPanel()
    }

    private var planFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrainingPlanListFilter.allCases) { filter in
                    planFilterButton(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func planFilterButton(_ filter: TrainingPlanListFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            selectedFilter = filter
            HapticsService.switchExercise()
        } label: {
            Text(filter.title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isSelected ? .black : .white)
                .lineLimit(1)
                .frame(minWidth: 46)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? theme.primary : Color.white.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(isSelected ? 0 : 0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func nextWorkoutCard(plan: TrainingPlan, nextDay: TrainingPlanDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingStageLabel(text: "下一次训练")

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.displayName)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    L10n.format(
                        "plan.next_workout_summary",
                        DefaultContentLocalization.trainingPlanDayName(nextDay, plan: plan),
                        L10n.count("count.exercises", nextDay.exerciseIds.count)
                    )
                )
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(exerciseNames(for: nextDay).joined(separator: " / "))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button {
                start(plan: plan, day: nextDay)
            } label: {
                Label("开始下一练", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .trainingButtonStyle(prominent: true, tint: theme.primary)
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func planSection(title: String, plans: [TrainingPlan]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(title))
                .font(.headline.weight(.heavy))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(plans) { plan in
                    let days = WorkoutService.trainingPlanDays(for: plan, from: planDays)
                    let nextDay = WorkoutService.nextTrainingPlanDay(for: plan, from: planDays)

                    TrainingPlanRow(
                        plan: plan,
                        days: days,
                        nextDay: nextDay,
                        exerciseNames: exerciseNames,
                        onStartNext: {
                            guard let nextDay else {
                                HapticsService.actionFailed()
                                return
                            }
                            start(plan: plan, day: nextDay)
                        },
                        onSetActive: {
                            WorkoutService.setActiveTrainingPlan(plan, in: modelContext)
                            HapticsService.saveSucceeded()
                        },
                        onEdit: plan.isOfficial ? nil : {
                            editingPlan = plan
                            showingPlanBuilder = true
                            HapticsService.openPanel()
                        },
                        onDelete: plan.isOfficial ? nil : {
                            pendingPlanDeletion = plan
                            showingPlanDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }

    private var diyHint: some View {
        Text("点右上角 + 可以创建自己的三分化、四分化或任意循环计划。每个训练日选好动作后，首页会直接给你下一练。")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.secondary)

            Text("还没有训练计划")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("官方三分化和四分化会自动补齐，也可以右上角新建 DIY 计划。")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .liquidGlassCard(cornerRadius: 26)
    }

    private var emptyFilteredState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.secondary)

            Text("没有匹配计划")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func filteredPlans(_ rawPlans: [TrainingPlan]) -> [TrainingPlan] {
        rawPlans
            .filter { selectedFilter.includes(plan: $0, days: WorkoutService.trainingPlanDays(for: $0, from: planDays)) }
            .filter(matchesSearch)
            .sorted(by: comparePlans)
    }

    private func visibleSectionPlans(_ rawPlans: [TrainingPlan]) -> [TrainingPlan] {
        let filtered = filteredPlans(rawPlans)
        guard let pinnedPlanId = pinnedActivePlan?.plan.id else {
            return filtered
        }

        return filtered.filter { $0.id != pinnedPlanId }
    }

    private func matchesSearch(_ plan: TrainingPlan) -> Bool {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return true
        }

        let days = WorkoutService.trainingPlanDays(for: plan, from: planDays)
        return DefaultContentLocalization.matchesSearch(
            source: plan.name,
            localized: plan.displayName,
            keyword: keyword
        )
            || days.contains { day in
                DefaultContentLocalization.matchesSearch(
                    source: day.name,
                    localized: DefaultContentLocalization.trainingPlanDayName(day, plan: plan),
                    keyword: keyword
                ) || day.exerciseIds.compactMap { exerciseById[$0] }.contains { exercise in
                    DefaultContentLocalization.matchesSearch(
                        source: exercise.name,
                        localized: exercise.displayName,
                        keyword: keyword
                    )
                }
            }
    }

    private func exerciseNames(for day: TrainingPlanDay) -> [String] {
        day.exerciseIds.compactMap { exerciseId in
            guard let exercise = exerciseById[exerciseId] else {
                return nil
            }
            return plannedDayExerciseSummary(
                exercise: exercise,
                targetSets: day.targetSetCount(for: exerciseId),
                targetReps: day.targetRepCount(for: exerciseId)
            )
        }
    }

    private func start(plan: TrainingPlan, day: TrainingPlanDay) {
        let session = WorkoutService.createWorkout(from: day, plan: plan, in: modelContext)
        HapticsService.startWorkout()
        onStart(session)
    }

    private func savePlan(name: String, dayDrafts: [TrainingPlanDayDraft]) {
        if let editingPlan {
            guard WorkoutService.updateUserTrainingPlan(
                editingPlan,
                name: name,
                dayDrafts: dayDrafts,
                existingDays: planDays,
                in: modelContext
            ) else {
                HapticsService.actionFailed()
                return
            }
        } else {
            guard WorkoutService.createUserTrainingPlan(named: name, dayDrafts: dayDrafts, in: modelContext) != nil else {
                HapticsService.actionFailed()
                return
            }
        }

        HapticsService.saveSucceeded()
    }

    private func deletePendingPlan() {
        guard let pendingPlanDeletion else {
            return
        }

        WorkoutService.deleteTrainingPlan(pendingPlanDeletion, days: planDays, in: modelContext)
        HapticsService.destructiveAction()
        self.pendingPlanDeletion = nil
    }

    private func comparePlans(_ lhs: TrainingPlan, _ rhs: TrainingPlan) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }

        if lhs.isOfficial != rhs.isOfficial {
            return lhs.isOfficial && !rhs.isOfficial
        }

        if lhs.sortIndex == rhs.sortIndex {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.sortIndex < rhs.sortIndex
    }
}

private enum TrainingPlanListFilter: String, CaseIterable, Identifiable {
    case all
    case mine
    case official
    case threeDay
    case fourDay
    case ppl
    case upperLower
    case fullBody

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return L10n.string("全部")
        case .mine:
            return L10n.string("我的")
        case .official:
            return L10n.string("官方")
        case .threeDay:
            return L10n.string("三分化")
        case .fourDay:
            return L10n.string("四分化")
        case .ppl:
            return "PPL"
        case .upperLower:
            return L10n.string("上下肢")
        case .fullBody:
            return L10n.string("全身")
        }
    }

    func includes(plan: TrainingPlan, days: [TrainingPlanDay]) -> Bool {
        switch self {
        case .all:
            return true
        case .mine:
            return !plan.isOfficial
        case .official:
            return plan.isOfficial
        case .threeDay:
            return plan.name.localizedCaseInsensitiveContains("三分化")
        case .fourDay:
            return plan.name.localizedCaseInsensitiveContains("四分化")
        case .ppl:
            return plan.name.localizedCaseInsensitiveContains("PPL")
        case .upperLower:
            return plan.name.localizedCaseInsensitiveContains("上下肢")
        case .fullBody:
            return plan.name.localizedCaseInsensitiveContains("全身") || days.contains { $0.name.localizedCaseInsensitiveContains("全身") }
        }
    }
}

private enum TrainingPlanExerciseFilter: String, CaseIterable, Identifiable {
    case all
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case conditioning

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return L10n.string("全部")
        case .chest:
            return L10n.string("胸")
        case .back:
            return L10n.string("背")
        case .legs:
            return L10n.string("腿臀")
        case .shoulders:
            return L10n.string("肩")
        case .arms:
            return L10n.string("手臂")
        case .core:
            return L10n.string("核心")
        case .conditioning:
            return L10n.string("体能")
        }
    }

    func includes(_ rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch self {
        case .all:
            return true
        case .chest:
            return containsAny(name, ["卧推", "推胸", "俯卧撑", "双杠臂屈伸", "飞鸟", "夹胸"])
        case .back:
            return containsAny(name, ["引体", "下拉", "划船", "上拉", "面拉"])
        case .legs:
            return containsAny(name, ["深蹲", "弓步", "分腿蹲", "箭步", "上步", "硬拉", "臀", "髋", "腿", "小腿", "提踵", "挺身"])
        case .shoulders:
            return containsAny(name, ["肩", "推举", "侧平举", "前平举", "俯身飞鸟", "反向蝴蝶", "耸肩"])
        case .arms:
            return containsAny(name, ["二头", "三头", "弯举", "下压", "臂屈伸"])
        case .core:
            return containsAny(name, ["平板", "卷腹", "悬垂", "俄罗斯", "死虫", "鸟狗", "侧桥", "Pallof", "抗旋"])
        case .conditioning:
            return containsAny(name, ["壶铃", "农夫", "药球", "雪橇", "战绳"])
        }
    }

    private func containsAny(_ name: String, _ keywords: [String]) -> Bool {
        keywords.contains { name.localizedCaseInsensitiveContains($0) }
    }
}

private struct TrainingPlanRow: View {
    @Environment(\.trainingTheme) private var theme

    let plan: TrainingPlan
    let days: [TrainingPlanDay]
    let nextDay: TrainingPlanDay?
    let exerciseNames: (TrainingPlanDay) -> [String]
    let onStartNext: () -> Void
    let onSetActive: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(plan.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        if plan.isActive {
                            Text("使用中")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(theme.primary, in: Capsule())
                        }
                    }

                    Text(L10n.count("count.training_days", days.count))
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.primary)
                }

                Spacer()

                Menu {
                    if !plan.isActive {
                        Button(action: onSetActive) {
                            Label("设为当前计划", systemImage: "checkmark.circle")
                        }
                    }

                    if let onEdit {
                        Button(action: onEdit) {
                            Label("编辑 DIY", systemImage: "pencil")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("删除计划", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            if let nextDay {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        L10n.format(
                            "plan.next_workout",
                            DefaultContentLocalization.trainingPlanDayName(nextDay, plan: plan)
                        )
                    )
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(exerciseNames(nextDay).joined(separator: " / "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            dayStrip

            Button(action: onStartNext) {
                Label(
                    plan.isActive
                        ? L10n.string("开始下一练")
                        : L10n.string("使用这个计划开始"),
                    systemImage: "play.fill"
                )
                    .frame(maxWidth: .infinity)
            }
            .trainingButtonStyle(prominent: true, tint: theme.primary)
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22, interactive: true)
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DefaultContentLocalization.trainingPlanDayName(day, plan: plan))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(L10n.count("count.exercises", day.exerciseIds.count))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Text(L10n.count("count.sets", day.exerciseIds.reduce(0) { $0 + day.targetSetCount(for: $1) }))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(day.id == nextDay?.id ? 0.14 : 0.07), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(day.id == nextDay?.id ? theme.primary.opacity(0.75) : .white.opacity(0.08), lineWidth: 1)
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }
}

private struct TrainingPlanBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingTheme) private var theme

    let exercises: [Exercise]
    let existingPlanNames: Set<String>
    let existingPlan: TrainingPlan?
    let onSave: (_ name: String, _ dayDrafts: [TrainingPlanDayDraft]) -> Void

    @State private var planName: String
    @State private var dayDrafts: [TrainingPlanDayDraft]
    @State private var selectedDayId: UUID?
    @State private var validationMessage: String?
    @State private var exerciseSearchText = ""
    @State private var selectedExerciseFilter = TrainingPlanExerciseFilter.all

    init(
        exercises: [Exercise],
        existingPlanNames: Set<String>,
        existingPlan: TrainingPlan?,
        existingDays: [TrainingPlanDay],
        onSave: @escaping (_ name: String, _ dayDrafts: [TrainingPlanDayDraft]) -> Void
    ) {
        let repBasedExerciseIds = Set(
            exercises
                .filter { $0.measurementMode.recordsReps }
                .map(\.id)
        )
        let drafts = existingDays.map { day in
            let targetRepCounts = Dictionary(
                uniqueKeysWithValues: day.exerciseIds.compactMap { exerciseId -> (UUID, Int)? in
                    if let count = day.targetRepCount(for: exerciseId) {
                        return (exerciseId, WorkoutTargetReps.normalizedCount(count))
                    }
                    guard repBasedExerciseIds.contains(exerciseId) else {
                        return nil
                    }
                    return (exerciseId, WorkoutTargetReps.defaultCount)
                }
            )
            return TrainingPlanDayDraft(
                id: day.id,
                name: day.name,
                exerciseIds: day.exerciseIds,
                targetSetCounts: WorkoutTargetSets.normalized(
                    day.targetSetCounts,
                    for: day.exerciseIds,
                    fallbackCount: WorkoutTargetSets.defaultCount
                ),
                targetRepCounts: targetRepCounts
            )
        }
        let initialDrafts = drafts.isEmpty
            ? [TrainingPlanDayDraft(name: L10n.format("plan.default_day_name", 1))]
            : drafts

        self.exercises = exercises
        self.existingPlanNames = existingPlanNames
        self.existingPlan = existingPlan
        self.onSave = onSave
        _planName = State(initialValue: existingPlan?.name ?? "")
        _dayDrafts = State(initialValue: initialDrafts)
        _selectedDayId = State(initialValue: initialDrafts.first?.id)
    }

    private var title: String {
        existingPlan == nil
            ? L10n.string("新建 DIY 计划")
            : L10n.string("编辑 DIY 计划")
    }

    private var trimmedPlanName: String {
        planName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        existingPlanNames.contains(trimmedPlanName)
    }

    private var selectedDayIndex: Int? {
        guard let selectedDayId else {
            return nil
        }
        return dayDrafts.firstIndex { $0.id == selectedDayId }
    }

    private var selectedDay: TrainingPlanDayDraft? {
        guard let selectedDayIndex else {
            return nil
        }
        return dayDrafts[selectedDayIndex]
    }

    private var canSave: Bool {
        !trimmedPlanName.isEmpty
            && !isDuplicateName
            && !dayDrafts.isEmpty
            && dayDrafts.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.exerciseIds.isEmpty }
    }

    private var filteredExercises: [Exercise] {
        let keyword = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
            selectedExerciseFilter.includes(exercise.name)
                && (
                    keyword.isEmpty
                        || DefaultContentLocalization.matchesSearch(
                            source: exercise.name,
                            localized: exercise.displayName,
                            keyword: keyword
                        )
                )
        }
    }

    private var exerciseById: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("安排多个训练日，并为次数型动作设置目标组数和每组次数。")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    nameField
                    validationText
                    dayEditor
                    exercisePicker
                }
                .padding(20)
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("我的计划")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    HapticsService.closePanel()
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: planName) { _, _ in
            validationMessage = nil
        }
        .onChange(of: dayDrafts) { _, _ in
            validationMessage = nil
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("计划名称")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.secondary)

            TextField("例如：我的四分化", text: $planName)
                .textInputAutocapitalization(.never)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .padding(16)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var validationText: some View {
        if let validationMessage {
            Text(validationMessage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red.opacity(0.9))
        } else if !trimmedPlanName.isEmpty, isDuplicateName {
            Text("这个计划名已经存在，换一个名称。")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red.opacity(0.9))
        }
    }

    private var dayEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练日")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    addDay()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(theme.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加训练日")
            }

            dayTabs

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("当前训练日")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if dayDrafts.count > 1 {
                        Button {
                            removeSelectedDay()
                        } label: {
                            Image(systemName: "trash")
                                .font(.headline)
                                .foregroundStyle(.red)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除当前训练日")
                    }
                }

                TextField("例如：推日、胸三头、腿臀", text: selectedDayNameBinding)
                    .textInputAutocapitalization(.never)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                selectedExerciseSummary
            }
            .padding(14)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dayDrafts) { day in
                    let isSelected = day.id == selectedDayId
                    Button {
                        selectedDayId = day.id
                        HapticsService.switchExercise()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                day.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? L10n.string("未命名")
                                    : day.name
                            )
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(isSelected ? .black : .white)
                                .lineLimit(1)

                            Text(L10n.count("count.exercises", day.exerciseIds.count))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isSelected ? .black.opacity(0.65) : .secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(isSelected ? theme.primary : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }

    private var selectedDayNameBinding: Binding<String> {
        Binding {
            selectedDay?.name ?? ""
        } set: { newValue in
            guard let selectedDayIndex else {
                return
            }
            dayDrafts[selectedDayIndex].name = newValue
        }
    }

    @ViewBuilder
    private var selectedExerciseSummary: some View {
        if let selectedDay, !selectedDay.exerciseIds.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedDay.exerciseIds.enumerated()), id: \.element) { index, exerciseId in
                        if let exercise = exerciseById[exerciseId] {
                            Text(
                                "\(index + 1). \(plannedDayExerciseSummary(exercise: exercise, targetSets: selectedDay.targetSetCount(for: exerciseId), targetReps: selectedDay.targetRepCount(for: exerciseId)))"
                            )
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.white.opacity(0.10), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
        } else {
            Text("给这个训练日选择动作。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("选择动作")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(L10n.format("selection.selected_count", selectedDay?.exerciseIds.count ?? 0))
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
            }

            TrainingSearchField(text: $exerciseSearchText, prompt: "搜索动作")
            exerciseFilterBar

            if filteredExercises.isEmpty {
                Text("没有匹配动作")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredExercises) { exercise in
                        exerciseSelectionRow(exercise)
                    }
                }
            }
        }
    }

    private var exerciseFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrainingPlanExerciseFilter.allCases) { filter in
                    exerciseFilterButton(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func exerciseFilterButton(_ filter: TrainingPlanExerciseFilter) -> some View {
        let isSelected = selectedExerciseFilter == filter

        return Button {
            selectedExerciseFilter = filter
            HapticsService.switchExercise()
        } label: {
            Text(filter.title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(isSelected ? .black : .white)
                .lineLimit(1)
                .frame(minWidth: 40)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? theme.primary : Color.white.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(isSelected ? 0 : 0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func exerciseSelectionRow(_ exercise: Exercise) -> some View {
        let selectedIndex = selectedDay?.exerciseIds.firstIndex(of: exercise.id)

        return HStack(spacing: 10) {
            Button {
                toggleExercise(exercise)
            } label: {
                HStack(spacing: 12) {
                if let selectedIndex {
                    Text("\(selectedIndex + 1)")
                        .font(.headline.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(theme.primary, in: Circle())
                } else {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 2)
                        .frame(width: 34, height: 34)
                }

                Text(exercise.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if selectedIndex != nil {
                targetControls(for: exercise)
            }
        }
        .padding(12)
        .background(.white.opacity(selectedIndex == nil ? 0.07 : 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func targetControls(for exercise: Exercise) -> some View {
        VStack(spacing: 6) {
            targetSetControl(for: exercise.id)
            if exercise.measurementMode.recordsReps {
                targetRepControl(for: exercise.id)
            }
        }
    }

    private func targetSetControl(for exerciseId: UUID) -> some View {
        let count = selectedDay?.targetSetCount(for: exerciseId) ?? WorkoutTargetSets.defaultCount

        return HStack(spacing: 6) {
            Button {
                setTargetSetCount(count - 1, for: exerciseId)
                HapticsService.switchExercise()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 30, height: 30)
            }
            .disabled(count == WorkoutTargetSets.allowedRange.lowerBound)

            Text(L10n.count("count.sets", count))
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(theme.primary)
                .frame(minWidth: 38)

            Button {
                setTargetSetCount(count + 1, for: exerciseId)
                HapticsService.switchExercise()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
            .disabled(count == WorkoutTargetSets.allowedRange.upperBound)
        }
        .font(.caption.weight(.black))
        .foregroundStyle(.white)
        .background(.white.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("目标组数"))
        .accessibilityValue(L10n.count("count.sets", count))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setTargetSetCount(count + 1, for: exerciseId)
            case .decrement:
                setTargetSetCount(count - 1, for: exerciseId)
            @unknown default:
                break
            }
        }
    }

    private func targetRepControl(for exerciseId: UUID) -> some View {
        let count = selectedDay?.targetRepCount(for: exerciseId) ?? WorkoutTargetReps.defaultCount

        return HStack(spacing: 6) {
            Button {
                setTargetRepCount(count - 1, for: exerciseId)
                HapticsService.switchExercise()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 30, height: 30)
            }
            .disabled(count == WorkoutTargetReps.allowedRange.lowerBound)

            Text(L10n.count("count.reps", count))
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(theme.primary)
                .frame(minWidth: 38)

            Button {
                setTargetRepCount(count + 1, for: exerciseId)
                HapticsService.switchExercise()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
            .disabled(count == WorkoutTargetReps.allowedRange.upperBound)
        }
        .font(.caption.weight(.black))
        .foregroundStyle(.white)
        .background(.white.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("每组目标次数"))
        .accessibilityValue(L10n.count("count.reps", count))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setTargetRepCount(count + 1, for: exerciseId)
            case .decrement:
                setTargetRepCount(count - 1, for: exerciseId)
            @unknown default:
                break
            }
        }
    }

    private func setTargetSetCount(_ count: Int, for exerciseId: UUID) {
        guard let selectedDayIndex else {
            return
        }
        dayDrafts[selectedDayIndex].targetSetCounts[exerciseId] = WorkoutTargetSets.normalizedCount(count)
    }

    private func setTargetRepCount(_ count: Int, for exerciseId: UUID) {
        guard let selectedDayIndex else {
            return
        }
        dayDrafts[selectedDayIndex].targetRepCounts[exerciseId] = WorkoutTargetReps.normalizedCount(count)
    }

    private func addDay() {
        let nextIndex = dayDrafts.count + 1
        let day = TrainingPlanDayDraft(name: L10n.format("plan.default_day_name", nextIndex))
        dayDrafts.append(day)
        selectedDayId = day.id
        validationMessage = nil
        HapticsService.openPanel()
    }

    private func removeSelectedDay() {
        guard dayDrafts.count > 1, let selectedDayIndex else {
            return
        }

        dayDrafts.remove(at: selectedDayIndex)
        selectedDayId = dayDrafts[min(selectedDayIndex, dayDrafts.count - 1)].id
        validationMessage = nil
        HapticsService.destructiveAction()
    }

    private func toggleExercise(_ exercise: Exercise) {
        guard let selectedDayIndex else {
            return
        }

        if let index = dayDrafts[selectedDayIndex].exerciseIds.firstIndex(of: exercise.id) {
            dayDrafts[selectedDayIndex].exerciseIds.remove(at: index)
            dayDrafts[selectedDayIndex].targetSetCounts.removeValue(forKey: exercise.id)
            dayDrafts[selectedDayIndex].targetRepCounts.removeValue(forKey: exercise.id)
            HapticsService.closePanel()
        } else {
            dayDrafts[selectedDayIndex].exerciseIds.append(exercise.id)
            dayDrafts[selectedDayIndex].targetSetCounts[exercise.id] = WorkoutTargetSets.defaultCount
            if exercise.measurementMode.recordsReps {
                dayDrafts[selectedDayIndex].targetRepCounts[exercise.id] = WorkoutTargetReps.defaultCount
            }
            HapticsService.switchExercise()
        }
    }

    private func save() {
        guard !trimmedPlanName.isEmpty else {
            validationMessage = L10n.string("先输入计划名称。")
            HapticsService.actionFailed()
            return
        }

        guard !isDuplicateName else {
            validationMessage = L10n.string("这个计划名已经存在，换一个名称。")
            HapticsService.actionFailed()
            return
        }

        guard !dayDrafts.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            validationMessage = L10n.string("每个训练日都要有名称。")
            HapticsService.actionFailed()
            return
        }

        guard !dayDrafts.contains(where: { $0.exerciseIds.isEmpty }) else {
            validationMessage = L10n.string("每个训练日至少选择一个动作。")
            HapticsService.actionFailed()
            return
        }

        onSave(trimmedPlanName, dayDrafts)
        dismiss()
    }
}

private func plannedDayExerciseSummary(
    exercise: Exercise,
    targetSets: Int,
    targetReps: Int?
) -> String {
    if exercise.measurementMode.recordsReps, let targetReps {
        return "\(exercise.displayName) · \(L10n.count("count.sets", targetSets)) × \(L10n.count("count.reps", targetReps))"
    }
    return "\(exercise.displayName) · \(L10n.count("count.sets", targetSets))"
}
