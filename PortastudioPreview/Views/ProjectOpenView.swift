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
                    Button("Add Audio Source...", systemImage: "externaldrive.badge.plus", action: addSourceAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-view-add-source")
                    .accessibilityLabel("Add audio source")
                    .accessibilityHint("Browse songs from an SD card or backup folder")
                    Text("Browse songs from an SD card or backup folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Button("Open Individual Song...", systemImage: "folder", action: openAction)
                    .accessibilityIdentifier("open-view-open-song")
                    .accessibilityLabel("Open Individual Song")
                    .accessibilityHint("Open a single song folder")
                    Text("Open one song folder directly.")
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
