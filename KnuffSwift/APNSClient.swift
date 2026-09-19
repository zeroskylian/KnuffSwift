import Foundation
import Security

struct APNSResponse: Sendable {
    let statusCode: Int
    let apnsID: String?
    let reason: String?

    var isSuccess: Bool { statusCode == 200 }
}

enum APNSError: LocalizedError {
    case invalidToken
    case invalidPayload
    case missingIdentity
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidToken: "Enter a valid hexadecimal device token."
        case .invalidPayload: "The payload must be a valid JSON object."
        case .missingIdentity: "Choose an APNs certificate first."
        case .invalidResponse: "APNs returned an invalid response."
        }
    }
}

final class APNSClient: NSObject, URLSessionDelegate {
    private let identity: SecIdentity
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    init(identity: SecIdentity) {
        self.identity = identity
        super.init()
    }

    func send(
        payload: String,
        token rawToken: String,
        topic: String,
        priority: APNSPriority,
        collapseID: String,
        pushType: APNSPushType,
        environment: APNSEnvironment
    ) async throws -> APNSResponse {
        let token = rawToken.filter(\.isHexDigit).lowercased()
        guard !token.isEmpty, token.count.isMultiple(of: 2) else { throw APNSError.invalidToken }
        guard let body = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: body), json is [String: Any] else {
            throw APNSError.invalidPayload
        }

        let host = environment == .development ? "api.sandbox.push.apple.com" : "api.push.apple.com"
        guard let url = URL(string: "https://\(host)/3/device/\(token)") else { throw APNSError.invalidToken }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(String(priority.rawValue), forHTTPHeaderField: "apns-priority")
        request.setValue(pushType.rawValue, forHTTPHeaderField: "apns-push-type")
        if !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(topic, forHTTPHeaderField: "apns-topic")
        }
        if !collapseID.isEmpty { request.setValue(collapseID, forHTTPHeaderField: "apns-collapse-id") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APNSError.invalidResponse }
        let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
        return APNSResponse(statusCode: http.statusCode, apnsID: http.value(forHTTPHeaderField: "apns-id"), reason: reason)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(identity: identity, certificates: [certificate], persistence: .forSession))
    }
}
