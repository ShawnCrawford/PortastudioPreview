//
//  ProjectValidationIssue.swift
//  PortastudioPreview
//

import Foundation

struct ProjectValidationIssue: Identifiable, Equatable {
    enum Severity: String {
        case warning = "Warning"
        case error = "Error"
    }

    let id: String
    let severity: Severity
    let message: String
}
