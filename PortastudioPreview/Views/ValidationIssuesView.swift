//
//  ValidationIssuesView.swift
//  PortastudioPreview
//

import SwiftUI

struct ValidationIssuesView: View {
    let issues: [ProjectValidationIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Validation")
                    .font(.headline)

                Spacer()

                Text(issues.isEmpty ? "No issues" : "\(issues.count) issues")
                    .foregroundStyle(.secondary)
            }

            if issues.isEmpty {
                Text("Required system files were found and readable.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(issues) { issue in
                    Label {
                        Text(issue.message)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                            .foregroundStyle(issue.severity == .error ? .red : .yellow)
                    }
                }
            }
        }
        .padding()
    }
}
