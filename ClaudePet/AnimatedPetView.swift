//
//  AnimatedPetView.swift
//  ClaudePet
//
//  Pixel-art sprite animation view used in both the menu bar (small) and pet tab (large).
//  Falls back to an emoji if the asset images have not yet been added to Assets.xcassets.
//
//  Asset naming convention:
//    {prefix}_{frameIndex}   (e.g. pet_stage1_0, pet_stage1_large_0 …)
//  To change frame counts per prefix, update `frameCounts` below.

import SwiftUI
import AppKit

struct AnimatedPetView: View {
    let stage: Int              // 1–5 growth stage
    let size: CGFloat           // display point size (width = height)
    let fps: Double             // animation speed
    let fallbackEmoji: String
    var assetPrefix: String? = nil  // nil = default "pet_stage{N}", set to override
    var useTemplateRendering: Bool = false

    /// Frame counts keyed by asset prefix. Default stages use index-based lookup.
    private static let defaultFrameCounts = [0, 8, 4, 4, 4, 4]
    private static let largeStageCounts: [String: Int] = [
        "pet_stage1_large": 9
    ]
    @State private var frameIndex = 0

    private var resolvedPrefix: String? {
        if let prefix = assetPrefix {
            // custom prefix: check frame 0 exists
            return NSImage(named: "\(prefix)_0") != nil ? prefix : nil
        }
        // default: walk down from stage to find highest with assets
        for s in stride(from: stage, through: 1, by: -1) {
            if NSImage(named: "pet_stage\(s)_0") != nil { return "pet_stage\(s)" }
        }
        return nil
    }

    private func frameCount(for prefix: String) -> Int {
        if let n = Self.largeStageCounts[prefix] { return n }
        let digits = prefix.reversed().prefix { $0.isNumber }.reversed()
        if let n = Int(String(digits)) {
            return Self.defaultFrameCounts[min(n, Self.defaultFrameCounts.count - 1)]
        }
        return 0
    }

    var body: some View {
        if let prefix = resolvedPrefix {
            let count = frameCount(for: prefix)
            let frameImage = Image("\(prefix)_\(frameIndex)")
                .renderingMode(useTemplateRendering ? .template : .original)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)

            if useTemplateRendering {
                frameImage
                    .foregroundStyle(.primary)
                    .task(id: "\(prefix)-\(fps)-\(count)") {
                        guard count > 0 else {
                            frameIndex = 0
                            return
                        }
                        frameIndex = 0
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(1.0 / fps))
                            frameIndex = (frameIndex + 1) % count
                        }
                    }
            } else {
                frameImage
                    .task(id: "\(prefix)-\(fps)-\(count)") {
                        guard count > 0 else {
                            frameIndex = 0
                            return
                        }
                        frameIndex = 0
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(1.0 / fps))
                            frameIndex = (frameIndex + 1) % count
                        }
                    }
            }
        } else {
            Text(fallbackEmoji)
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)
        }
    }
}
