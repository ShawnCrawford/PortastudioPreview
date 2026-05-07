//
//  SampleTimeFormatterTests.swift
//  PortastudioPreviewTests
//

import Testing
@testable import PortastudioPreview

struct SampleTimeFormatterTests {
    @Test func displaysZeroAndNegativeAsZero() {
        #expect(SampleTimeFormatter.displayString(samples: 0) == "0s")
        #expect(SampleTimeFormatter.displayString(samples: -48_000) == "0s")
    }

    @Test func displaysWholeSeconds() {
        #expect(SampleTimeFormatter.displayString(samples: 48_000) == "1.0s")
        #expect(SampleTimeFormatter.displayString(samples: 96_000) == "2.0s")
    }

    @Test func displaysFractionalSeconds() {
        #expect(SampleTimeFormatter.displayString(samples: 24_000) == "0.5s")
    }

    @Test func displaysMinutesAndFractionalSeconds() {
        let samples = (48_000 * 90) + 24_000 // 90.5s
        #expect(SampleTimeFormatter.displayString(samples: samples) == "1m 30.5s")
    }

    @Test func displaysUnknownForNil() {
        #expect(SampleTimeFormatter.displayString(optionalSamples: nil) == "Unknown")
    }

    @Test func passesOptionalThrough() {
        #expect(SampleTimeFormatter.displayString(optionalSamples: 48_000) == "1.0s")
    }
}
