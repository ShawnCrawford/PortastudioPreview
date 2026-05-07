//
//  ProjectOpenView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectOpenView: View {
    let openAction: () -> Void
    let addSourceAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Button(action: addSourceAction) {
                        Label("Add SD Card or Backup...", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-view-add-source")
                    .accessibilityLabel("Add SD Card or Backup")
                    .accessibilityHint("Scan an SD card root or backup folder and browse all its songs")
                    Text("Scan a card root or backup folder and browse all its songs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Button(action: openAction) {
                        Label("Open Individual Song...", systemImage: "folder")
                    }
                    .accessibilityIdentifier("open-view-open-song")
                    .accessibilityLabel("Open Individual Song")
                    .accessibilityHint("Load a single DP-32SD song project folder")
                    Text("Load a single DP-32SD song project folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .contain)
    }
}
