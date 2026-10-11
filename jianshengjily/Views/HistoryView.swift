import SwiftData
import SwiftUI
import Charts
import UIKit

struct MuscleTrainingMapView: View {
    @Query private var sessions: [WorkoutSession]
    @Query private var logs: [SetLog]
    @Query private var exercises: [Exercise]
    @State private var days = 7
    @State private var back = false
    @State private var selected: String?
    @Environment(\.trainingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let regions = ["chest", "abs", "quads", "back", "glutes", "hamstrings", "calves"]
    private let titles = ["chest": "胸部", "abs": "腹部", "quads": "大腿前侧", "back": "背部", "glutes": "臀部", "hamstrings": "大腿后侧", "calves": "小腿"]

    private var counts: [String: Int] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: now))!
        let ids = Set(sessions.filter { $0.status == .finished && $0.startedAt >= start && $0.startedAt <= now }.map(\.id))
        var groups: [UUID: String] = [:]
        for exercise in exercises { groups[exercise.id] = Self.region(for: exercise.name) }
        var result: [String: Int] = [:]
        for log in logs where ids.contains(log.sessionId) {
            result[groups[log.exerciseId] ?? "unmapped", default: 0] += 1
        }
        return result
    }

    // One primary region per set. Do not imply measured muscle activation.
    static func region(for name: String) -> String {
        let rules: [(String, [String])] = [
            ("calves", ["提踵", "calf raise"]),
            ("hamstrings", ["腿弯举", "罗马尼亚硬拉", "直腿硬拉", "leg curl", "romanian deadlift"]),
            ("glutes", ["臀推", "臀桥", "hip thrust", "glute bridge"]),
            ("quads", ["深蹲", "腿举", "腿屈伸", "squat", "leg press", "leg extension"]),
            ("abs", ["卷腹", "平板支撑", "悬垂举腿", "死虫", "俄罗斯转体", "crunch", "plank"]),
            ("back", ["引体", "下拉", "划船", "pull-up", "pulldown", "row"]),
            ("chest", ["卧推", "推胸", "俯卧撑", "夹胸", "bench press", "push-up", "chest press"])
        ]
        return rules.first { $0.1.contains { name.localizedCaseInsensitiveContains($0) } }?.0 ?? "unmapped"
    }

    var body: some View {
        ZStack {
                    TrainingGlassBackground()
                    ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    Picker("统计范围", selection: $days) {
                        Text("近 7 天").tag(7)
                        Text("近 30 天").tag(30)
                    }.pickerStyle(.segmented).padding(.horizontal)
                    HStack {
                        Picker("人体视角", selection: $back) {
                            Text("正面").tag(false)
                            Text("背面").tag(true)
                        }.pickerStyle(.segmented).frame(maxWidth: 200)
                        Spacer()
                        Button("全身") { selected = nil }
                            .disabled(selected == nil)
                    }
                    NativeMuscleMap(counts: counts, back: back, selected: selected,
                                    tint: UIColor(theme.primary), reduceMotion: reduceMotion) { id in
                        select(id)
                    }
                    .frame(height: 390)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel("人体肌群图，请使用下方部位按钮选择")
                    HStack(alignment: .firstTextBaseline) {
                        Text(selected.flatMap { titles[$0] } ?? "训练分布").font(.title2.bold())
                        Spacer()
                        Text("\(selected.map { counts[$0, default: 0] } ?? counts.values.reduce(0, +)) 组")
                            .font(.title2.monospacedDigit().bold()).foregroundStyle(theme.primary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(regions, id: \.self) { id in
                            Button { select(id) } label: {
                                HStack {
                                    Text(titles[id] ?? id)
                                    Spacer()
                                    Text("\(counts[id, default: 0])").monospacedDigit()
                                }.font(.subheadline.weight(.semibold)).padding(14)
                                    .foregroundStyle(selected == id ? theme.primary : .white)
                                    .background(selected == id ? theme.primary.opacity(0.16) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                            .accessibilityAddTraits(selected == id ? .isSelected : [])
                        }
                    }
                    if counts.values.reduce(0, +) == 0 {
                        Text("这段时间还没有完成训练，完成一练后再来看。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(L10n.format("muscle_map.unmapped_sets", counts["unmapped", default: 0]))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("仅统计已结束的训练。每组归入一个主要部位，颜色表示组数，不代表肌肉激活或恢复程度。")
                        .font(.caption).foregroundStyle(.secondary)
                    }.padding(20)
                    }
        }
        .navigationTitle("肌群训练图")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onChange(of: back) { _, value in
            if let selected, Self.isBack(selected) != value { self.selected = nil }
        }
    }

    private func select(_ id: String) {
        back = Self.isBack(id)
        selected = id
        HapticsService.openPanel()
    }
    static func isBack(_ id: String) -> Bool { ["back", "glutes", "hamstrings", "calves"].contains(id) }
}


private struct NativeMuscleMap: UIViewRepresentable {
    let counts: [String: Int]
    let back: Bool
    let selected: String?
    let tint: UIColor
    let reduceMotion: Bool
    let onSelect: (String) -> Void
    func makeUIView(context: Context) -> MuscleCanvas { MuscleCanvas() }
    func updateUIView(_ view: MuscleCanvas, context: Context) {
        view.onSelect = onSelect
        view.configure(counts: counts, back: back, selected: selected, tint: tint, animated: !reduceMotion)
    }
}

private final class MuscleCanvas: UIView {
    private struct Command: Decodable { let op: String; let v: [CGFloat] }
    private struct Contour: Decodable { let box: [CGFloat]; let paths: [[Command]] }
    private static let contours: [String: Contour] = {
        guard let url = Bundle.main.url(forResource: "contours", withExtension: "json", subdirectory: "MuscleMap"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: Contour].self, from: data) else { return [:] }
        return result
    }()
    private static let picture: UIImage? = {
        guard let url = Bundle.main.url(forResource: "user-reference-v2", withExtension: "png", subdirectory: "MuscleMap/assets") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
    private static let paths: [String: UIBezierPath] = contours.mapValues { contour in
        let path = UIBezierPath()
        for commands in contour.paths {
            for command in commands {
                let v = command.v
                switch command.op {
                case "M" where v.count == 2: path.move(to: CGPoint(x: v[0], y: v[1]))
                case "L" where v.count == 2: path.addLine(to: CGPoint(x: v[0], y: v[1]))
                case "Q" where v.count == 4: path.addQuadCurve(to: CGPoint(x: v[2], y: v[3]), controlPoint: CGPoint(x: v[0], y: v[1]))
                case "C" where v.count == 6: path.addCurve(to: CGPoint(x: v[4], y: v[5]), controlPoint1: CGPoint(x: v[0], y: v[1]), controlPoint2: CGPoint(x: v[2], y: v[3]))
                case "Z": path.close()
                default: break
                }
            }
        }
        return path
    }
    var onSelect: ((String) -> Void)?
    private var counts: [String: Int] = [:]
    private var back = false
    private var selected: String?
    private var accent = UIColor.systemOrange
    private var viewport = CGRect(x: 35, y: 0, width: 620, height: 1199)
    private var origin = CGRect.zero
    private var destination = CGRect.zero
    private var start: CFTimeInterval = 0
    private var timer: CADisplayLink?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.94, alpha: 1)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { timer?.invalidate(); timer = nil }
    }
    func configure(counts: [String: Int], back: Bool, selected: String?, tint: UIColor, animated: Bool) {
        self.counts = counts; self.back = back; self.selected = selected; accent = tint
        let box = selected.flatMap { Self.contours[$0]?.box }
        let target = box.map { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
            ?? CGRect(x: back ? 640 : 35, y: 0, width: 620, height: 1199)
        if target != destination {
            timer?.invalidate(); timer = nil
            origin = viewport; destination = target
            if animated && window != nil {
                start = CACurrentMediaTime()
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common); timer = link
            } else { viewport = target }
        }
        setNeedsDisplay()
    }
    @objc private func tick() {
        let progress = min(1, (CACurrentMediaTime() - start) / 0.38)
        let t = CGFloat(progress * progress * (3 - 2 * progress))
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        viewport = CGRect(x: mix(origin.minX, destination.minX), y: mix(origin.minY, destination.minY), width: mix(origin.width, destination.width), height: mix(origin.height, destination.height))
        setNeedsDisplay()
        if progress == 1 { timer?.invalidate(); timer = nil }
    }
    private var drawingTransform: CGAffineTransform {
        let scale = min(bounds.width / viewport.width, bounds.height / viewport.height)
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                 tx: bounds.midX - viewport.midX * scale,
                                 ty: bounds.midY - viewport.midY * scale)
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        guard let picture = Self.picture, !Self.paths.isEmpty else {
            ("肌群图暂时无法加载" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.foregroundColor: UIColor.darkGray])
            return
        }
        context.saveGState()
        context.concatenate(drawingTransform)
        context.clip(to: CGRect(x: back ? 656 : 0, y: 0, width: 656, height: 1199))
        picture.draw(in: CGRect(x: 0, y: 0, width: 1312, height: 1199))
        let peak = max(1, counts.filter { $0.key != "unmapped" }.values.max() ?? 1)
        for (id, path) in Self.paths where MuscleTrainingMapView.isBack(id) == back {
            let count = counts[id, default: 0]
            let opacity: CGFloat = selected == id ? 0.46 : count > 0 ? 0.1 + 0.25 * CGFloat(count) / CGFloat(peak) : 0
            accent.withAlphaComponent(opacity).setFill(); path.fill()
        }
        context.restoreGState()
    }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self).applying(drawingTransform.inverted())
        if let id = Self.paths.first(where: { MuscleTrainingMapView.isBack($0.key) == back && $0.value.contains(point) })?.key { onSelect?(id) }
    }
}

struct HistoryView: View {
    var onRepeat: ((WorkoutSession) -> Void)? = nil
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \SetLog.createdAt) private var setLogs: [SetLog]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    private var finishedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .finished }
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink { WorkoutInsightsView() } label: {
                        Label("进步复盘", systemImage: "chart.xyaxis.line")
                            .font(.headline).frame(maxWidth: .infinity).padding(18)
                    }
                    .liquidGlassCard(cornerRadius: 22)
                    NavigationLink { WorkoutStatisticsView() } label: {
                        Label("训练统计", systemImage: "chart.bar.xaxis")
                            .font(.headline).frame(maxWidth: .infinity).padding(18)
                    }
                    .liquidGlassCard(cornerRadius: 22)
                    if finishedSessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.secondary)

                            Text("暂无历史记录")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("结束训练后会显示在这里。")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 320)
                        .liquidGlassCard(cornerRadius: 26)
                    } else {
                        ForEach(finishedSessions) { session in
                            HistoryRow(session: session, setLogs: setLogs, exercises: exercises, onRepeat: onRepeat)
                                .padding(18)
                                .liquidGlassCard(cornerRadius: 22, interactive: true)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("历史记录")
        .preferredColorScheme(.dark)
    }
}

private struct HistoryRow: View {
    @Environment(\.trainingTheme) private var theme

    let session: WorkoutSession
    let setLogs: [SetLog]
    let exercises: [Exercise]
    let onRepeat: ((WorkoutSession) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(WorkoutService.durationText(for: session))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ExerciseGlyphView(size: 18)
                    Text(L10n.count("count.exercises", WorkoutService.exerciseCount(in: session, setLogs: setLogs)))
                }

                HStack(spacing: 6) {
                    SetCountGlyphView(size: 18)
                    Text(L10n.count("count.sets", WorkoutService.totalSetCount(in: session, setLogs: setLogs)))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                NavigationLink {
                    HistoryDetailView(session: session, setLogs: setLogs, exercises: exercises, onRepeat: onRepeat)
                } label: {
                    Label("查看详情", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticsService.openPanel()
                })
                .trainingButtonStyle(tint: theme.primary)

                SharePosterButton(session: session, setLogs: setLogs, exercises: exercises)
            }
        }
    }
}

struct WorkoutStatisticsView: View {
    @Environment(\.trainingTheme) private var theme
    @Query private var sessions: [WorkoutSession]
    @Query private var logs: [SetLog]
    @Query private var exercises: [Exercise]
    @State private var dayCount = 7

    private var statistics: WorkoutStatistics {
        WorkoutStatistics(sessions: sessions, logs: logs, exercises: exercises, dayCount: dayCount)
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("每一次训练，都在积累")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("查看训练频率、总组数、训练时长和负重训练量。")
                        .foregroundStyle(.secondary)
                        Picker("统计范围", selection: $dayCount) {
                            Text("近 7 天").tag(7)
                            Text("近 30 天").tag(30)
                        }.pickerStyle(.segmented)
                        let data = statistics
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metric("训练次数", value: "\(data.workoutCount)", icon: "calendar")
                            metric("总组数", value: "\(data.setCount)", icon: "checkmark.circle")
                            metric("累计时长（分钟）", value: "\(data.durationMinutes)", icon: "clock")
                            metric("负重训练量（kg）", value: data.volumeKg.formatted(.number.precision(.fractionLength(0))), icon: "scalemass")
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Text("训练频率").font(.headline)
                            Chart(data.days) { day in
                                BarMark(x: .value("日期", day.date, unit: .day), y: .value("训练次数", day.workouts))
                                    .foregroundStyle(theme.primary.gradient)
                                    .cornerRadius(4)
                            }
                            .chartYScale(domain: 0...max(1, data.days.map(\.workouts).max() ?? 1))
                            .chartYAxis { AxisMarks(values: .stride(by: 1)) }
                            .chartXAxis { AxisMarks(values: .stride(by: .day, count: dayCount == 7 ? 1 : 7)) { _ in
                                AxisValueLabel(format: .dateTime.day())
                            } }
                            .frame(height: 180)
                            if data.workoutCount == 0 {
                                Text("这段时间还没有完成训练，完成一练后再来看。")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(18).liquidGlassCard(cornerRadius: 24)
                        Text("仅统计已结束的训练，按训练开始日期归属。负重训练量为重量 × 实际次数之和；自重只计附加负重，计时动作不计入。")
                            .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
        }
        .navigationTitle("训练统计")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func metric(_ title: LocalizedStringKey, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(theme.primary)
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).liquidGlassCard(cornerRadius: 22)
    }
}

struct WorkoutInsightsView: View {
    @Environment(\.trainingTheme) private var theme
    @Query private var sessions: [WorkoutSession]
    @Query private var logs: [SetLog]
    @Query private var exercises: [Exercise]
    @State private var selectedExerciseID: UUID?

    private var insights: WorkoutInsights {
        WorkoutInsights(sessions: sessions, logs: logs, exercises: exercises)
    }

    private var selectedTrend: WorkoutInsights.ExerciseTrend? {
        let available = insights.trends
        return available.first { $0.id == selectedExerciseID } ?? available.first
    }

    var body: some View {
        ZStack {
                    TrainingGlassBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            if sessions.contains(where: { $0.status == .finished }) {
                                periodComparison
                                exerciseSection
                            } else {
                                emptyStart
                            }
                        }
                        .padding(20)
                    }
        }
        .navigationTitle("进步复盘")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练概览")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(L10n.string(sessions.contains(where: { $0.status == .finished })
                             ? "先对照两段训练，再看每个动作的记录。"
                             : "每次训练结束后，进步会在这里累积。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title.bold())
                .foregroundStyle(theme.primary)
            Text("先完成一练")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("完成训练后，这里会显示近7天对比和单动作记录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }

    private var periodComparison: some View {
        let data = insights
        return VStack(alignment: .leading, spacing: 14) {
            Text("近7天对比")
                .font(.title2.bold())
                .foregroundStyle(.white)
            comparisonRow("训练次数",
                          recent: L10n.count("count.workouts", data.recent.workoutCount),
                          previous: L10n.count("count.workouts", data.previous.workoutCount))
            comparisonRow("总组数",
                          recent: L10n.count("count.sets", data.recent.setCount),
                          previous: L10n.count("count.sets", data.previous.setCount))
            comparisonRow("负重训练量",
                          recent: "\(data.recent.volumeKg.formatted(.number.precision(.fractionLength(0)))) kg",
                          previous: "\(data.previous.volumeKg.formatted(.number.precision(.fractionLength(0)))) kg")
            Text("只统计已结束的训练；负重训练量是有效重量乘以实际次数。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func comparisonRow(_ title: String, recent: String, previous: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(L10n.string(title))
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(recent)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                Text(L10n.format("insights.previous_period", previous))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("按动作看进步")
                .font(.title2.bold())
                .foregroundStyle(.white)
            if let trend = selectedTrend {
                Menu {
                    ForEach(insights.trends) { option in
                        Button(option.name) { selectedExerciseID = option.id }
                    }
                } label: {
                    HStack {
                        Text(trend.name)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .liquidGlassCard(cornerRadius: 16, tint: theme.primary)
                }
                Text(L10n.format("insights.trend_count", L10n.count("count.workouts", trend.points.count), L10n.string(trend.metric.title)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                trendCard(trend)
            } else {
                Text("完成训练后，这里会显示每个动作的趋势。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassCard(cornerRadius: 20)
            }
        }
    }

    private func trendCard(_ trend: WorkoutInsights.ExerciseTrend) -> some View {
        let values = trend.points.map(\.value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let padding = max(1, (maximum - minimum) * 0.2)
        return VStack(alignment: .leading, spacing: 16) {
            if let latest = trend.points.last {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最近一次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pointValue(latest, trend: trend))
                            .font(.title.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if let first = trend.points.first, first.id != latest.id {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("最早一条")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(pointValue(first, trend: trend))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if trend.points.count >= 2 {
                Chart(trend.points) { point in
                    LineMark(x: .value("日期", point.date), y: .value("记录值", point.value))
                        .foregroundStyle(theme.primary)
                    PointMark(x: .value("日期", point.date), y: .value("记录值", point.value))
                        .foregroundStyle(theme.primary)
                        .symbolSize(55)
                }
                .chartYScale(domain: max(0, minimum - padding)...(maximum + padding))
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 190)
                .accessibilityLabel(Text(L10n.format("insights.chart_accessibility", trend.name, L10n.string(trend.metric.title))))
            }
            if trend.points.count == 1 {
                Text("再完成一次这个动作，就能看到变化趋势。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("逐次记录") {
                VStack(spacing: 10) {
                    ForEach(Array(trend.points.reversed())) { point in
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(pointValue(point, trend: trend))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            Text(L10n.string(trend.metric == .weightKg
                 ? "每个点是一场训练的最重一组；次数可能不同，不能直接当作最大力量。"
                 : "每个点是该动作当次训练的最高记录；如有负重，会一起标注。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func pointValue(_ point: WorkoutInsights.TrendPoint, trend: WorkoutInsights.ExerciseTrend) -> String {
        let number = point.value.formatted(.number.precision(.fractionLength(trend.metric == .weightKg ? 0...1 : 0...0)))
        if trend.metric == .weightKg, let reps = point.reps {
            return L10n.format("insights.weight_reps", number, L10n.count("count.reps", reps))
        }
        let result = "\(number) \(trend.metric.unit)"
        guard let load = point.loadKg else { return result }
        let formattedLoad = load.formatted(.number.precision(.fractionLength(0...1)))
        return L10n.format(trend.loadIsAdditional ? "insights.added_load" : "insights.external_load", result, formattedLoad)
    }
}

struct SharePosterButton: View {
    @Environment(\.trainingTheme) private var theme

    let session: WorkoutSession
    let setLogs: [SetLog]
    let exercises: [Exercise]

    @State private var posterURL: URL?

    var body: some View {
        Group {
            if let posterURL {
                ShareLink(item: posterURL) {
                    Label("分享训练海报", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticsService.shareStarted()
                })
                .trainingButtonStyle(tint: .white)
            } else {
                Button {
                    let url = SharePosterService.makePoster(
                        session: session,
                        setLogs: setLogs,
                        exercises: exercises,
                        theme: theme
                    )
                    posterURL = url
                    if url == nil {
                        HapticsService.actionFailed()
                    } else {
                        HapticsService.sharePosterReady()
                    }
                } label: {
                    Label("生成分享海报", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .trainingButtonStyle(tint: .white)
            }
        }
        .onDisappear {
            if let posterURL {
                SharePosterService.removePoster(at: posterURL)
                self.posterURL = nil
            }
        }
    }
}
