//
//  ProjectOpenView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectOpenView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Open a DP-32SD project folder")
                .font(.title3)

            Button(action: openAction) {
                Label("Open Project Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
