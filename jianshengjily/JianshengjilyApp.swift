import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct JianshengjilyApp: App {
    @UIApplicationDelegateAdaptor(LijiAppDelegate.self) private var appDelegate
    @AppStorage("trainingTheme") private var selectedThemeRawValue = TrainingTheme.defaultTheme.rawValue

    private let sharedModelContainer: ModelContainer?

    init() {
        UIScrollView.appearance().keyboardDismissMode = .interactive

        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            SetLog.self,
            WorkoutTemplate.self,
            TrainingPlan.self,
            TrainingPlanDay.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            sharedModelContainer = nil
            #if DEBUG
            print("Could not create SwiftData container: \(error)")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                HomeView()
                    .environment(\.trainingTheme, selectedTheme)
                    .modelContainer(sharedModelContainer)
                    .onAppear {
                        KeyboardDismissCoordinator.shared.installIfNeeded()
                        AppIconService.apply(theme: selectedTheme)
                        #if DEBUG
                        if ExerciseGlyphCatalogExporter.shouldExport {
                            ExerciseGlyphCatalogExporter.export()
                        }
                        #endif
                    }
                    .onChange(of: selectedThemeRawValue) { _, _ in
                        AppIconService.apply(theme: selectedTheme)
                    }
            } else {
                DataStoreUnavailableView()
                    .environment(\.trainingTheme, selectedTheme)
                }
        }
    }

    private var selectedTheme: TrainingTheme {
        TrainingTheme(rawValue: selectedThemeRawValue) ?? .defaultTheme
    }
}

private final class LijiAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissCoordinator()

    private weak var installedWindow: UIWindow?
    private lazy var downwardPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

    func installIfNeeded() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        guard let window, installedWindow !== window else {
            return
        }

        installedWindow?.removeGestureRecognizer(downwardPan)
        installedWindow = window
        downwardPan.delegate = self
        downwardPan.cancelsTouchesInView = false
        downwardPan.maximumNumberOfTouches = 1
        window.addGestureRecognizer(downwardPan)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        installedWindow?.containsActiveTextInput() == true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: installedWindow)
        guard gestureRecognizer.state == .changed,
              translation.y > 12,
              abs(translation.y) > abs(translation.x) else {
            return
        }

        installedWindow?.endEditing(true)
    }

    deinit {
        installedWindow?.removeGestureRecognizer(downwardPan)
    }
}

extension UIView {
    fileprivate func containsActiveTextInput() -> Bool {
        if isFirstResponder, self is UITextField || self is UITextView {
            return true
        }

        return subviews.contains(where: { $0.containsActiveTextInput() })
    }
}

private struct DataStoreUnavailableView: View {
    var body: some View {
        ZStack {
            TrainingGlassBackground()

            VStack(spacing: 18) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("暂时无法打开训练数据")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)

                Text("请先重新启动 App。不要删除 App，以免本地训练记录一起被清除；如果仍然无法打开，请通过 App Store 的“App 支持”联系我们。")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .liquidGlassCard(cornerRadius: 28)
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

private enum AppIconService {
    @MainActor
    static func apply(theme: TrainingTheme) {
        guard UIApplication.shared.supportsAlternateIcons else {
            return
        }

        let iconName = theme.alternateAppIconName
        guard UIApplication.shared.alternateIconName != iconName else {
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            #if DEBUG
            if let error {
                print("Failed to update app icon: \(error)")
            }
            #endif
        }
    }
}
