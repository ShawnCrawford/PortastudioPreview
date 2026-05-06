//
//  LevelMapper.swift
//  PortastudioPreview
//

import Foundation

/// Maps raw song.sys level bytes to display strings.
///
/// Scale confirmed from SONG_0092 (Phase 7 capture, 2026-05-06):
/// Eight tracks each set to a distinct fader position; every expected low-bank and mirror-bank
/// offset changed exactly as predicted by the stride-0x14 formula.
///
/// Confirmed anchor points:
/// | Raw byte | Fader position |
/// |----------|---------------|
/// | 0x00     | −∞ (minimum)  |
/// | 0x28     | −20 dB        |
/// | 0x3E     | −10 dB        |
/// | 0x4E     | ≈ −6.4 dB     |
/// | 0x5C     | ≈ −3 dB       |
/// | 0x6A     | 0 dB (unity)  |
/// | 0x7F     | +6 dB (max)   |
///
/// Note: the device fader maximum is +6 dB, not +10 dB.
/// The true continuous dB mapping between anchors is unconfirmed; interpolation is Hypothesis.
enum LevelMapper {
    // MARK: - Confirmed anchor points (Evidence: Confirmed, SONG_0092)

    static let rawMin:   UInt8 = 0x00  // −∞
    static let rawM20dB: UInt8 = 0x28  // −20 dB
    static let rawM10dB: UInt8 = 0x3E  // −10 dB
    static let rawM6dB:  UInt8 = 0x4E  // ≈ −6.4 dB (device fader sensitivity limit)
    static let rawM3dB:  UInt8 = 0x5C  // ≈ −3 dB
    static let rawUnity: UInt8 = 0x6A  // 0 dB
    static let rawMax:   UInt8 = 0x7F  // +6 dB

    static func displayValue(for rawByte: UInt8) -> String {
        switch rawByte {
        case rawMin:   return "-∞"
        case rawM20dB: return "-20 dB"
        case rawM10dB: return "-10 dB"
        case rawM6dB:  return "≈-6.4 dB"
        case rawM3dB:  return "≈-3 dB"
        case rawUnity: return "0 dB"
        case rawMax:   return "+6 dB"
        default:       return "raw \(HexFormatter.byte(rawByte))"
        }
    }
}
