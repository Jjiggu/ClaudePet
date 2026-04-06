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

    @State private var frameIndex = 0

    private var resolvedFrames: [String]? {
        if let prefix = assetPrefix {
            let frames = availableFrames(for: prefix)
            return frames.isEmpty ? nil : frames
        }

        for s in stride(from: stage, through: 1, by: -1) {
            let frames = availableFrames(for: "pet_stage\(s)")
            if !frames.isEmpty { return frames }
        }

        return nil
    }

    private func availableFrames(for prefix: String) -> [String] {
        if NSImage(named: prefix) != nil {
            return [prefix]
        }

        var frames: [String] = []
        var index = 0

        while NSImage(named: "\(prefix)_\(index)") != nil {
            frames.append("\(prefix)_\(index)")
            index += 1
        }

        return frames
    }

    var body: some View {
        if let frames = resolvedFrames {
            let count = frames.count
            let currentFrame = frames[min(frameIndex, count - 1)]

            Group {
                if useTemplateRendering {
                    frameImage(named: currentFrame)
                        .foregroundStyle(.primary)
                } else {
                    frameImage(named: currentFrame)
                }
            }
            .task(id: "\(frames.first ?? "missing")-\(fps)-\(count)") {
                await runAnimation(frameCount: count)
            }
        } else {
            Text(fallbackEmoji)
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)
        }
    }

    private func frameImage(named assetName: String) -> some View {
        Image(assetName)
            .renderingMode(useTemplateRendering ? .template : .original)
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
    }

    @MainActor
    private func runAnimation(frameCount: Int) async {
        guard frameCount > 1 else {
            frameIndex = 0
            return
        }

        frameIndex = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.0 / fps))
            frameIndex = (frameIndex + 1) % frameCount
        }
    }
}
