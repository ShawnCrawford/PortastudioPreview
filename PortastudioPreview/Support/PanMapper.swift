//
//  PanMapper.swift
//  PortastudioPreview
//

import Foundation

/// Maps raw song.sys pan bytes to display strings.
///
/// Scale confirmed from SONG_0092 (Phase 7 capture, 2026-05-06):
/// T1–T8 each set to a distinct pan position; all expected offsets changed as predicted.
/// Center (0x40) confirmed as the baseline value — T3 and T7 set to center were unchanged.
///
/// Confirmed anchor points:
/// | Raw byte | Pan position |
/// |----------|--------------|
/// | 0x01     | L (hard left)|
/// | 0x3C     | L4            |
/// | 0x3E     | L2            |
/// | 0x40     | C (center)    |
/// | 0x42     | R2            |
/// | 0x44     | R4            |
/// | 0x7F     | R (hard right)|
///
/// Intermediate playback values are linearly mapped between confirmed anchors.
enum PanMapper {
    // MARK: - Confirmed anchor points (Evidence: Confirmed, SONG_0092)

    static let rawHardLeft:  UInt8 = 0x01  // L
    static let rawL4:        UInt8 = 0x3C  // L4
    static let rawL2:        UInt8 = 0x3E  // L2
    static let rawCenter:    UInt8 = 0x40  // C
    static let rawR2:        UInt8 = 0x42  // R2
    static let rawR4:        UInt8 = 0x44  // R4
    static let rawHardRight: UInt8 = 0x7F  // R

    static func displayValue(for rawByte: UInt8) -> String {
        switch rawByte {
        case rawHardLeft:  return "L"
        case rawL4:        return "L4"
        case rawL2:        return "L2"
        case rawCenter:    return "C"
        case rawR2:        return "R2"
        case rawR4:        return "R4"
        case rawHardRight: return "R"
        default:           return "raw \(HexFormatter.byte(rawByte))"
        }
    }

    static func normalizedPosition(for rawByte: UInt8) -> Double {
        let centered = (Double(rawByte) - Double(rawCenter)) / Double(0x3F)
        return min(max(centered, -1), 1)
    }

    static func rawByte(forNormalizedPosition position: Double) -> UInt8 {
        let clamped = min(max(position, -1), 1)
        let scaled = (clamped * Double(0x3F)) + Double(rawCenter)
        let rounded = UInt8(scaled.rounded())
        return min(max(rounded, rawHardLeft), rawHardRight)
    }

    static func previewDisplayValue(forNormalizedPosition position: Double) -> String {
        let clamped = min(max(position, -1), 1)

        if abs(clamped) < 0.01 {
            return "C"
        }

        if clamped <= -0.99 {
            return "L"
        }

        if clamped >= 0.99 {
            return "R"
        }

        let side = clamped < 0 ? "L" : "R"
        let step = Int((abs(clamped) * 8).rounded(.toNearestOrAwayFromZero))
        return "\(side)\(max(step, 1))"
    }
}
