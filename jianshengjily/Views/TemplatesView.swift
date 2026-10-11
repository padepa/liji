import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    var onStart: (WorkoutSession) -> Void

    @State private var showingTemplateBuilder = false
    @State private var showingTemplateDeleteConfirmation = false
    @State private var pendingTemplateDeletion: WorkoutTemplate?
    @State private var templateSearchText = ""
    @State private var selectedTemplateFilter = TemplateListFilter.all

    private var exerciseById: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    private var officialTemplates: [WorkoutTemplate] {
        let defaultOrder = Dictionary(
            uniqueKeysWithValues: WorkoutService.defaultTemplateDefinitions.enumerated().map { ($0.element.name, $0.offset) }
        )

        return templates
            .filter { WorkoutService.defaultTemplateNames.contains($0.name) }
            .sorted { lhs, rhs in
                (defaultOrder[lhs.name] ?? Int.max) < (defaultOrder[rhs.name] ?? Int.max)
            }
    }

    private var userTemplates: [WorkoutTemplate] {
        templates.filter { !WorkoutService.defaultTemplateNames.contains($0.name) }
    }

    private var visibleOfficialTemplates: [WorkoutTemplate] {
        officialTemplates.filter { template in
            selectedTemplateFilter.includes(templateName: template.name, isOfficial: true)
                && matchesTemplateSearch(template)
        }
    }

    private var visibleUserTemplates: [WorkoutTemplate] {
        userTemplates.filter { template in
            selectedTemplateFilter.includes(templateName: template.name, isOfficial: false)
                && matchesTemplateSearch(template)
        }
    }

    private var hasVisibleTemplates: Bool {
        !visibleOfficialTemplates.isEmpty || !visibleUserTemplates.isEmpty
    }

    private var shouldShowMyTemplateHint: Bool {
        let isBrowsingOwnTemplates = selectedTemplateFilter == .all || selectedTemplateFilter == .mine
        return userTemplates.isEmpty && templateSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isBrowsingOwnTemplates
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FirstUseHint("templates", message: "模板是一套可重复使用的动作。选一个模板，就不用每次重新添加动作。")
                    TrainingSearchField(text: $templateSearchText, prompt: "搜索模板或动作")
                    templateFilterBar

                    if templates.isEmpty {
                        emptyState
                    } else if !hasVisibleTemplates {
                        emptyFilteredState
                    } else {
                        if !visibleOfficialTemplates.isEmpty {
                            templateSection(title: "官方模板", templates: visibleOfficialTemplates, allowsDelete: false)
                        }

                        if !visibleUserTemplates.isEmpty {
                            templateSection(title: "我的模板", templates: visibleUserTemplates, allowsDelete: true)
                        } else if shouldShowMyTemplateHint {
                            myTemplateHint
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("训练模板")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    beginCreatingTemplate()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                }
                .accessibilityLabel("新建模板")
            }
        }
        .sheet(isPresented: $showingTemplateBuilder) {
            NavigationStack {
                TemplateBuilderView(
                    exercises: exercises,
                    existingTemplateNames: Set(templates.map(\.name))
                ) { name, exerciseIds, targetSetCounts, targetRepCounts in
                    createUserTemplate(
                        name: name,
                        exerciseIds: exerciseIds,
                        targetSetCounts: targetSetCounts,
                        targetRepCounts: targetRepCounts
                    )
                }
            }
        }
        .confirmationDialog(
            "删除这个模板？",
            isPresented: $showingTemplateDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除模板", role: .destructive) {
                deletePendingTemplate()
            }
            Button("取消", role: .cancel) {
                pendingTemplateDeletion = nil
            }
        } message: {
            Text("删除后无法恢复，已经保存的历史训练不会受到影响。")
        }
        .preferredColorScheme(.dark)
        .task {
            WorkoutService.seedDefaultTemplatesIfNeeded(in: modelContext)
        }
    }

    private var templateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TemplateListFilter.allCases) { filter in
                    templateFilterButton(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func beginCreatingTemplate() {
        HapticsService.openPanel()
        showingTemplateBuilder = true
    }

    private func templateFilterButton(_ filter: TemplateListFilter) -> some View {
        let isSelected = selectedTemplateFilter == filter

        return Button {
            selectedTemplateFilter = filter
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

    private var emptyFilteredState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.secondary)

            Text("没有匹配模板")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func matchesTemplateSearch(_ template: WorkoutTemplate) -> Bool {
        let keyword = templateSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return true
        }

        return DefaultContentLocalization.matchesSearch(
            source: template.name,
            localized: template.displayName,
            keyword: keyword
        ) || template.exerciseIds.compactMap { exerciseById[$0] }.contains { exercise in
            DefaultContentLocalization.matchesSearch(
                source: exercise.name,
                localized: exercise.displayName,
                keyword: keyword
            )
        }
    }

    private func exerciseSummaries(for template: WorkoutTemplate) -> [String] {
        template.exerciseIds.compactMap { exerciseId in
            guard let exercise = exerciseById[exerciseId] else {
                return nil
            }
            return plannedExerciseSummary(
                exercise: exercise,
                targetSets: template.targetSetCount(for: exerciseId),
                targetReps: template.targetRepCount(for: exerciseId)
            )
        }
    }

    private func templateSection(title: String, templates: [WorkoutTemplate], allowsDelete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(title))
                .font(.headline.weight(.heavy))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(templates) { template in
                    TemplateRow(
                        template: template,
                        exerciseSummaries: exerciseSummaries(for: template),
                        isOfficial: !allowsDelete,
                        onStart: {
                            let session = WorkoutService.createWorkout(from: template, in: modelContext)
                            HapticsService.startWorkout()
                            onStart(session)
                        },
                        onDelete: {
                            pendingTemplateDeletion = template
                            showingTemplateDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }

    private func createUserTemplate(
        name: String,
        exerciseIds: [UUID],
        targetSetCounts: [UUID: Int],
        targetRepCounts: [UUID: Int]
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !exerciseIds.isEmpty else {
            HapticsService.actionFailed()
            return
        }

        let existingNames = Set(templates.map(\.name))
        guard !existingNames.contains(trimmedName) else {
            HapticsService.actionFailed()
            return
        }

        modelContext.insert(
            WorkoutTemplate(
                name: trimmedName,
                exerciseIds: exerciseIds,
                targetSetCounts: WorkoutTargetSets.normalized(
                    targetSetCounts,
                    for: exerciseIds,
                    fallbackCount: WorkoutTargetSets.defaultCount
                ),
                targetRepCounts: WorkoutTargetReps.normalized(targetRepCounts, for: exerciseIds)
            )
        )
        try? modelContext.save()
        HapticsService.saveSucceeded()
    }

    private func deletePendingTemplate() {
        guard let pendingTemplateDeletion else {
            return
        }

        modelContext.delete(pendingTemplateDeletion)
        do {
            try modelContext.save()
            HapticsService.destructiveAction()
        } catch {
            HapticsService.actionFailed()
        }
        self.pendingTemplateDeletion = nil
    }

    private var myTemplateHint: some View {
        Text("点右上角 + 可以直接创建自己的模板；完成一套训练后也可以在当前训练页保存为模板。")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.secondary)

            Text("还没有模板")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("点右上角 + 可以直接创建；完成训练后也可以保存本次动作。")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .liquidGlassCard(cornerRadius: 26)
    }
}

private enum TemplateListFilter: String, CaseIterable, Identifiable {
    case all
    case mine
    case common
    case ppl
    case upperLower
    case fullBody
    case focus
    case strength

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return L10n.string("全部")
        case .mine:
            return L10n.string("我的")
        case .common:
            return L10n.string("常用")
        case .ppl:
            return "PPL"
        case .upperLower:
            return L10n.string("上下肢")
        case .fullBody:
            return L10n.string("全身")
        case .focus:
            return L10n.string("专项")
        case .strength:
            return L10n.string("力量")
        }
    }

    func includes(templateName: String, isOfficial: Bool) -> Bool {
        switch self {
        case .all:
            return true
        case .mine:
            return !isOfficial
        case .common:
            return isOfficial && [
                "全身入门",
                "全身 A",
                "PPL 推日",
                "PPL 拉日",
                "PPL 腿日",
                "上肢 A",
                "下肢 A",
                "经典 5x5"
            ].contains(templateName)
        case .ppl:
            return templateName.localizedCaseInsensitiveContains("PPL")
        case .upperLower:
            return containsAny(templateName, ["上肢", "下肢"])
        case .fullBody:
            return templateName.localizedCaseInsensitiveContains("全身")
        case .focus:
            return containsAny(templateName, ["胸", "背", "肩", "手臂", "臀腿", "核心", "体能"])
        case .strength:
            return containsAny(templateName, ["力量", "三大项", "5x5"])
        }
    }

    private func containsAny(_ name: String, _ keywords: [String]) -> Bool {
        keywords.contains { name.localizedCaseInsensitiveContains($0) }
    }
}

private enum TemplateExerciseFilter: String, CaseIterable, Identifiable {
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

private struct TemplateBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingTheme) private var theme

    let exercises: [Exercise]
    let existingTemplateNames: Set<String>
    let onSave: (
        _ name: String,
        _ exerciseIds: [UUID],
        _ targetSetCounts: [UUID: Int],
        _ targetRepCounts: [UUID: Int]
    ) -> Void

    @State private var templateName = ""
    @State private var selectedExerciseIds: [UUID] = []
    @State private var targetSetCounts: [UUID: Int] = [:]
    @State private var targetRepCounts: [UUID: Int] = [:]
    @State private var validationMessage: String?
    @State private var exerciseSearchText = ""
    @State private var selectedExerciseFilter = TemplateExerciseFilter.all

    private var trimmedName: String {
        templateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !selectedExerciseIds.isEmpty && !isDuplicateName
    }

    private var isDuplicateName: Bool {
        existingTemplateNames.contains(trimmedName)
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

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("新建模板")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("按点击顺序安排动作，并设置每个动作的目标组数和每组次数。")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("模板名称")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.secondary)

                        TextField("例如：胸肩三头", text: $templateName)
                            .textInputAutocapitalization(.never)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red.opacity(0.9))
                    } else if !trimmedName.isEmpty, isDuplicateName {
                        Text("这个模板名已经存在，换一个名称。")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("选择动作")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(L10n.format("selection.selected_count", selectedExerciseIds.count))
                                .font(.subheadline.weight(.heavy))
                                .monospacedDigit()
                                .foregroundStyle(theme.primary)
                        }

                        TrainingSearchField(text: $exerciseSearchText, prompt: "搜索动作")
                        exerciseFilterBar

                        if filteredExercises.isEmpty {
                            emptyExerciseState
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredExercises) { exercise in
                                    exerciseSelectionRow(exercise)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("我的模板")
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
        .onChange(of: templateName) { _, _ in
            validationMessage = nil
        }
        .onChange(of: selectedExerciseIds) { _, _ in
            validationMessage = nil
        }
    }

    private var exerciseFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TemplateExerciseFilter.allCases) { filter in
                    exerciseFilterButton(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func exerciseFilterButton(_ filter: TemplateExerciseFilter) -> some View {
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

    private var emptyExerciseState: some View {
        Text("没有匹配动作")
            .font(.headline.weight(.heavy))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func exerciseSelectionRow(_ exercise: Exercise) -> some View {
        let selectedIndex = selectedExerciseIds.firstIndex(of: exercise.id)

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
        let count = targetSetCounts[exerciseId] ?? WorkoutTargetSets.defaultCount

        return HStack(spacing: 6) {
            Button {
                targetSetCounts[exerciseId] = WorkoutTargetSets.normalizedCount(count - 1)
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
                targetSetCounts[exerciseId] = WorkoutTargetSets.normalizedCount(count + 1)
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
                targetSetCounts[exerciseId] = WorkoutTargetSets.normalizedCount(count + 1)
            case .decrement:
                targetSetCounts[exerciseId] = WorkoutTargetSets.normalizedCount(count - 1)
            @unknown default:
                break
            }
        }
    }

    private func targetRepControl(for exerciseId: UUID) -> some View {
        let count = targetRepCounts[exerciseId] ?? WorkoutTargetReps.defaultCount

        return HStack(spacing: 6) {
            Button {
                targetRepCounts[exerciseId] = WorkoutTargetReps.normalizedCount(count - 1)
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
                targetRepCounts[exerciseId] = WorkoutTargetReps.normalizedCount(count + 1)
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
                targetRepCounts[exerciseId] = WorkoutTargetReps.normalizedCount(count + 1)
            case .decrement:
                targetRepCounts[exerciseId] = WorkoutTargetReps.normalizedCount(count - 1)
            @unknown default:
                break
            }
        }
    }

    private func toggleExercise(_ exercise: Exercise) {
        if let index = selectedExerciseIds.firstIndex(of: exercise.id) {
            selectedExerciseIds.remove(at: index)
            targetSetCounts.removeValue(forKey: exercise.id)
            targetRepCounts.removeValue(forKey: exercise.id)
            HapticsService.closePanel()
        } else {
            selectedExerciseIds.append(exercise.id)
            targetSetCounts[exercise.id] = WorkoutTargetSets.defaultCount
            if exercise.measurementMode.recordsReps {
                targetRepCounts[exercise.id] = WorkoutTargetReps.defaultCount
            }
            HapticsService.switchExercise()
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            validationMessage = L10n.string("先输入模板名称。")
            HapticsService.actionFailed()
            return
        }

        guard !isDuplicateName else {
            validationMessage = L10n.string("这个模板名已经存在，换一个名称。")
            HapticsService.actionFailed()
            return
        }

        guard !selectedExerciseIds.isEmpty else {
            validationMessage = L10n.string("至少选择一个动作。")
            HapticsService.actionFailed()
            return
        }

        onSave(trimmedName, selectedExerciseIds, targetSetCounts, targetRepCounts)
        dismiss()
    }
}

private func plannedExerciseSummary(
    exercise: Exercise,
    targetSets: Int,
    targetReps: Int?
) -> String {
    if exercise.measurementMode.recordsReps, let targetReps {
        return "\(exercise.displayName) · \(L10n.count("count.sets", targetSets)) × \(L10n.count("count.reps", targetReps))"
    }
    return "\(exercise.displayName) · \(L10n.count("count.sets", targetSets))"
}

private struct TemplateRow: View {
    @Environment(\.trainingTheme) private var theme

    let template: WorkoutTemplate
    let exerciseSummaries: [String]
    let isOfficial: Bool
    let onStart: () -> Void
    let onDelete: () -> Void

    private var totalTargetSetCount: Int {
        template.exerciseIds.reduce(0) { $0 + template.targetSetCount(for: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(L10n.count("count.exercises", exerciseSummaries.count))

                        Text("· \(L10n.count("count.sets", totalTargetSetCount))")

                        if isOfficial {
                            Text("· 官方")
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.primary)
                }

                Spacer()

                Button(action: onStart) {
                    Label("开始", systemImage: "play.fill")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.primary, in: Capsule())
                }
                .buttonStyle(.plain)

                if !isOfficial {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(exerciseSummaries.joined(separator: " / "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20, interactive: true)
    }
}
