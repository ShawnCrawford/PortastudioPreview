//
//  PortastudioPreviewApp.swift
//  PortastudioPreview
//
//  Created by Shawn Crawford on 5/5/26.
//

import SwiftUI

@main
struct PortastudioPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            ProjectCommands()
        }
    }
}

struct ProjectCommands: Commands {
    @FocusedValue(\.openProjectAction) private var openProjectAction

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Project Folder...") {
                openProjectAction?()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(openProjectAction == nil)
        }
    }
}

private struct OpenProjectActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openProjectAction: (() -> Void)? {
        get { self[OpenProjectActionKey.self] }
        set { self[OpenProjectActionKey.self] = newValue }
    }
}
