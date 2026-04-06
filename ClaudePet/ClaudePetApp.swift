//
//  ClaudePetApp.swift
//  ClaudePet
//
//  Created by 김지훈 on 4/2/26.
//

import SwiftUI

@main
struct ClaudePetApp: App {
    @StateObject private var petManager = PetManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(petManager: petManager)
                .frame(width: 280)
                .onAppear {
                    // MenuBarExtra(.window) does not automatically become key window
                    // when another app is focused, causing the first click inside to be
                    // swallowed by the window-activation event. Force key focus on appear.
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        } label: {
            MenuBarView(petManager: petManager)
        }
        .menuBarExtraStyle(.window)
    }
}
