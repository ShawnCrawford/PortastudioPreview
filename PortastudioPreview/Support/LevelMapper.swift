//
//  LevelMapper.swift
//  PortastudioPreview
//

import Foundation

enum LevelMapper {
    static func displayValue(for rawByte: UInt8) -> String {
        "raw \(HexFormatter.byte(rawByte))"
    }
}
