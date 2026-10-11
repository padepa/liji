import Foundation
import WatchConnectivity

extension Notification.Name {
    static let watchRecordSetRequested = Notification.Name("watchRecordSetRequested")
}

final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    private func handle(_ message: [String: Any]) {
        guard message["action"] as? String == "recordSet" else {
            return
        }

        let exerciseId = (message["exerciseId"] as? String).flatMap(UUID.init(uuidString:))
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .watchRecordSetRequested,
                object: nil,
                userInfo: ["exerciseId": exerciseId as Any]
            )
        }
    }
}
