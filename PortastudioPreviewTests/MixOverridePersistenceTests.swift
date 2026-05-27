//
//  MixOverridePersistenceTests.swift
//  PortastudioPreviewTests
//

import Foundation
import SwiftData
import Testing
@testable import PortastudioPreview

@MainActor
struct MixOverridePersistenceTests {
    @Test func reloadsSavedOverridesForMatchingSongFingerprint() throws {
        let container = try makeContainer()
        let project = makeProject()
        let context = makeContext(fingerprint: "fp-A")

        let firstState = PreviewMixState(project: project)
        firstState.configure(modelContext: container.mainContext)
        firstState.loadOverrides(context: context)
        firstState.setLevelPosition(0.25, for: 1)
        firstState.setPanPosition(-0.5, for: 1)
        firstState.setMuted(true, for: 1)
        firstState.setSoloed(true, for: 1)
        firstState.setSelectedVirtualTrackOptionID("track1#take2", for: 1)

        let reloadedState = PreviewMixState(project: project)
        reloadedState.configure(modelContext: container.mainContext)
        reloadedState.loadOverrides(context: context)

        #expect(reloadedState.levelPosition(for: 1) == 0.25)
        #expect(reloadedState.panPosition(for: 1) == -0.5)
        #expect(reloadedState.isMuted(for: 1))
        #expect(reloadedState.isSoloed(for: 1))
        #expect(reloadedState.selectedVirtualTrackOptionID(for: 1) == "track1#take2")
    }

    @Test func resetSelectedDeletesOnlyThatChannelOverride() throws {
        let container = try makeContainer()
        let project = makeProject()
        let state = PreviewMixState(project: project)
        state.configure(modelContext: container.mainContext)
        state.loadOverrides(context: makeContext())

        state.setMuted(true, for: 1)
        state.setPanPosition(0.75, for: 2)
        state.resetChannel(trackNumber: 1)

        #expect(!state.isMuted(for: 1))
        #expect(state.panPosition(for: 2) == 0.75)

        let records = try container.mainContext.fetch(FetchDescriptor<MixOverrideRecord>())
        #expect(records.count == 1)
        #expect(records.first?.logicalChannelTrackNumber == 2)
    }

    @Test func resetAllDeletesSavedOverrides() throws {
        let container = try makeContainer()
        let state = PreviewMixState(project: makeProject())
        state.configure(modelContext: container.mainContext)
        state.loadOverrides(context: makeContext())

        state.setMuted(true, for: 1)
        state.setSoloed(true, for: 2)
        state.resetAll()

        let records = try container.mainContext.fetch(FetchDescriptor<MixOverrideRecord>())
        #expect(records.isEmpty)
        #expect(!state.isMuted(for: 1))
        #expect(!state.isSoloed(for: 2))
    }

    @Test func fingerprintsIsolateSavedMixes() throws {
        let container = try makeContainer()
        let project = makeProject()

        let stateA = PreviewMixState(project: project)
        stateA.configure(modelContext: container.mainContext)
        stateA.loadOverrides(context: makeContext(fingerprint: "fp-A"))
        stateA.setMuted(true, for: 1)

        let stateB = PreviewMixState(project: project)
        stateB.configure(modelContext: container.mainContext)
        stateB.loadOverrides(context: makeContext(fingerprint: "fp-B"))

        #expect(!stateB.isMuted(for: 1))
    }

    @Test func soloMakesUnsoloedChannelsEffectivelyMuted() {
        let state = PreviewMixState(project: makeProject())

        state.setSoloed(true, for: 2)

        #expect(state.effectiveTrackMuteOverrides[1] == true)
        #expect(state.effectiveTrackMuteOverrides[2] == false)

        state.setMuted(true, for: 2)
        #expect(state.effectiveTrackMuteOverrides[2] == true)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LibrarySourceRecord.self,
            LibrarySongRecord.self,
            TrackAnnotationRecord.self,
            MixOverrideRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeContext(fingerprint: String = "fp-test") -> SongAnnotationContext {
        SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: fingerprint,
            folderURL: URL(fileURLWithPath: "/tmp/SONG_mix"),
            folderDerivedDisplayName: "SONG_mix",
            displayNameOverride: nil,
            matchState: .exact
        )
    }

    private func makeProject() -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_mix"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: (1...2).map(makeTrack(trackNumber:)),
            edlTableSummary: nil
        )
    }

    private func makeTrack(trackNumber: Int) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: nil,
            mixerSetting: TrackMixerSetting(
                trackNumber: trackNumber,
                level: MixerSetting(name: "Level", primaryOffset: 0, primaryByte: LevelMapper.rawUnity, mirrorOffset: nil, mirrorByte: nil, evidenceLevel: .correlated),
                pan: MixerSetting(name: "Pan", primaryOffset: 0, primaryByte: PanMapper.rawCenter, mirrorOffset: nil, mirrorByte: nil, evidenceLevel: .correlated),
                mute: MixerSetting(name: "Mute", primaryOffset: 0, primaryByte: 0, mirrorOffset: nil, mirrorByte: nil, evidenceLevel: .correlated)
            ),
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )
    }
}
