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
    @FocusedValue(\.addSourceAction) private var addSourceAction

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Individual Song...") {
                openProjectAction?()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(openProjectAction == nil)

            Button("Add SD Card or Backup...") {
                addSourceAction?()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(addSourceAction == nil)
        }
    }
}

private struct OpenProjectActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct AddSourceActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openProjectAction: (() -> Void)? {
        get { self[OpenProjectActionKey.self] }
        set { self[OpenProjectActionKey.self] = newValue }
    }

    var addSourceAction: (() -> Void)? {
        get { self[AddSourceActionKey.self] }
        set { self[AddSourceActionKey.self] = newValue }
    }
}
