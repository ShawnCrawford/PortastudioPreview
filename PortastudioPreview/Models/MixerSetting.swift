//
//  MixerSetting.swift
//  PortastudioPreview
//

import Foundation

struct MixerSetting: Hashable {
    let name: String
    let primaryOffset: Int
    let primaryByte: UInt8
    let mirrorOffset: Int?
    let mirrorByte: UInt8?
    let evidenceLevel: EvidenceLevel

    var hasMirrorMismatch: Bool {
        guard let mirrorByte else {
            return false
        }

        return primaryByte != mirrorByte
    }

    var rawBytesDescription: String {
        let primary = "\(HexFormatter.offset(primaryOffset))=\(HexFormatter.byte(primaryByte))"

        guard let mirrorOffset, let mirrorByte else {
            return primary
        }

        return "\(primary), \(HexFormatter.offset(mirrorOffset))=\(HexFormatter.byte(mirrorByte))"
    }
}
