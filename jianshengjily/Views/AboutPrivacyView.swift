import SwiftUI

enum LijiPublicLinks {
    static let privacyPolicyURL = URL(
        string: "https://liji-public-site-1449065823.cos.ap-guangzhou.myqcloud.com/privacy.html"
    )!
}

struct AboutPrivacyView: View {
    @Environment(\.trainingTheme) private var theme

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return L10n.format("about.version_build", version, build)
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        PowerTraceMarkView(size: 76, progress: 0.78)

                        Text("力迹")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("训练时只看下一步")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("渐成造物出品")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text(versionText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.primary)
                    }

                    privacyCard(
                        title: "你的数据留在设备里",
                        systemImage: "iphone.gen3.lock",
                        text: "动作、重量、次数、训练时长、休息时间、备注、模板和计划都保存在这台设备的本地数据库中。本版本不创建账号，也不会把训练记录上传到服务器。"
                    )

                    privacyCard(
                        title: "不跟踪，也不做广告分析",
                        systemImage: "eye.slash.fill",
                        text: "本版本没有广告、第三方统计 SDK 或用户追踪，也不会读取或写入 Apple 健康数据。主题与训练提醒偏好只用于在本机记住你的设置。"
                    )

                    privacyCard(
                        title: "所有功能免费开放",
                        systemImage: "checkmark.seal.fill",
                        text: "此版本不提供新的应用内订阅或付费解锁。如果你曾订阅 Pro，请在 Apple ID 的订阅设置中查看是否仍会续费。"
                    )

                    privacyCard(
                        title: "分享由你主动决定",
                        systemImage: "square.and.arrow.up",
                        text: "只有当你主动点击分享训练或 PR 海报时，系统分享面板才会处理该图片。力迹不会在后台自动分享或上传内容。"
                    )

                    privacyCard(
                        title: "本地删除与系统备份",
                        systemImage: "externaldrive.badge.xmark",
                        text: "力迹不提供账号或跨设备云同步。从设备删除 App 会删除当前本地训练记录；如果你启用了 iCloud 或电脑整机备份，iOS 可能把 App 数据包含在系统备份中，备份和恢复由 Apple 与你的系统设置管理。"
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("需要帮助")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)

                        Link(destination: LijiPublicLinks.privacyPolicyURL) {
                            Label("完整隐私政策", systemImage: "doc.text.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primary)
                        }

                        Link(destination: URL(string: "mailto:gradformstudio@outlook.com")!) {
                            Label("gradformstudio@outlook.com", systemImage: "envelope.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primary)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassCard(cornerRadius: 22)
                }
                .padding(20)
            }
        }
        .navigationTitle("关于与隐私")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func privacyCard(title: String, systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string(title), systemImage: systemImage)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            Text(L10n.string(text))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 22, tint: theme.primary)
    }
}
