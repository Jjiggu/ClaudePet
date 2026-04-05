//
//  MenuBarView.swift
//  ClaudePet
//
//  Status bar label: animated pixel-art pet + session %
//  Animation speed scales with session usage (RunCat style).

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var petManager: PetManager

    var body: some View {
        HStack(spacing: 4) {
            if petManager.errorMessage != nil {
                Text("⚠️").font(.system(size: 13))
            } else {
                let mode = petManager.menuBarDisplayMode
                if mode == .imageOnly || mode == .both {
                    let name = "pet_stage1_\(petManager.menuBarFrame)"
                    if NSImage(named: name) != nil {
                        Image(name)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 22, height: 22)
                    } else {
                        Text(petManager.emoji).font(.system(size: 14))
                    }
                }
                if (mode == .usageOnly || mode == .both), let session = petManager.fiveHour {
                    Text("\(Int(session.utilization))%")
                        .font(.system(size: 11))
                }
            }
        }
    }
}
