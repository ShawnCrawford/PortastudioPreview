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

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Button(action: addSourceAction) {
                        Label("Add SD Card or Backup...", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Text("Scan a card root or backup folder and browse all its songs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Button(action: openAction) {
                        Label("Open Individual Song...", systemImage: "folder")
                    }
                    Text("Load a single DP-32SD song project folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
