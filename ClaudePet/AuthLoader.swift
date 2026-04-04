//
//  AuthLoader.swift
//  ClaudePet
//
//  Token loading priority:
//  1. ~/.claude/.credentials.json
//  2. macOS Keychain

import Foundation
import Security

struct AuthLoader {
    static func loadOAuthToken() -> String? {
        if let token = loadFromCredentialsFile() { return token }
        return loadFromKeychain()
    }

    /// Returns the source of the current token, or nil if not found.
    static func authSource() -> String? {
        if loadFromCredentialsFile() != nil { return "Credentials File" }
        if loadFromKeychain() != nil { return "Keychain" }
        return nil
    }

    // MARK: - Credentials File

    private static func loadFromCredentialsFile() -> String? {
        let url = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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

    private static func loadFromKeychain() -> String? {
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
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }
}
