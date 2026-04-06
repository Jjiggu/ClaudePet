//
//  AuthLoader.swift
//  ClaudePet
//
//  Token loading priority:
//  1. ~/.claude/.credentials.json
//  2. macOS Keychain

import Foundation
import Security

enum AuthSource {
    case credentialsFile
    case keychain

    var displayName: String {
        switch self {
        case .credentialsFile: "Credentials File"
        case .keychain: "Keychain"
        }
    }
}

struct AuthState {
    let token: String?
    let source: AuthSource?

    static let missing = AuthState(token: nil, source: nil)
}

struct AuthLoader {
    static func loadAuthState() -> AuthState {
        if let data = loadCredentialsData(),
           let token = token(fromCredentialsData: data) {
            return AuthState(token: token, source: .credentialsFile)
        }

        if let data = loadKeychainData(),
           let token = token(fromKeychainPayload: data) {
            return AuthState(token: token, source: .keychain)
        }

        return .missing
    }

    static func loadOAuthToken() -> String? {
        loadAuthState().token
    }

    /// Returns the source of the current token, or nil if not found.
    static func authSource() -> String? {
        loadAuthState().source?.displayName
    }

    // MARK: - Credentials File

    private static func loadCredentialsData() -> Data? {
        let url = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")

        return try? Data(contentsOf: url)
    }

    static func token(fromCredentialsData data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Typical shape: { "claudeAiOauth": { "accessToken": "..." } }
        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            return token
        }
        // Fallback flat key
        return json["accessToken"] as? String
    }

    // MARK: - Keychain

    private static func loadKeychainData() -> Data? {
        // Keychain service name used by Claude Code (verified 2026-04-02)
        // JSON shape: { "claudeAiOauth": { "accessToken": "sk-ant-oat01-..." } }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return data
    }

    static func token(fromKeychainPayload data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }
}
