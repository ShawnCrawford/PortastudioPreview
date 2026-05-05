//
//  PanMapper.swift
//  PortastudioPreview
//

import Foundation

enum PanMapper {
    static func displayValue(for rawByte: UInt8) -> String {
        "raw \(HexFormatter.byte(rawByte))"
    }
}
