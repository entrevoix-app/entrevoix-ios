import AuthenticationServices
import CryptoKit
import EntrevoixCore
import Foundation
import Network
import Security
import UIKit

enum CodexConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed
}

nonisolated enum CodexAuthenticationError: LocalizedError {
    case callbackServerUnavailable
    case callbackTimedOut
    case callbackRejected
    case browserCouldNotStart
    case tokenExchangeFailed(Int)
    case refreshFailed(Int)
    case malformedTokenResponse

    var errorDescription: String? {
        switch self {
        case .callbackServerUnavailable: "The ChatGPT authorization callback could not start."
        case .callbackTimedOut: "The ChatGPT authorization timed out."
        case .callbackRejected: "The ChatGPT authorization callback was rejected."
        case .browserCouldNotStart: "The ChatGPT authorization session could not start."
        case .tokenExchangeFailed: "The ChatGPT authorization code could not be exchanged."
        case .refreshFailed: "The ChatGPT session could not be refreshed."
        case .malformedTokenResponse: "ChatGPT returned an invalid authorization response."
        }
    }
}

private nonisolated enum CodexProtocol {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let issuer = URL(string: "https://auth.openai.com")!
    static let callbackPort: NWEndpoint.Port = 1455
    static let callbackPath = "/auth/callback"
    static let appCallbackScheme = "entrevoix"
    static let keychainService = "com.d9beuD.Entrevoix"
    static let keychainAccount = "codex-oauth"
}

private nonisolated struct CodexTokenResponse: Decodable {
    let idToken: String?
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private nonisolated struct CodexOAuthTokenClient: Sendable {
    private let session: URLSession
    private let now: @Sendable () -> Date

    init(session: URLSession = .shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.session = session
        self.now = now
    }

    func authorizationURL(redirectURI: URL, challenge: String, state: String) -> URL {
        var components = URLComponents(
            url: CodexProtocol.issuer.appending(path: "oauth/authorize"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: CodexProtocol.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: "opencode")
        ]
        return components.url!
    }

    func exchange(code: String, redirectURI: URL, verifier: String) async throws -> CodexCredentials {
        try await requestToken(
            items: [
                ("grant_type", "authorization_code"),
                ("code", code),
                ("redirect_uri", redirectURI.absoluteString),
                ("client_id", CodexProtocol.clientID),
                ("code_verifier", verifier)
            ],
            failure: CodexAuthenticationError.tokenExchangeFailed
        )
    }

    func refresh(_ credentials: CodexCredentials) async throws -> CodexCredentials {
        try await requestToken(
            items: [
                ("grant_type", "refresh_token"),
                ("refresh_token", credentials.refreshToken),
                ("client_id", CodexProtocol.clientID)
            ],
            failure: CodexAuthenticationError.refreshFailed,
            fallbackAccountID: credentials.accountID,
            fallbackResidency: credentials.computeResidency
        )
    }

    private func requestToken(
        items: [(String, String)],
        failure: (Int) -> CodexAuthenticationError,
        fallbackAccountID: String? = nil,
        fallbackResidency: String? = nil
    ) async throws -> CodexCredentials {
        var request = URLRequest(url: CodexProtocol.issuer.appending(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = items
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CodexAuthenticationError.malformedTokenResponse }
        guard (200..<300).contains(http.statusCode) else { throw failure(http.statusCode) }
        guard let token = try? JSONDecoder().decode(CodexTokenResponse.self, from: data) else {
            throw CodexAuthenticationError.malformedTokenResponse
        }
        let claims = CodexJWTClaims(token.idToken ?? token.accessToken)
        return CodexCredentials(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: now().addingTimeInterval(token.expiresIn ?? 3_600),
            accountID: claims.accountID ?? fallbackAccountID,
            computeResidency: claims.computeResidency ?? fallbackResidency
        )
    }

    private func formEncode(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

@MainActor
final class CodexBrowserAuthenticator: NSObject, CodexAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private let tokenClient: CodexOAuthTokenClient
    private var authenticationSession: ASWebAuthenticationSession?

    override init() {
        tokenClient = CodexOAuthTokenClient()
        super.init()
    }

    func connect() async throws -> CodexCredentials {
        let verifier = CodexPKCE.verifier()
        let state = CodexPKCE.randomValue()
        let callback = try CodexLoopbackCallbackServer()
        let redirectURI = callback.redirectURI
        let authorizationURL = tokenClient.authorizationURL(
            redirectURI: redirectURI,
            challenge: CodexPKCE.challenge(for: verifier),
            state: state
        )

        async let code = callback.waitForCode(expectedState: state)
        _ = try await authenticate(at: authorizationURL)
        return try await tokenClient.exchange(code: code, redirectURI: redirectURI, verifier: verifier)
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let windowScene = windowScenes.first else {
            preconditionFailure("ChatGPT authentication requires an active window scene.")
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }

    private func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: CodexProtocol.appCallbackScheme
            ) { [weak self] callbackURL, error in
                self?.authenticationSession = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? CodexAuthenticationError.callbackRejected)
                }
            }
            session.presentationContextProvider = self
            authenticationSession = session
            guard session.start() else {
                authenticationSession = nil
                continuation.resume(throwing: CodexAuthenticationError.browserCouldNotStart)
                return
            }
        }
    }
}

actor CodexCredentialVault: CodexCredentialsStoring, CodexAccessTokenProviding {
    private var cachedCredentials: CodexCredentials?
    private let tokenClient: CodexOAuthTokenClient

    init() {
        tokenClient = CodexOAuthTokenClient()
    }

    func readCodexCredentials() async throws -> CodexCredentials? {
        if let cachedCredentials { return cachedCredentials }
        guard let data = try readData() else { return nil }
        let credentials = try JSONDecoder().decode(CodexCredentials.self, from: data)
        cachedCredentials = credentials
        return credentials
    }

    func saveCodexCredentials(_ credentials: CodexCredentials?) async throws {
        cachedCredentials = credentials
        guard let credentials else {
            try deleteData()
            return
        }
        try saveData(JSONEncoder().encode(credentials))
    }

    func validCredentials() async throws -> CodexCredentials {
        guard let credentials = try await readCodexCredentials() else { throw CodexAuthenticationError.callbackRejected }
        guard credentials.isExpired else { return credentials }
        let refreshed = try await tokenClient.refresh(credentials)
        try saveData(JSONEncoder().encode(refreshed))
        cachedCredentials = refreshed
        return refreshed
    }

    private func readData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: CodexProtocol.keychainService,
            kSecAttrAccount as String: CodexProtocol.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CodexKeychainError.unexpectedStatus(status) }
        return item as? Data
    }

    private func saveData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: CodexProtocol.keychainService,
            kSecAttrAccount as String: CodexProtocol.keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw CodexKeychainError.unexpectedStatus(addStatus) }
        } else if status != errSecSuccess {
            throw CodexKeychainError.unexpectedStatus(status)
        }
    }

    private func deleteData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: CodexProtocol.keychainService,
            kSecAttrAccount as String: CodexProtocol.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CodexKeychainError.unexpectedStatus(status)
        }
    }
}

private nonisolated enum CodexKeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? { "The ChatGPT credentials could not be stored securely." }
}

private nonisolated enum CodexPKCE {
    static func verifier() -> String { randomValue(length: 64) }

    static func randomValue(length: Int = 43) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private nonisolated struct CodexJWTClaims {
    let accountID: String?
    let computeResidency: String?

    init(_ token: String) {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let data = Data(base64URLEncoded: String(parts[1])),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            accountID = nil
            computeResidency = nil
            return
        }
        let namespaced = value["https://api.openai.com/auth"] as? [String: Any]
        accountID = value["chatgpt_account_id"] as? String
            ?? namespaced?["chatgpt_account_id"] as? String
            ?? ((value["organizations"] as? [[String: Any]])?.first?["id"] as? String)
        let residency = namespaced?["chatgpt_compute_residency"] as? String
            ?? value["chatgpt_compute_residency"] as? String
        computeResidency = residency == "no_constraint" ? nil : residency
    }
}

@MainActor
private final class CodexLoopbackCallbackServer {
    private let listener: NWListener
    private var continuation: CheckedContinuation<String, any Error>?
    private var timeoutTask: Task<Void, Never>?

    init() throws {
        do {
            listener = try NWListener(using: .tcp, on: CodexProtocol.callbackPort)
        } catch {
            throw CodexAuthenticationError.callbackServerUnavailable
        }
    }

    deinit { listener.cancel() }

    var redirectURI: URL {
        URL(string: "http://localhost:\(CodexProtocol.callbackPort.rawValue)\(CodexProtocol.callbackPath)")!
    }

    func waitForCode(expectedState: String) async throws -> String {
        try Task.checkCancellation()
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
                Task { @MainActor in
                    self?.handle(data: data, connection: connection, expectedState: expectedState)
                }
            }
        }
        listener.start(queue: .main)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(300))
                    } catch {
                        return
                    }
                    self?.finish(.failure(CodexAuthenticationError.callbackTimedOut))
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    private func handle(data: Data?, connection: NWConnection, expectedState: String) {
        defer { connection.cancel() }
        guard let data,
              let request = String(data: data, encoding: .utf8),
              let target = request.split(separator: "\n").first?.split(separator: " ").dropFirst().first,
              let url = URLComponents(string: "http://localhost\(target)")
        else {
            finish(.failure(CodexAuthenticationError.callbackRejected))
            return
        }

        let items = Dictionary(uniqueKeysWithValues: (url.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        guard url.path == CodexProtocol.callbackPath,
              items["state"] == expectedState,
              let code = items["code"],
              !code.isEmpty
        else {
            finish(.failure(CodexAuthenticationError.callbackRejected))
            return
        }

        respond(connection)
        finish(.success(code))
    }

    private func respond(_ connection: NWConnection) {
        let body = """
        <html><body><p>You can return to Entrevoix.</p><script>window.location.replace('\(CodexProtocol.appCallbackScheme)://oauth');</script></body></html>
        """
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
    }

    private func finish(_ result: Result<String, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        listener.cancel()
        continuation.resume(with: result)
    }
}

private extension Data {
    nonisolated init?(base64URLEncoded value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized.append(String(repeating: "=", count: (4 - normalized.count % 4) % 4))
        self.init(base64Encoded: normalized)
    }
}
