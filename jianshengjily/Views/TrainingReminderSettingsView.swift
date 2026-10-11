import SwiftUI
import UIKit

struct TrainingReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.trainingTheme) private var theme

    @State private var schedule = TrainingReminderService.loadSchedule()
    @State private var authorizationState: TrainingReminderAuthorizationState = .notDetermined
    @State private var isSaving = false
    @State private var alert: TrainingReminderAlert?

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    reminderHero
                    reminderToggleCard
                    scheduleCard
                    permissionCard

                    Button {
                        saveReminder()
                    } label: {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: schedule.isEnabled ? "bell.badge.fill" : "bell.slash.fill")
                            }

                            Text("保存提醒")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .trainingButtonStyle(prominent: true, tint: theme.primary)
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.7 : 1)
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle("训练提醒")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
        }
        .task {
            authorizationState = await TrainingReminderService.authorizationState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                authorizationState = await TrainingReminderService.authorizationState()
            }
        }
        .alert(item: $alert) { alert in
            switch alert {
            case .chooseDay:
                Alert(
                    title: Text("请至少选择一个训练日"),
                    dismissButton: .default(Text("好的"))
                )
            case .permissionDenied:
                Alert(
                    title: Text("通知权限未开启"),
                    message: Text("需要先在系统设置中允许通知，才能按时提醒你。"),
                    primaryButton: .default(Text("打开系统设置")) {
                        openSystemSettings()
                    },
                    secondaryButton: .cancel(Text("稍后"))
                )
            case .saveFailed:
                Alert(
                    title: Text("无法保存提醒"),
                    message: Text("请稍后再试。"),
                    dismissButton: .default(Text("好的"))
                )
            }
        }
    }

    private var reminderHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.primary.opacity(0.16))

                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primary)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text("按计划出发")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                Text("到点提醒你准备开始，不需要保持 App 打开。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 24, tint: theme.primary)
    }

    private var reminderToggleCard: some View {
        Toggle(isOn: $schedule.isEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("开启提醒")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)

                Text(scheduleSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(schedule.isEnabled ? theme.primary : .secondary)
            }
        }
        .tint(theme.primary)
        .padding(18)
        .liquidGlassCard(cornerRadius: 22, tint: schedule.isEnabled ? theme.primary : nil, interactive: true)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label("训练日", systemImage: "calendar")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(TrainingReminderWeekday.displayOrder) { weekday in
                        weekdayButton(weekday)
                    }
                }
            }

            Divider()
                .overlay(.white.opacity(0.10))

            HStack {
                Label("提醒时间", systemImage: "clock.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)

                Spacer()

                DatePicker(
                    "提醒时间",
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .tint(theme.primary)
            }

            Text("每周在选定日期提醒你；下一练仍按当前训练计划的顺序推进。")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 22)
        .disabled(!schedule.isEnabled)
        .opacity(schedule.isEnabled ? 1 : 0.5)
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permissionIcon)
                .font(.title3.weight(.bold))
                .foregroundStyle(permissionTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(permissionTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)

                Text(permissionMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if authorizationState == .denied {
                    Button("打开系统设置") {
                        openSystemSettings()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primary)
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 22)
    }

    private func weekdayButton(_ weekday: TrainingReminderWeekday) -> some View {
        let isSelected = schedule.weekdays.contains(weekday.rawValue)

        return Button {
            if isSelected {
                schedule.weekdays.remove(weekday.rawValue)
            } else {
                schedule.weekdays.insert(weekday.rawValue)
            }
            HapticsService.switchExercise()
        } label: {
            Text(weekday.shortTitle)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .background(
                    isSelected ? theme.primary : .white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? theme.primary.opacity(0.3) : .white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var reminderTime: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = schedule.hour
            components.minute = schedule.minute
            return Calendar.current.date(from: components) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            schedule.hour = components.hour ?? schedule.hour
            schedule.minute = components.minute ?? schedule.minute
        }
    }

    private var scheduleSummary: String {
        guard schedule.isEnabled else {
            return L10n.string("当前已关闭")
        }

        let selectedDays = TrainingReminderWeekday.displayOrder
            .filter { schedule.weekdays.contains($0.rawValue) }
            .map(\.shortTitle)
            .joined(separator: L10n.string("、"))
        return "\(selectedDays) · \(formattedTime)"
    }

    private var formattedTime: String {
        var components = DateComponents()
        components.hour = schedule.hour
        components.minute = schedule.minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var permissionIcon: String {
        switch authorizationState {
        case .notDetermined: "bell.badge"
        case .allowed: "checkmark.circle.fill"
        case .denied: "exclamationmark.triangle.fill"
        }
    }

    private var permissionTint: Color {
        switch authorizationState {
        case .notDetermined: theme.primary
        case .allowed: theme.success
        case .denied: .orange
        }
    }

    private var permissionTitle: String {
        switch authorizationState {
        case .notDetermined: L10n.string("还未申请通知权限")
        case .allowed: L10n.string("通知权限已开启")
        case .denied: L10n.string("通知权限已关闭")
        }
    }

    private var permissionMessage: String {
        switch authorizationState {
        case .notDetermined: L10n.string("保存提醒时，系统会询问是否允许通知。")
        case .allowed: L10n.string("到点后力迹可以正常提醒你。")
        case .denied: L10n.string("请在系统设置中允许力迹发送通知。")
        }
    }

    private func saveReminder() {
        guard !schedule.isEnabled || !schedule.weekdays.isEmpty else {
            alert = .chooseDay
            return
        }

        isSaving = true
        Task {
            do {
                let result = try await TrainingReminderService.save(schedule)
                authorizationState = await TrainingReminderService.authorizationState()
                isSaving = false

                switch result {
                case .scheduled, .disabled:
                    HapticsService.closePanel()
                    dismiss()
                case .denied:
                    schedule.isEnabled = false
                    alert = .permissionDenied
                }
            } catch {
                isSaving = false
                alert = .saveFailed
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

private enum TrainingReminderAlert: Int, Identifiable {
    case chooseDay
    case permissionDenied
    case saveFailed

    var id: Int { rawValue }
}
