//
//  ValidationIssuesView.swift
//  PortastudioPreview
//

import SwiftUI

struct ValidationIssuesView: View {
    let issues: [ProjectValidationIssue]

    var body: some View {
        if issues.isEmpty {
            Text("Required system files were found and readable.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues) { issue in
                    Label {
                        Text(issue.message)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                }
            }
        }
    }
}
