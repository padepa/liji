import SwiftUI

/// A visual-first recap. It only presents facts already recorded for this session.
struct WorkoutRecapPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trainingTheme) private var theme

    let session: WorkoutSession
    let setLogs: [SetLog]
    let exercises: [Exercise]

    private struct ExerciseProgress: Identifiable {
        let exercise: Exercise
        let completedSets: Int
        let targetSets: Int?

        var id: UUID { exercise.id }

        var fraction: Double? {
            guard let targetSets, targetSets > 0 else { return nil }
            return min(Double(completedSets) / Double(targetSets), 1)
        }
    }

    private var sessionSets: [SetLog] {
        setLogs.filter { $0.sessionId == session.id }
    }

    private var exerciseProgress: [ExerciseProgress] {
        WorkoutService.exercisesUsed(in: session, exercises: exercises, setLogs: setLogs).map { exercise in
            ExerciseProgress(
                exercise: exercise,
                completedSets: sessionSets.filter { $0.exerciseId == exercise.id }.count,
                targetSets: session.targetSetCount(for: exercise.id)
            )
        }
    }

    private var targetedExercises: [ExerciseProgress] {
        exerciseProgress.filter { ($0.targetSets ?? 0) > 0 }
    }

    private var completedTargetCount: Int {
        targetedExercises.filter { $0.completedSets >= ($0.targetSets ?? 0) }.count
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metrics
                    exerciseSection
                    observation
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .frame(maxWidth: .infinity)
            }
            .trainingButtonStyle(prominent: true, tint: theme.primary)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("训练复盘")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TrainingStageLabel(text: "训练完成")
                Spacer()
                Text("界面预览")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("本次训练已保存")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(.white)

                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(WorkoutService.durationText(for: session))
                    .font(.system(size: 47, weight: .black, design: .rounded))
                    .tracking(-1.7)
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text("训练时长")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 28, tint: theme.primary)
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(title: "动作", value: exerciseProgress.count, symbol: "figure.strengthtraining.traditional")

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 54)
                .padding(.horizontal, 18)
                .accessibilityHidden(true)

            metric(title: "总组数", value: sessionSets.count, symbol: "square.stack.3d.up")
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func metric(title: String, value: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value.formatted())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("动作完成情况")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                if !targetedExercises.isEmpty {
                    Text(L10n.format("recap.targets_progress", completedTargetCount, targetedExercises.count))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                }
            }

            if exerciseProgress.isEmpty {
                Text("没有组记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(exerciseProgress) { item in
                        exerciseRow(item)

                        if item.id != exerciseProgress.last?.id {
                            Rectangle()
                                .fill(.white.opacity(0.09))
                                .frame(height: 1)
                                .padding(.leading, 54)
                                .padding(.vertical, 13)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(18)
                .liquidGlassCard(cornerRadius: 24)
            }
        }
    }

    private func exerciseRow(_ item: ExerciseProgress) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ExerciseGlyphView(exerciseName: item.exercise.name, size: 42)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.exercise.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 4)

                    Text(item.targetSets.map {
                        L10n.format("recap.sets_progress", item.completedSets, $0)
                    } ?? L10n.count("count.sets", item.completedSets))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(item.fraction == 1 ? theme.primary : Color.secondary)
                        .fixedSize()
                }

                if let fraction = item.fraction {
                    ProgressView(value: fraction)
                        .tint(theme.primary)
                        .accessibilityLabel(Text("目标组数"))
                        .accessibilityValue(Text(L10n.format("recap.sets_progress", item.completedSets, item.targetSets ?? 0)))
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var observation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(theme.primary)
                Text("本次观察")
                    .foregroundStyle(.white)
            }
            .font(.subheadline.weight(.bold))

            Text(observationText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("仅展示已记录的训练数据")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 24, tint: theme.primary)
    }

    private var observationText: String {
        guard !targetedExercises.isEmpty else {
            return L10n.string("继续记录，逐步看见变化")
        }
        if completedTargetCount == targetedExercises.count {
            return L10n.string("已完成本次设定的全部目标组数")
        }
        return L10n.format("recap.completed_targets", completedTargetCount, targetedExercises.count)
    }
}
