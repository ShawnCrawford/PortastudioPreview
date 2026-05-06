//
//  EvidenceLevel.swift
//  PortastudioPreview
//

import Foundation

enum EvidenceLevel: String, CaseIterable, Identifiable, Sendable {
    case observed = "Observed"
    case correlated = "Correlated"
    case confirmed = "Confirmed"
    case hypothesis = "Hypothesis"
    case rejected = "Rejected"

    var id: String { rawValue }
}
