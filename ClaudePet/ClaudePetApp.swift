//
//  ClaudePetApp.swift
//  ClaudePet
//

import SwiftUI

@main
struct ClaudePetApp: App {
    @StateObject private var petManager = PetManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(petManager: petManager)
                .frame(width: 340)
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
