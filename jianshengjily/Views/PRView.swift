import SwiftData
import SwiftUI
import UIKit

struct PRView: View {
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query(sort: \SetLog.createdAt) private var setLogs: [SetLog]
    @State private var showingShareComposer = false

    private var records: [PersonalRecord] {
        let exerciseById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: setLogs, by: \.exerciseId)

        return grouped.compactMap { exerciseId, logs in
            guard let exercise = exerciseById[exerciseId] else {
                return nil
            }

            let measurementMode = exercise.measurementMode
            let maxWeight = logs.compactMap(\.weightKg).max()
            let maxReps = logs.compactMap(\.reps).max()
            let maxDuration = logs.compactMap(\.durationSeconds).max()
            let bestEstimatedOneRepMax = measurementMode == .externalLoadAndReps
                ? logs
                    .compactMap { WorkoutLogic.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }
                    .max()
                : nil

            guard let shareAchievement = PersonalRecordAchievement(logs: logs, measurementMode: measurementMode) else {
                return nil
            }

            return PersonalRecord(
                id: exercise.id,
                exerciseName: exercise.displayName,
                maxWeight: maxWeight,
                maxReps: maxReps,
                maxDuration: maxDuration,
                estimatedOneRepMax: bestEstimatedOneRepMax,
                measurementMode: measurementMode,
                shareAchievement: shareAchievement
            )
        }
        .sorted {
            if $0.shareAchievement.achievedAt != $1.shareAchievement.achievedAt {
                return $0.shareAchievement.achievedAt > $1.shareAchievement.achievedAt
            }

            let nameOrder = $0.exerciseName.localizedStandardCompare($1.exerciseName)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FirstUseHint("pr", message: "记录训练后，这里自动汇总你的最好成绩。点分享高光可制作成绩海报。")
                    FitnessSectionTitle(text: "个人 PR")

                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.secondary)

                            Text("还没有 PR")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("记录重量或次数后，这里会自动计算。")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .liquidGlassCard(cornerRadius: 26)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(records) { record in
                                PRRow(record: record)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("个人 PR")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsService.openPanel()
                    showingShareComposer = true
                } label: {
                    Label("分享高光", systemImage: "square.and.arrow.up")
                }
                .disabled(records.isEmpty)
            }
        }
        .sheet(isPresented: $showingShareComposer) {
            NavigationStack {
                PersonalRecordShareComposer(records: records)
            }
        }
    }
}

private struct PersonalRecord: Identifiable {
    let id: UUID
    let exerciseName: String
    let maxWeight: Double?
    let maxReps: Int?
    let maxDuration: Double?
    let estimatedOneRepMax: Double?
    let measurementMode: ExerciseMeasurementMode
    let shareAchievement: PersonalRecordAchievement
}

private struct PersonalRecordAchievement {
    enum Improvement {
        case firstRecord
        case weight(Double)
        case reps(Int)
        case duration(Double)
    }

    let measurementMode: ExerciseMeasurementMode
    let weightKg: Double?
    let reps: Int?
    let durationSeconds: Double?
    let achievedAt: Date
    let improvement: Improvement?

    init?(logs: [SetLog], measurementMode: ExerciseMeasurementMode) {
        let candidates = logs.filter { Self.hasShareableResult($0, measurementMode: measurementMode) }
        guard let bestSet = candidates.sorted(by: {
            Self.ranksAhead($0, $1, measurementMode: measurementMode)
        }).first else {
            return nil
        }

        let positiveWeight = measurementMode.acceptsLoad
            ? bestSet.weightKg.flatMap { $0 > 0 ? $0 : nil }
            : nil
        let positiveReps = measurementMode.recordsReps
            ? bestSet.reps.flatMap { $0 > 0 ? $0 : nil }
            : nil
        let positiveDuration = measurementMode.recordsDuration
            ? bestSet.durationSeconds.flatMap { $0 > 0 ? $0 : nil }
            : nil
        let previousSets = candidates.filter { $0.createdAt < bestSet.createdAt }

        self.measurementMode = measurementMode
        weightKg = positiveWeight
        reps = positiveReps
        durationSeconds = positiveDuration
        achievedAt = bestSet.createdAt
        improvement = Self.improvement(
            weightKg: positiveWeight,
            reps: positiveReps,
            durationSeconds: positiveDuration,
            previousSets: previousSets,
            measurementMode: measurementMode
        )
    }

    var resultText: String {
        let loadText = weightKg.map {
            L10n.format("weight.kg", WorkoutLogic.formattedWeight($0))
        }

        switch measurementMode {
        case .externalLoadAndReps:
            if let loadText, let reps {
                return "\(loadText) × \(reps)"
            }
            return loadText ?? reps.map { L10n.count("count.reps", $0) } ?? "-"
        case .bodyweightAndReps:
            if let loadText, let reps {
                return "\(L10n.format("附加负重 +%@", loadText)) × \(reps)"
            }
            return reps.map { L10n.count("count.reps", $0) } ?? "-"
        case .bodyweightAndDuration:
            let durationText = WorkoutLogic.shortDurationText(seconds: durationSeconds) ?? "-"
            guard let loadText else {
                return durationText
            }
            return "\(L10n.format("附加负重 +%@", loadText)) · \(durationText)"
        case .duration:
            return WorkoutLogic.shortDurationText(seconds: durationSeconds) ?? "-"
        case .externalLoadAndDuration:
            let durationText = WorkoutLogic.shortDurationText(seconds: durationSeconds) ?? "-"
            guard let loadText else {
                return durationText
            }
            return "\(loadText) · \(durationText)"
        }
    }

    var improvementText: String? {
        switch improvement {
        case .firstRecord:
            return L10n.string("首次记录")
        case let .weight(value):
            let weightText = L10n.format("weight.kg", WorkoutLogic.formattedWeight(value))
            return measurementMode.loadIsAdditional
                ? L10n.format("附加负重提升 +%@", weightText)
                : L10n.format("重量提升 +%@", weightText)
        case let .reps(value):
            return L10n.format("次数提升 +%lld", value)
        case let .duration(value):
            guard let durationText = WorkoutLogic.shortDurationText(seconds: value) else {
                return nil
            }
            return L10n.format("时长提升 +%@", durationText)
        case nil:
            return nil
        }
    }

    private static func hasShareableResult(
        _ set: SetLog,
        measurementMode: ExerciseMeasurementMode
    ) -> Bool {
        if measurementMode.recordsDuration {
            return (set.durationSeconds ?? 0) > 0
        }
        if measurementMode == .bodyweightAndReps {
            return (set.reps ?? 0) > 0
        }
        return (set.weightKg ?? 0) > 0 || (set.reps ?? 0) > 0
    }

    private static func ranksAhead(
        _ lhs: SetLog,
        _ rhs: SetLog,
        measurementMode: ExerciseMeasurementMode
    ) -> Bool {
        if measurementMode.acceptsLoad {
            let lhsWeight = max(lhs.weightKg ?? 0, 0)
            let rhsWeight = max(rhs.weightKg ?? 0, 0)
            if lhsWeight != rhsWeight {
                return lhsWeight > rhsWeight
            }
        }

        if measurementMode.recordsReps {
            let lhsReps = max(lhs.reps ?? 0, 0)
            let rhsReps = max(rhs.reps ?? 0, 0)
            if lhsReps != rhsReps {
                return lhsReps > rhsReps
            }
        } else {
            let lhsDuration = max(lhs.durationSeconds ?? 0, 0)
            let rhsDuration = max(rhs.durationSeconds ?? 0, 0)
            if lhsDuration != rhsDuration {
                return lhsDuration > rhsDuration
            }
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func improvement(
        weightKg: Double?,
        reps: Int?,
        durationSeconds: Double?,
        previousSets: [SetLog],
        measurementMode: ExerciseMeasurementMode
    ) -> Improvement? {
        guard !previousSets.isEmpty else {
            return .firstRecord
        }

        if let weightKg {
            let previousMaximumWeight = previousSets
                .compactMap(\.weightKg)
                .filter { $0 > 0 }
                .max()

            if let previousMaximumWeight, weightKg > previousMaximumWeight {
                return .weight(weightKg - previousMaximumWeight)
            }

            if measurementMode.loadIsAdditional, previousMaximumWeight == nil {
                return .weight(weightKg)
            }

            if measurementMode.recordsReps, let reps {
                let previousRepsAtWeight = previousSets
                    .filter { abs(($0.weightKg ?? 0) - weightKg) < 0.001 }
                    .compactMap(\.reps)
                    .max()

                if let previousRepsAtWeight, reps > previousRepsAtWeight {
                    return .reps(reps - previousRepsAtWeight)
                }
            }

            if measurementMode.recordsDuration, let durationSeconds {
                let previousDurationAtWeight = previousSets
                    .filter { abs(($0.weightKg ?? 0) - weightKg) < 0.001 }
                    .compactMap(\.durationSeconds)
                    .max()

                if let previousDurationAtWeight, durationSeconds > previousDurationAtWeight {
                    return .duration(durationSeconds - previousDurationAtWeight)
                }
            }

            return previousMaximumWeight == nil ? .firstRecord : nil
        }

        if measurementMode.recordsReps, let reps {
            let previousMaximumReps = previousSets
                .filter { ($0.weightKg ?? 0) <= 0 }
                .compactMap(\.reps)
                .max()
            if let previousMaximumReps, reps > previousMaximumReps {
                return .reps(reps - previousMaximumReps)
            }
            return previousMaximumReps == nil ? .firstRecord : nil
        }

        if measurementMode.recordsDuration, let durationSeconds {
            let previousMaximumDuration = previousSets
                .filter { ($0.weightKg ?? 0) <= 0 }
                .compactMap(\.durationSeconds)
                .max()
            if let previousMaximumDuration, durationSeconds > previousMaximumDuration {
                return .duration(durationSeconds - previousMaximumDuration)
            }
            return previousMaximumDuration == nil ? .firstRecord : nil
        }

        return nil
    }
}

private struct PRRow: View {
    let record: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(record.exerciseName)
                .font(.title3.bold())
                .foregroundStyle(.white)

            metrics
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22)
    }

    @ViewBuilder
    private var metrics: some View {
        HStack(spacing: 12) {
            switch record.measurementMode {
            case .externalLoadAndReps:
                PRMetric(title: "最大重量", value: formattedWeight(record.maxWeight))
                PRMetric(title: "最多次数", value: record.maxReps.map(String.init) ?? "-")
                PRMetric(title: "估算 1RM", value: formattedWeight(record.estimatedOneRepMax))
            case .bodyweightAndReps:
                PRMetric(title: "最多次数", value: record.maxReps.map(String.init) ?? "-")
                PRMetric(title: "最大附加负重", value: formattedAddedLoad(record.maxWeight))
                PRMetric(title: "最佳一组", value: record.shareAchievement.resultText)
            case .bodyweightAndDuration:
                PRMetric(title: "最长时间", value: formattedDuration(record.maxDuration))
                PRMetric(title: "最大附加负重", value: formattedAddedLoad(record.maxWeight))
                PRMetric(title: "最佳一组", value: record.shareAchievement.resultText)
            case .duration:
                PRMetric(title: "最长时间", value: formattedDuration(record.maxDuration))
                PRMetric(title: "最佳一组", value: record.shareAchievement.resultText)
            case .externalLoadAndDuration:
                PRMetric(title: "最大重量", value: formattedWeight(record.maxWeight))
                PRMetric(title: "最长时间", value: formattedDuration(record.maxDuration))
                PRMetric(title: "最佳一组", value: record.shareAchievement.resultText)
            }
        }
    }

    private func formattedWeight(_ value: Double?) -> String {
        value.map { L10n.format("weight.kg", WorkoutLogic.formattedWeight($0)) } ?? "-"
    }

    private func formattedAddedLoad(_ value: Double?) -> String {
        guard let value, value > 0 else {
            return L10n.string("自重")
        }
        return "+\(L10n.format("weight.kg", WorkoutLogic.formattedWeight(value)))"
    }

    private func formattedDuration(_ value: Double?) -> String {
        WorkoutLogic.shortDurationText(seconds: value) ?? "-"
    }
}

private struct PersonalRecordShareComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingTheme) private var theme

    let records: [PersonalRecord]

    @State private var selectedRecordIDs: [UUID]
    @State private var showingPreview = false

    private let maximumSelectionCount = 4

    init(records: [PersonalRecord]) {
        self.records = records
        _selectedRecordIDs = State(initialValue: Array(records.prefix(3).map(\.id)))
    }

    private var selectedRecords: [PersonalRecord] {
        selectedRecordIDs.compactMap { id in
            records.first(where: { $0.id == id })
        }
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("挑选你的高光")
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)

                            Text("按想展示的顺序选择 1–4 个动作；第一个会成为海报主角。")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            Text(L10n.format("已选 %1$lld / %2$lld", selectedRecordIDs.count, maximumSelectionCount))
                                .font(.caption.weight(.black))
                                .foregroundStyle(theme.primary)

                            Spacer()

                            Text("最多选择 4 个动作")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 10) {
                            ForEach(records) { record in
                                selectionRow(for: record)
                            }
                        }
                    }
                    .padding(20)
                }

                Button {
                    HapticsService.openPanel()
                    showingPreview = true
                } label: {
                    Label("预览高光海报", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedRecordIDs.isEmpty)
                .trainingButtonStyle(tint: theme.primary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(.black.opacity(0.72))
            }
        }
        .navigationTitle("分享 PR 高光")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    HapticsService.closePanel()
                    dismiss()
                }
            }
        }
        .navigationDestination(isPresented: $showingPreview) {
            PersonalRecordShareView(records: selectedRecords)
        }
    }

    private func selectionRow(for record: PersonalRecord) -> some View {
        let selectionIndex = selectedRecordIDs.firstIndex(of: record.id)
        let isSelected = selectionIndex != nil

        return Button {
            toggleSelection(for: record)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? theme.primary : .white.opacity(0.08))
                        .frame(width: 36, height: 36)

                    if let selectionIndex {
                        Text("\(selectionIndex + 1)")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.black)
                            .monospacedDigit()
                    } else {
                        Image(systemName: "circle")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.exerciseName)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(record.highlightSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? theme.primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? theme.primary : .secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .liquidGlassCard(cornerRadius: 20, tint: isSelected ? theme.primary : nil, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(for record: PersonalRecord) {
        if let index = selectedRecordIDs.firstIndex(of: record.id) {
            selectedRecordIDs.remove(at: index)
            HapticsService.switchExercise()
            return
        }

        guard selectedRecordIDs.count < maximumSelectionCount else {
            HapticsService.actionFailed()
            return
        }

        selectedRecordIDs.append(record.id)
        HapticsService.selectExercise()
    }
}

private struct PersonalRecordShareView: View {
    @Environment(\.trainingTheme) private var theme

    let records: [PersonalRecord]

    @State private var posterURL: URL?
    @State private var didFail = false

    private var posterImage: UIImage? {
        guard let posterURL else {
            return nil
        }
        return UIImage(contentsOfFile: posterURL.path)
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(spacing: 18) {
                    if let posterImage {
                        Image(uiImage: posterImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.12), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
                    } else if didFail {
                        ContentUnavailableView {
                            Label("海报生成失败", systemImage: "exclamationmark.triangle")
                        } actions: {
                            Button("生成分享海报", action: generatePoster)
                                .trainingButtonStyle(tint: theme.primary)
                        }
                        .frame(minHeight: 420)
                    } else {
                        ProgressView()
                            .tint(theme.primary)
                            .frame(maxWidth: .infinity, minHeight: 420)
                    }

                    if let posterURL {
                        ShareLink(item: posterURL) {
                            Label("分享这组 PR", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticsService.shareStarted()
                        })
                        .trainingButtonStyle(tint: theme.primary)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("PR 海报")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            generatePoster()
        }
        .onDisappear {
            removePoster()
        }
    }

    private func generatePoster() {
        removePoster()
        didFail = false

        posterURL = SharePosterService.makePersonalRecordPoster(
            records: records.map(\.posterItem),
            theme: theme
        )
        didFail = posterURL == nil

        if didFail {
            HapticsService.actionFailed()
        } else {
            HapticsService.sharePosterReady()
        }
    }

    private func removePoster() {
        guard let posterURL else {
            return
        }

        SharePosterService.removePoster(at: posterURL)
        self.posterURL = nil
    }
}

private extension PersonalRecord {
    var posterItem: PersonalRecordPosterItem {
        PersonalRecordPosterItem(
            exerciseName: exerciseName,
            resultText: shareAchievement.resultText,
            achievedAt: shareAchievement.achievedAt,
            improvementText: shareAchievement.improvementText
        )
    }

    var highlightSummary: String {
        "\(L10n.string("最佳一组")) · \(shareAchievement.resultText)"
    }
}

private struct PRMetric: View {
    @Environment(\.trainingTheme) private var theme

    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.string(title))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(theme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
