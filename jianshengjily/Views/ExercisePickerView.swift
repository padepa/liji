import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    let session: WorkoutSession
    var tutorialOnly = false
    var onPick: (Exercise) -> Void

    @State private var searchText = ""
    @State private var customExerciseName = ""
    @State private var showingCustomExercisePrompt = false
    @State private var selectedFilter = ExercisePickerFilter.all

    private var filteredExercises: [Exercise] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
            selectedFilter.includes(exercise.name)
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
        Group {
            if tutorialOnly { pickerContent }
            else { normalBody }
        }
    }

    private var pickerContent: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(spacing: 12) {
                    TrainingSearchField(text: $searchText, prompt: "搜索动作")
                    filterBar

                    if filteredExercises.isEmpty {
                        emptyFilteredState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredExercises) { exercise in
                                exerciseButton(exercise)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var normalBody: some View {
        pickerContent
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("选择动作")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    HapticsService.closePanel()
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsService.openPanel()
                    showingCustomExercisePrompt = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3.weight(.bold))
                }
                .accessibilityLabel("自定义动作")
            }
        }
        .alert("自定义动作", isPresented: $showingCustomExercisePrompt) {
            TextField("动作名称", text: $customExerciseName)
            Button("添加") {
                addCustomExercise()
            }
            Button("取消", role: .cancel) {
                customExerciseName = ""
                HapticsService.closePanel()
            }
        } message: {
            Text("输入本次要记录的动作名称。")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExercisePickerFilter.allCases) { filter in
                    filterButton(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterButton(_ filter: ExercisePickerFilter) -> some View {
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

    private var emptyFilteredState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.primary)

            Text("没有匹配动作")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .liquidGlassCard(cornerRadius: 20)
    }

    private func exerciseButton(_ exercise: Exercise) -> some View {
        Button {
            pick(exercise)
        } label: {
            HStack(spacing: 12) {
                ExerciseGlyphView(exerciseName: exercise.name, size: 36)

                Text(exercise.displayName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 10)

                if session.exerciseIds.contains(exercise.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func pick(_ exercise: Exercise) {
        WorkoutService.addExercise(exercise, to: session, in: modelContext)
        HapticsService.selectExercise()
        onPick(exercise)
        dismiss()
    }

    private func addCustomExercise() {
        guard let exercise = WorkoutService.createCustomExercise(named: customExerciseName, in: modelContext) else {
            HapticsService.actionFailed()
            return
        }

        customExerciseName = ""
        pick(exercise)
    }
}

private enum ExercisePickerFilter: String, CaseIterable, Identifiable {
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
