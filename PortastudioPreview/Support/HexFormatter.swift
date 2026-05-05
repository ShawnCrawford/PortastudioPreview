//
//  HexFormatter.swift
//  PortastudioPreview
//

import Foundation

enum HexFormatter {
    static func offset(_ value: Int) -> String {
        let width = value > 0xFFFF ? 8 : 4
        return String(format: "0x%0\(width)X", value)
    }

    static func byte(_ value: UInt8) -> String {
        String(format: "0x%02X", value)
    }
}
