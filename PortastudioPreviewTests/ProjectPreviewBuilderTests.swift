//
//  ProjectPreviewBuilderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectPreviewBuilderTests {
    @Test func inferredStartSamplesPairImplicitZeroWithDelayedAnchors() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 3,
            timelineAnchors: [882_000, 441_000]
        )

        #expect(starts == [0, 441_000, 882_000])
    }

    @Test func inferredStartSamplesPreserveSingleDelayedRegionSilence() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 1,
            timelineAnchors: [441_000]
        )

        #expect(starts == [441_000])
    }

    @Test func inferredStartSamplesDefaultToZeroWhenTimelinePairingIsAmbiguous() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 3,
            timelineAnchors: [441_000]
        )

        #expect(starts == [0, 0, 0])
    }

    @Test func builderAssignsEDLOrderedWAVsToTracksByPosition() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))
        try Data([0x03]).write(to: folder.url.appendingPathComponent("ZZ0002_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        // EDL position 0 → track 1 (Confirmed)
        #expect(project.tracks[0].candidateWAV?.rawFilename == "ZZ0002_1.wav")
        #expect(project.tracks[0].timeline != nil)
        #expect(project.tracks[0].timeline?.evidenceLevel == .confirmed)
        // EDL position 1 → track 2 (Confirmed)
        #expect(project.tracks[1].candidateWAV?.rawFilename == "ZZ0001_1.wav")
        #expect(project.tracks[1].timeline != nil)
        // EDL position 2 → track 3 (Confirmed)
        #expect(project.tracks[2].candidateWAV?.rawFilename == "ZZ0000_1.wav")
        #expect(project.tracks[2].timeline != nil)
        // Tracks beyond the EDL list remain unassigned
        #expect(project.tracks[3].candidateWAV == nil)
        #expect(project.tracks[3].timeline == nil)
        // All three WAVs are assigned → unassigned regions is empty
        #expect(project.unassignedAudioRegions.isEmpty)
        #expect(StereoPreviewEngine.hasPlayableTracks(project))
    }

    @Test func builderLeavesWAVsNotInEDLAsUnassignedRegions() throws {
        // WAVs present on disk but absent from the EDL file list should stay unassigned.
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0000_1.wav"],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        // ZZ0001_1.wav exists on disk but is NOT in the EDL file list.
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.tracks[0].candidateWAV?.rawFilename == "ZZ0000_1.wav")
        #expect(project.tracks[0].timeline != nil)
        #expect(project.unassignedAudioRegions.map(\.sourceFilename) == ["ZZ0001_1.wav"])
    }

    @Test func builderLeavesAllWAVsUnassignedWhenNoEdlFileList() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        // edltable with no File List entries (just the header bytes).
        try writeEdlTable(
            fileList: [],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.tracks.allSatisfy { $0.candidateWAV == nil })
        #expect(project.tracks.allSatisfy { $0.timeline == nil })
        #expect(project.unassignedAudioRegions.count == 2)
    }

    @Test func builderGroupsVirtualTakeAlternativesIntoSinglePhysicalTrackRow() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0000_1.wav", "ZZ0000_2.wav"],
            activeTakeCandidate: 0x01,
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0000_2.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.tracks[0].virtualTrackOptions.count == 2)
        #expect(project.tracks[0].defaultVirtualTrackOption?.takeNumber == 2)
        #expect(project.tracks[0].candidateWAV?.rawFilename == "ZZ0000_2.wav")
        #expect(project.tracks[1].virtualTrackOptions.isEmpty)
        #expect(project.tracks[1].candidateWAV == nil)
        #expect(project.unassignedAudioRegions.isEmpty)
    }

    @Test func builderKeepsSongFileSelectedTakeAsDefaultVirtualOption() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0003_1.wav", "ZZ0003_2.wav"],
            activeTakeCandidate: 0x00,
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0003_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0003_2.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.tracks[0].defaultVirtualTrackOption?.takeNumber == 1)
        #expect(project.tracks[0].candidateWAV?.rawFilename == "ZZ0003_1.wav")
    }

    @Test func builderPairsImplicitZeroRegionWithDelayedTimelineAnchor() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0000_1.wav", "ZZ0001_1.wav"],
            timelineAnchors: [441_000],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        // Both WAVs are in the EDL file list → assigned to tracks, not unassigned.
        #expect(project.unassignedAudioRegions.isEmpty)
        // Track 1 (EDL position 0) gets the implicit-zero start.
        #expect(project.tracks[0].candidateWAV?.rawFilename == "ZZ0000_1.wav")
        #expect(project.tracks[0].timeline?.regions.first?.startSample == 0)
        // Track 2 (EDL position 1) gets the delayed anchor.
        #expect(project.tracks[1].candidateWAV?.rawFilename == "ZZ0001_1.wav")
        #expect(project.tracks[1].timeline?.regions.first?.startSample == 441_000)
    }

    // MARK: - Sequential start-time helpers

    @Test func wavStemAndSuffixParsesStandardZZFilename() {
        let result = ProjectPreviewBuilder.wavStemAndSuffix("ZZ0008_2.wav")
        #expect(result?.stem == "ZZ0008")
        #expect(result?.suffix == 2)
    }

    @Test func wavStemAndSuffixReturnsPrimaryForTakeOne() {
        let result = ProjectPreviewBuilder.wavStemAndSuffix("ZZ0000_1.wav")
        #expect(result?.stem == "ZZ0000")
        #expect(result?.suffix == 1)
    }

    @Test func wavStemAndSuffixReturnsNilForNonMatchingName() {
        #expect(ProjectPreviewBuilder.wavStemAndSuffix("song.sys") == nil)
        #expect(ProjectPreviewBuilder.wavStemAndSuffix("ZZ0000.wav") == nil)
    }

    @Test func anyBoundaryFoundInEdlReturnsTrueWhenValuePresent() {
        var data = Data(count: 0x42000)
        // Write 252399 (0x0003D9EF) at offset 0x41950 in LE
        let offset = 0x41950
        data[offset] = 0xEF
        data[offset + 1] = 0xD9
        data[offset + 2] = 0x03
        data[offset + 3] = 0x00

        #expect(ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    @Test func anyBoundaryFoundInEdlReturnsTrueForValueWithinTolerance() {
        var data = Data(count: 0x42000)
        let offset = 0x41950
        // Write 252401 when searching for 252399 (diff = 2, within ±5)
        let val: UInt32 = 252401
        data[offset] = UInt8(val & 0xFF)
        data[offset + 1] = UInt8((val >> 8) & 0xFF)
        data[offset + 2] = UInt8((val >> 16) & 0xFF)
        data[offset + 3] = 0x00

        #expect(ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    @Test func anyBoundaryFoundInEdlReturnsFalseWhenAbsent() {
        let data = Data(count: 0x42000)
        #expect(!ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    private func writeEdlTable(
        fileList: [String],
        timelineAnchors: [UInt32] = [],
        activeTakeCandidate: UInt8 = 0x00,
        to url: URL
    ) throws {
        let text = "File List\0" + fileList.joined(separator: "\0") + "\0"
        var data = Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1)
        data.replaceSubrange(0x100..<(0x100 + text.utf8.count), with: text.utf8)
        data[EdlTableParser.track1ActiveTakeCandidateOffset] = activeTakeCandidate

        for (index, anchor) in timelineAnchors.enumerated() {
            writeUInt32LE(anchor, to: &data, at: 0x41858 + index * 0x40)
        }

        try data.write(to: url)
    }

    private func writeUInt32LE(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    // MARK: - Virtual Track Picker Tests

    @Test func pickerIsHiddenForTracksWithNoOptions() {
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [],
            defaultVirtualTrackOptionID: nil
        )
        
        #expect(!track.showsVirtualTrackPicker)
    }

    @Test func pickerIsHiddenForTracksWithSingleOption() {
        let option = VirtualTrackOption(
            id: "track1#zz0000_1.wav",
            takeNumber: 1,
            takeLabel: "Take 1",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                rawFilename: "ZZ0000_1.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_1.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: option.wavItem,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [option],
            defaultVirtualTrackOptionID: option.id
        )
        
        #expect(!track.showsVirtualTrackPicker)
    }

    @Test func pickerIsShownForTracksWithMultipleOptions() {
        let option1 = VirtualTrackOption(
            id: "track1#zz0000_1.wav",
            takeNumber: 1,
            takeLabel: "Take 1",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                rawFilename: "ZZ0000_1.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_1.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let option2 = VirtualTrackOption(
            id: "track1#zz0000_2.wav",
            takeNumber: 2,
            takeLabel: "Take 2",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                rawFilename: "ZZ0000_2.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_2.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: option2.wavItem,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [option1, option2],
            defaultVirtualTrackOptionID: option2.id
        )
        
        #expect(track.showsVirtualTrackPicker)
    }

    @Test func selectedVirtualTrackOptionFallsBackToDefaultWhenNotFound() {
        let option1 = VirtualTrackOption(
            id: "track1#zz0000_1.wav",
            takeNumber: 1,
            takeLabel: "Take 1",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                rawFilename: "ZZ0000_1.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_1.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let option2 = VirtualTrackOption(
            id: "track1#zz0000_2.wav",
            takeNumber: 2,
            takeLabel: "Take 2",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                rawFilename: "ZZ0000_2.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_2.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: option2.wavItem,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [option1, option2],
            defaultVirtualTrackOptionID: option2.id
        )
        
        let selected = track.selectedVirtualTrackOption(selectedOptionID: "invalid-id")
        #expect(selected?.id == option2.id)
    }

    @Test func selectedVirtualTrackOptionReturnsSelectedWhenValid() {
        let option1 = VirtualTrackOption(
            id: "track1#zz0000_1.wav",
            takeNumber: 1,
            takeLabel: "Take 1",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                rawFilename: "ZZ0000_1.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_1.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let option2 = VirtualTrackOption(
            id: "track1#zz0000_2.wav",
            takeNumber: 2,
            takeLabel: "Take 2",
            wavItem: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                rawFilename: "ZZ0000_2.wav",
                byteCount: nil
            ),
            timelineRegion: TimelineRegion(
                startSample: 0,
                endSample: nil,
                lengthSample: nil,
                sourceFilename: "ZZ0000_2.wav",
                sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_2.wav"),
                evidenceLevel: .hypothesis
            ),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: option2.wavItem,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [option1, option2],
            defaultVirtualTrackOptionID: option2.id
        )
        
        let selected = track.selectedVirtualTrackOption(selectedOptionID: option1.id)
        #expect(selected?.id == option1.id)
    }
}
