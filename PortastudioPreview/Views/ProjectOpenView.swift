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

            Text("Open an individual DP-32SD song folder")
                .font(.title3)

            Button(action: openAction) {
                Label("Open Individual Song...", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
