//
//  ProjectWorkspacePresentationTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectWorkspacePresentationTests {
    @Test func headerIncludesAssignedTrackTimelinesInDurationLabel() {
        // Duration must include tracks with timelines, not only unassigned regions.
        let region = TimelineRegion(
            startSample: 0,
            endSample: 192_000,
            lengthSample: 192_000,
            sourceFilename: "ZZ0001_1.wav",
            sourceURL: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
                rawFilename: "ZZ0001_1.wav",
                byteCount: nil
            ),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: TrackTimeline(trackNumber: 1, regions: [region], evidenceLevel: .hypothesis),
            virtualTrackOptions: [],
            defaultVirtualTrackOptionID: nil
        )
        let project = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],   // region is assigned — not here
            tracks: [track],
            edlTableSummary: nil
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.durationLabel != "Duration unknown")
    }

    @Test func headerUsesDisplayNameAndDerivedStatus() {
        let project = makeProject(
            validationIssues: [],
            regions: [makeRegion(filename: "ZZ0001_1.wav", startSample: 0, length: 96_000)],
            tracks: [makeTrack(trackNumber: 1, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false, assigned: true)]
        )

        let summary = ProjectHeaderSummary(project: project, displayName: "Band Take")

        #expect(summary.title == "Band Take")
        #expect(summary.folderName == "SONG_0001")
        #expect(summary.deviceContext == "Song")
        #expect(summary.formatLabel == "\(Int(SampleTimeFormatter.standardSampleRate / 1_000)) kHz")
        #expect(summary.trackCountLabel == "1 Track")
        #expect(summary.wavCountLabel == "1 Audio File")
        #expect(summary.durationLabel != "Duration unknown")
        #expect(summary.metadataLine.contains(summary.trackCountLabel))
        #expect(summary.metadataLine.contains("1 Audio File"))
        #expect(summary.issueLabel == nil)
        #expect(summary.previewUnavailableLabel == nil)
    }

    @Test func headerFallsBackWhenDurationAndPreviewAreUnavailable() {
        let project = makeProject(validationIssues: [], regions: [], tracks: [])

        let summary = ProjectHeaderSummary(project: project, displayName: "  ")

        #expect(summary.title == "SONG_0001")
        #expect(summary.durationLabel == "Duration unknown")
        #expect(summary.previewUnavailableLabel == "Preview unavailable")
    }

    @Test func headerReportsValidationIssues() {
        let project = makeProject(
            validationIssues: [
                ProjectValidationIssue(id: "warning", severity: .warning, message: "warning"),
                ProjectValidationIssue(id: "error", severity: .error, message: "error")
            ],
            regions: [],
            tracks: []
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.issueLabel == "2 issues need attention")
    }

    @Test func headerReportsWarningOnlyIssues() {
        let project = makeProject(
            validationIssues: [
                ProjectValidationIssue(id: "w1", severity: .warning, message: "Watch out"),
                ProjectValidationIssue(id: "w2", severity: .warning, message: "Also watch out")
            ],
            regions: [],
            tracks: []
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.issueLabel == "2 warnings")
    }

    @Test func mixerStripMapsTrackDisplayState() {
        let track = makeTrack(
            trackNumber: 3,
            level: LevelMapper.rawUnity,
            pan: PanMapper.rawR2,
            muted: true,
            assigned: true
        )

        let strip = TrackMixerStripPresentation(
            channel: MixerChannel(leadingTrackNumber: 3, memberTracks: [track]),
            displayName: "Lead Vocal",
            isSelected: true,
            meterLevel: 0.42
        )

        #expect(strip.id == 3)
        #expect(strip.trackNumberLabel == "3")
        #expect(strip.channelTitle == "Lead Vocal")
        #expect(strip.channelSubtitle == "Track 3")
        #expect(strip.candidateWAVLabel == "ZZ0003_1.wav")
        #expect(strip.audioStatusLabel == "Audio assigned")
        #expect(strip.panDisplayLabel == "R1")
        #expect(strip.panPosition > 0)
        #expect(strip.levelLabel == "0 dB")
        #expect(strip.levelPosition > 0.8)
        #expect(strip.meterLevel == 0.42)
        #expect(strip.isMuted)
        #expect(strip.muteLabel == "Muted")
        #expect(strip.isSelected)
    }

    @Test func mixerStripFallsBackForMissingMixerData() {
        let track = TrackPreview(
            trackNumber: 4,
            candidateWAV: nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [],
            defaultVirtualTrackOptionID: nil
        )

        let strip = TrackMixerStripPresentation(
            channel: MixerChannel(leadingTrackNumber: 4, memberTracks: [track]),
            displayName: nil,
            isSelected: false
        )

        #expect(strip.channelTitle == "Track 4")
        #expect(strip.channelSubtitle == nil)
        #expect(strip.trackNumberLabel == "4")
        #expect(strip.candidateWAVLabel == "No Audio File")
        #expect(strip.audioStatusLabel == "No audio")
        #expect(strip.panDisplayLabel == "C")
        #expect(strip.panPosition == 0)
        #expect(strip.levelLabel == "n/a")
        #expect(strip.levelPosition == 0)
        #expect(strip.meterLevel == 0)
        #expect(!strip.isMuted)
    }

    @Test func primaryPresentationCopyAvoidsInternalTerminology() {
        let cleanSummary = ProjectHeaderSummary(project: makeProject(validationIssues: [], regions: [], tracks: []), displayName: nil)
        let issueSummary = ProjectHeaderSummary(
            project: makeProject(
                validationIssues: [ProjectValidationIssue(id: "warning", severity: .warning, message: "warning")],
                regions: [],
                tracks: []
            ),
            displayName: nil
        )
        let noFileStrip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 8,
                memberTracks: [TrackPreview(
                    trackNumber: 8,
                    candidateWAV: nil,
                    mixerSetting: nil,
                    track1ActiveTakeCandidate: nil,
                    timeline: nil,
                    virtualTrackOptions: [],
                    defaultVirtualTrackOptionID: nil
                )]
            ),
            displayName: nil,
            isSelected: false
        )

        let primaryCopy = [
            cleanSummary.deviceContext,
            cleanSummary.formatLabel,
            cleanSummary.trackCountLabel,
            cleanSummary.wavCountLabel,
            cleanSummary.metadataLine,
            cleanSummary.issueLabel ?? "",
            cleanSummary.previewUnavailableLabel ?? "",
            issueSummary.issueLabel ?? "",
            noFileStrip.audioStatusLabel
        ].joined(separator: " ").lowercased()

        let blockedTerms = ["hypothesis", "validated", "evidence", "edl file list", "preview domain", "exact match"]
        for term in blockedTerms {
            #expect(!primaryCopy.contains(term))
        }
    }

    @Test func mixerPrimaryChannelIdentityAvoidsDuplicateDefaultTrackName() {
        let strip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 4,
                memberTracks: [makeTrack(trackNumber: 4, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false)]
            ),
            displayName: nil,
            isSelected: false
        )

        #expect(strip.channelTitle == "Track 4")
        #expect(strip.channelSubtitle == nil)
    }

    @Test func mixerPrimaryChannelIdentityShowsCustomNameWithSubtleTrackNumber() {
        let strip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 3,
                memberTracks: [makeTrack(trackNumber: 3, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false)]
            ),
            displayName: "Lead Vocal",
            isSelected: false
        )

        #expect(strip.channelTitle == "Lead Vocal")
        #expect(strip.channelSubtitle == "Track 3")
    }

    @Test func mixerPrimaryAudioCopyExcludesTechnicalDetails() {
        let strip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 3,
                memberTracks: [makeTrack(trackNumber: 3, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false, assigned: true)]
            ),
            displayName: "Lead Vocal",
            isSelected: false
        )

        let primaryCopy = [
            strip.channelTitle,
            strip.channelSubtitle ?? "",
            strip.audioStatusLabel
        ].joined(separator: " ").lowercased()

        #expect(!primaryCopy.contains("zz0003_1.wav"))
        #expect(!primaryCopy.contains("confirmed"))
        #expect(!primaryCopy.contains("take"))
        #expect(primaryCopy.contains("audio assigned"))
    }

    @Test func mixerPrimaryAudioCopyKeepsNoAudioStateVisible() {
        let inactiveStrip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 8,
                memberTracks: [TrackPreview(
                    trackNumber: 8,
                    candidateWAV: nil,
                    mixerSetting: nil,
                    track1ActiveTakeCandidate: nil,
                    timeline: nil,
                    virtualTrackOptions: [],
                    defaultVirtualTrackOptionID: nil
                )]
            ),
            displayName: nil,
            isSelected: false
        )
        let missingStrip = TrackMixerStripPresentation(
            channel: MixerChannel(
                leadingTrackNumber: 9,
                memberTracks: [TrackPreview(
                    trackNumber: 9,
                    candidateWAV: nil,
                    mixerSetting: nil,
                    track1ActiveTakeCandidate: nil,
                    timeline: TrackTimeline(trackNumber: 9, regions: [], evidenceLevel: .hypothesis),
                    virtualTrackOptions: [],
                    defaultVirtualTrackOptionID: nil
                )]
            ),
            displayName: nil,
            isSelected: false
        )

        #expect(inactiveStrip.audioStatusLabel == "No audio")
        #expect(missingStrip.audioStatusLabel == "Missing audio")
    }

    @Test func visibleMixerChannelsGroupTrack9And10IntoSingleRow() {
        let project = makeProject(
            validationIssues: [],
            regions: [],
            tracks: [
                makeTrack(trackNumber: 9, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false, assigned: true),
                makeTrack(trackNumber: 10, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false, assigned: true)
            ]
        )

        #expect(project.visibleMixerChannels.count == 1)
        #expect(project.visibleMixerChannels[0].id == 9)
        #expect(project.visibleMixerChannels[0].trackNumberLabel == "9/10")
    }

    // MARK: - Helpers

    private func makeProject(
        validationIssues: [ProjectValidationIssue],
        regions: [TimelineRegion],
        tracks: [TrackPreview]
    ) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: validationIssues,
            wavInventory: [
                WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
                    rawFilename: "ZZ0001_1.wav",
                    byteCount: 128
                )
            ],
            unassignedAudioRegions: regions,
            tracks: tracks,
            edlTableSummary: nil
        )
    }

    private func makeRegion(filename: String, startSample: Int, length: Int) -> TimelineRegion {
        TimelineRegion(
            startSample: startSample,
            endSample: startSample + length,
            lengthSample: length,
            sourceFilename: filename,
            sourceURL: URL(fileURLWithPath: "/tmp/SONG_0001/\(filename)"),
            evidenceLevel: .hypothesis
        )
    }

    private func makeTrack(
        trackNumber: Int,
        level: UInt8,
        pan: UInt8,
        muted: Bool,
        assigned: Bool = false
    ) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: assigned
                ? WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ000\(trackNumber)_1.wav"),
                    rawFilename: "ZZ000\(trackNumber)_1.wav",
                    byteCount: 128
                )
                : nil,
            mixerSetting: TrackMixerSetting(
                trackNumber: trackNumber,
                level: MixerSetting(
                    name: "Level",
                    primaryOffset: 0,
                    primaryByte: level,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .confirmed
                ),
                pan: MixerSetting(
                    name: "Pan",
                    primaryOffset: 1,
                    primaryByte: pan,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .confirmed
                ),
                mute: MixerSetting(
                    name: "Mute",
                    primaryOffset: 2,
                    primaryByte: muted ? 0x01 : 0x00,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .observed
                )
            ),
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: [],
            defaultVirtualTrackOptionID: nil
        )
    }
}
