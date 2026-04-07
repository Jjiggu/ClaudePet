//
//  UsageSnapshotCache.swift
//  ClaudePet
//
//  Stores only the last successful usage snapshot so the UI can show
//  last-known-good data when the usage API is temporarily unavailable.
//

import Foundation

struct CachedUsageSnapshot: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let fetchedAt: Date
    let usage: OAuthUsageResponse
    let planName: String?

    init(
        fetchedAt: Date,
        usage: OAuthUsageResponse,
        planName: String?,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.fetchedAt = fetchedAt
        self.usage = usage
        self.planName = planName
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
    }
}

struct UsageSnapshotCache {
    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL = Self.defaultFileURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func load() -> CachedUsageSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try Self.decoder.decode(CachedUsageSnapshot.self, from: data)
            return snapshot.isCurrentSchema ? snapshot : nil
        } catch {
            print("[ClaudePet] Failed to load usage cache: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ snapshot: CachedUsageSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    func remove() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("[ClaudePet] Failed to remove usage cache: \(error.localizedDescription)")
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport
                .appendingPathComponent("ClaudePet", isDirectory: true)
                .appendingPathComponent("usage-cache.json")
        }

        return fileManager.temporaryDirectory
            .appendingPathComponent("ClaudePet", isDirectory: true)
            .appendingPathComponent("usage-cache.json")
    }

    private nonisolated(unsafe) static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private nonisolated(unsafe) static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
