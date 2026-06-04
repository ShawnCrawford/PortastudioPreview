//
//  PortastudioPreviewApp.swift
//  PortastudioPreview
//
//  Created by Shawn Crawford on 5/5/26.
//

import SwiftUI
import SwiftData

@main
struct PortastudioPreviewApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            LibrarySourceRecord.self,
            LibrarySongRecord.self,
            TrackAnnotationRecord.self,
            MixOverrideRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .commands {
            ProjectCommands()
        }
    }
}

struct ProjectCommands: Commands {
    @FocusedValue(\.openProjectAction) private var openProjectAction
    @FocusedValue(\.addSourceAction) private var addSourceAction
    @FocusedValue(\.mixerCommandActions) private var mixerCommandActions

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

        CommandMenu("Mixer") {
            Button("Play Preview") {
                mixerCommandActions?.play()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(mixerCommandActions?.canPlay != true)

            Button("Stop Preview") {
                mixerCommandActions?.stop()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(mixerCommandActions?.canStop != true)

            Divider()

            Button("Previous Channel") {
                mixerCommandActions?.selectPreviousChannel()
            }
            .disabled(mixerCommandActions?.canSelectPreviousChannel != true)

            Button("Next Channel") {
                mixerCommandActions?.selectNextChannel()
            }
            .disabled(mixerCommandActions?.canSelectNextChannel != true)

            Divider()

            Button("Mute Selected Channel") {
                mixerCommandActions?.toggleMuteSelected()
            }
            .keyboardShortcut("m", modifiers: [.command])
            .disabled(mixerCommandActions?.hasSelectedChannel != true)

            Button("Solo Selected Channel") {
                mixerCommandActions?.toggleSoloSelected()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(mixerCommandActions?.hasSelectedChannel != true)

            Divider()

            Button("Reset Selected Channel") {
                mixerCommandActions?.resetSelected()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(mixerCommandActions?.hasSelectedChannel != true)

            Button("Reset All Mix") {
                mixerCommandActions?.resetAll()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(mixerCommandActions == nil)
        }
    }
}

struct MixerCommandActions {
    let canPlay: Bool
    let canStop: Bool
    let hasSelectedChannel: Bool
    let canSelectPreviousChannel: Bool
    let canSelectNextChannel: Bool
    let play: () -> Void
    let stop: () -> Void
    let selectPreviousChannel: () -> Void
    let selectNextChannel: () -> Void
    let toggleMuteSelected: () -> Void
    let toggleSoloSelected: () -> Void
    let resetSelected: () -> Void
    let resetAll: () -> Void
}

private struct OpenProjectActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct AddSourceActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct MixerCommandActionsKey: FocusedValueKey {
    typealias Value = MixerCommandActions
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

    var mixerCommandActions: MixerCommandActions? {
        get { self[MixerCommandActionsKey.self] }
        set { self[MixerCommandActionsKey.self] = newValue }
    }
}
