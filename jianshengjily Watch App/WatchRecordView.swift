import SwiftUI

struct WatchRecordView: View {
    @EnvironmentObject private var connectivity: WatchRecordService

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("力迹")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(connectivity.isReachable ? "已连接 iPhone" : "离线也会稍后同步")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(connectivity.isReachable ? .green : .secondary)
                }

                Button {
                    connectivity.recordSet()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .heavy))
                        Text("记录一组")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity, minHeight: 104)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if let lastSentAt = connectivity.lastSentAt {
                    Text("已发送 \(lastSentAt, style: .time)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}
