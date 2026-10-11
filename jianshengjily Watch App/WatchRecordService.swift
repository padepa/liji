import Foundation
import WatchConnectivity

final class WatchRecordService: NSObject, ObservableObject {
    static let shared = WatchRecordService()

    @Published private(set) var lastSentAt: Date?
    @Published private(set) var isReachable = false

    private override init() {
        super.init()
        start()
    }

    func start() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func recordSet() {
        let payload: [String: Any] = [
            "action": "recordSet",
            "createdAt": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }

        lastSentAt = Date()
    }
}

extension WatchRecordService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
