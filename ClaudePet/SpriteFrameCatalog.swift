//
//  SpriteFrameCatalog.swift
//  ClaudePet
//
//  Centralizes frame discovery so animation views prefer numbered sprite
//  sequences and only fall back to single-frame assets when needed.
//

import AppKit

enum SpriteFrameCatalog {
    typealias ImageLookup = (String) -> Bool

    static func frames(for prefix: String, imageExists: ImageLookup = assetExists) -> [String] {
        let numberedFrames = numberedFrames(for: prefix, imageExists: imageExists)
        if !numberedFrames.isEmpty {
            return numberedFrames
        }

        return imageExists(prefix) ? [prefix] : []
    }

    static func firstAvailableFrames(
        prefixes: [String],
        imageExists: ImageLookup = assetExists
    ) -> [String]? {
        for prefix in prefixes {
            let frames = frames(for: prefix, imageExists: imageExists)
            if !frames.isEmpty {
                return frames
            }
        }

        return nil
    }

    private static func numberedFrames(
        for prefix: String,
        imageExists: ImageLookup
    ) -> [String] {
        var frames: [String] = []
        var index = 0

        while imageExists("\(prefix)_\(index)") {
            frames.append("\(prefix)_\(index)")
            index += 1
        }

        return frames
    }

    private static func assetExists(named name: String) -> Bool {
        NSImage(named: name) != nil
    }
}
