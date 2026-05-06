//
//  ProjectValidationIssue.swift
//  PortastudioPreview
//

import Foundation

struct ProjectValidationIssue: Identifiable, Equatable, Sendable {
    enum Severity: String, Sendable {
        case warning = "Warning"
        case error = "Error"
    }

    let id: String
    let severity: Severity
    let message: String
}
