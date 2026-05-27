//
//  PreviewFixtures.swift
//  PortastudioPreview
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum PreviewFixtures {
    struct Workspace {
        let container: ModelContainer
        let project: PortastudioProject
        let annotationStore: TrackAnnotationStore
        let playbackController: PreviewPlaybackController
        let mixState: PreviewMixState
        let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    }

    static func mixerWorkspace() -> Workspace {
        workspace(
            folderName: "SONG_0092_SYNTH_MIX",
            displayName: "Canvas Mixer Sketch",
            tracks: mixerTracks(),
            issues: [
                ProjectValidationIssue(
                    id: "preview.virtual-take-warning",
                    severity: .warning,
                    message: "Synthetic preview includes virtual take and missing WAV states."
                )
            ],
            annotations: [
                1: "Kick",
                2: "Snare",
                3: "Bass DI",
                4: "Vox Lead",
                5: "Guitar L",
                6: "Guitar R",
                7: "Keys",
                8: "Room",
                9: "Drum Bus",
                11: "Stereo Synth"
            ],
            configureMix: { mixState in
                mixState.setPanPosition(-0.75, for: 1)
                mixState.setPanPosition(0.75, for: 2)
                mixState.setLevelPosition(0.90, for: 4)
                mixState.setMuted(true, for: 6)
                mixState.setSoloed(true, for: 9)
            }
        )
    }

    static func compactWorkspace() -> Workspace {
        workspace(
            folderName: "SONG_0001_EMPTY_CANVAS",
            displayName: "Compact No Audio State",
            tracks: [
                track(
                    number: 1,
                    filename: nil,
                    level: LevelMapper.rawUnity,
                    pan: PanMapper.rawCenter,
                    mute: false,
                    timeline: nil
                )
            ],
            issues: [
                ProjectValidationIssue(
                    id: "preview.no-audio",
                    severity: .warning,
                    message: "No synthetic audio files are assigned."
                )
            ],
            annotations: [:]
        )
    }

    static func editedWorkspace() -> Workspace {
        workspace(
            folderName: "SONG_0101_EDITED_MIX",
            displayName: "Edited Mix State",
            tracks: mixerTracks(),
            issues: [],
            annotations: [
                1: "Kick",
                3: "Bass DI",
                4: "Lead Vocal",
                9: "Stereo Drums"
            ],
            configureMix: { mixState in
                mixState.setLevelPosition(0.25, for: 1)
                mixState.setLevelPosition(1.00, for: 3)
                mixState.setPanPosition(-1.0, for: 5)
                mixState.setPanPosition(1.0, for: 6)
                mixState.setMuted(true, for: 2)
                mixState.setSoloed(true, for: 3)
            }
        )
    }

    static func stripPresentation(
        trackNumber: Int = 4,
        isSelected: Bool = true,
        panPosition: Double = 0,
        levelPosition: Double = 106.0 / 127.0,
        isMuted: Bool = false,
        isSoloed: Bool = false,
        isEffectivelyMuted: Bool = false,
        meterLevel: Double = 0.68
    ) -> TrackMixerStripPresentation {
        let track = track(
            number: trackNumber,
            filename: "TRACK\(twoDigitTrackNumber(trackNumber)).WAV",
            level: LevelMapper.rawUnity,
            pan: PanMapper.rawCenter,
            mute: false
        )
        let channel = MixerChannel(leadingTrackNumber: trackNumber, memberTracks: [track])
        return TrackMixerStripPresentation(
            channel: channel,
            displayName: "Preview Track",
            isSelected: isSelected,
            panPositionOverride: panPosition,
            levelPositionOverride: levelPosition,
            muteOverride: isMuted,
            soloOverride: isSoloed,
            isEffectivelyMuted: isEffectivelyMuted,
            meterLevel: meterLevel
        )
    }

    private static func workspace(
        folderName: String,
        displayName: String,
        tracks: [TrackPreview],
        issues: [ProjectValidationIssue],
        annotations: [Int: String],
        configureMix: ((PreviewMixState) -> Void)? = nil
    ) -> Workspace {
        let folderURL = URL.temporaryDirectory
            .appending(path: "PortastudioPreviewCanvas")
            .appending(path: folderName)
        let project = PortastudioProject(
            folderURL: folderURL,
            validationIssues: issues,
            wavInventory: tracks.compactMap(\.candidateWAV),
            unassignedAudioRegions: [
                region(filename: "UNASSIGNED_01.WAV", start: 12_000, length: 96_000)
            ],
            tracks: tracks,
            edlTableSummary: EdlTableSummary(
                track1ActiveTakeCandidate: 0x02,
                activeTakeCandidateOffset: 0x0010,
                evidenceLevel: .observed,
                fileListEntries: tracks.compactMap { track in
                    guard let filename = track.candidateWAV?.rawFilename else { return nil }
                    return EdlFileListEntry(
                        fileID: track.trackNumber,
                        filename: filename,
                        evidenceLevel: .observed
                    )
                },
                timelineAnchors: [0, 96_000, 192_000],
                timelineCandidates: [
                    EdlTimelineCandidate(
                        representativeSample: 96_000,
                        rawSamples: [96_000, 192_000],
                        evidenceLevel: .hypothesis
                    )
                ]
            )
        )

        let container = previewContainer()
        let context = container.mainContext
        let songID = UUID()
        let songRecord = LibrarySongRecord(
            id: songID,
            displayName: folderName,
            lastKnownPath: folderURL.path,
            isStandalone: true
        )
        songRecord.aggregateFingerprintString = "preview-\(folderName)"
        songRecord.matchStateRawValue = FingerprintMatchState.exact.rawValue
        songRecord.displayNameOverride = displayName
        context.insert(songRecord)

        for (trackNumber, name) in annotations {
            context.insert(
                TrackAnnotationRecord(
                    songFingerprintString: "preview-\(folderName)",
                    trackNumber: trackNumber,
                    trackName: name,
                    lastKnownSongDisplayName: displayName,
                    lastKnownSongPath: folderURL.path,
                    songRecordID: songID
                )
            )
        }
        try? context.save()

        let annotationStore = TrackAnnotationStore(modelContext: context)
        annotationStore.load(
            context: SongAnnotationContext(
                songRecordID: songID,
                songFingerprintString: "preview-\(folderName)",
                folderURL: folderURL,
                folderDerivedDisplayName: folderName,
                displayNameOverride: displayName,
                matchState: .exact
            )
        )

        let mixState = PreviewMixState(project: project)
        mixState.configure(modelContext: context)
        mixState.loadOverrides(context: annotationStore.annotationContext)
        configureMix?(mixState)

        return Workspace(
            container: container,
            project: project,
            annotationStore: annotationStore,
            playbackController: PreviewPlaybackController(),
            mixState: mixState,
            selectedVirtualTrackIDs: mixState.selectedVirtualTrackOptionIDs
        )
    }

    private static func mixerTracks() -> [TrackPreview] {
        [
            track(number: 1, filename: "TRACK01_KICK.WAV", level: LevelMapper.rawUnity, pan: PanMapper.rawHardLeft, mute: false),
            track(number: 2, filename: "TRACK02_SNARE.WAV", level: LevelMapper.rawM3dB, pan: PanMapper.rawHardRight, mute: false),
            track(number: 3, filename: "TRACK03_BASS.WAV", level: LevelMapper.rawM6dB, pan: PanMapper.rawCenter, mute: false),
            track(number: 4, filename: "TRACK04_VOX.WAV", level: LevelMapper.rawMax, pan: PanMapper.rawCenter, mute: false, virtualTakes: true),
            track(number: 5, filename: "TRACK05_GTR_L.WAV", level: LevelMapper.rawM10dB, pan: PanMapper.rawL4, mute: false),
            track(number: 6, filename: "TRACK06_GTR_R.WAV", level: LevelMapper.rawM10dB, pan: PanMapper.rawR4, mute: true),
            track(number: 7, filename: nil, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, mute: false),
            track(number: 8, filename: "TRACK08_ROOM.WAV", level: LevelMapper.rawM20dB, pan: PanMapper.rawCenter, mute: false),
            track(number: 9, filename: "TRACK09_DRUMBUS_L.WAV", level: LevelMapper.rawUnity, pan: PanMapper.rawHardLeft, mute: false),
            track(number: 10, filename: "TRACK10_DRUMBUS_R.WAV", level: LevelMapper.rawUnity, pan: PanMapper.rawHardRight, mute: false),
            track(number: 11, filename: "TRACK11_SYNTH_L.WAV", level: LevelMapper.rawM3dB, pan: PanMapper.rawL2, mute: false),
            track(number: 12, filename: "TRACK12_SYNTH_R.WAV", level: LevelMapper.rawM3dB, pan: PanMapper.rawR2, mute: false)
        ]
    }

    private static func track(
        number: Int,
        filename: String?,
        level: UInt8,
        pan: UInt8,
        mute: Bool,
        timeline: TrackTimeline? = nil,
        virtualTakes: Bool = false
    ) -> TrackPreview {
        let wavItem = filename.map { wav(filename: $0) }
        let primaryOffset = 0x00C0 + ((number - 1) * 0x14)
        let timeline = timeline ?? wavItem.map { item in
            TrackTimeline(
                trackNumber: number,
                regions: [
                    TimelineRegion(
                        startSample: number * 24_000,
                        endSample: nil,
                        lengthSample: 220_500 + (number * 8_000),
                        sourceFilename: item.rawFilename,
                        sourceURL: item.url,
                        evidenceLevel: .hypothesis
                    )
                ],
                evidenceLevel: .hypothesis
            )
        }

        let options: [VirtualTrackOption]
        let defaultOptionID: VirtualTrackOption.ID?
        if virtualTakes, let wavItem, let timelineRegion = timeline?.regions.first {
            let alternate = wav(filename: "TRACK\(twoDigitTrackNumber(number))_ALT.WAV")
            options = [
                VirtualTrackOption(
                    id: "T\(number)-take-1",
                    takeNumber: 1,
                    takeLabel: "Take 1",
                    wavItem: wavItem,
                    timelineRegion: timelineRegion,
                    evidenceLevel: .hypothesis
                ),
                VirtualTrackOption(
                    id: "T\(number)-take-2",
                    takeNumber: 2,
                    takeLabel: "Take 2",
                    wavItem: alternate,
                    timelineRegion: region(filename: alternate.rawFilename, start: 48_000, length: 180_000),
                    evidenceLevel: .hypothesis
                )
            ]
            defaultOptionID = options.first?.id
        } else {
            options = []
            defaultOptionID = nil
        }

        return TrackPreview(
            trackNumber: number,
            candidateWAV: wavItem,
            mixerSetting: TrackMixerSetting(
                trackNumber: number,
                level: setting(name: "Level", offset: primaryOffset, byte: level),
                pan: setting(name: "Pan", offset: primaryOffset + 0x01, byte: pan),
                mute: setting(name: "Mute", offset: primaryOffset + 0x02, byte: mute ? 0x01 : 0x00)
            ),
            track1ActiveTakeCandidate: number == 1 ? 0x02 : nil,
            timeline: timeline,
            virtualTrackOptions: options,
            defaultVirtualTrackOptionID: defaultOptionID
        )
    }

    private static func wav(filename: String) -> WAVInventoryItem {
        WAVInventoryItem(
            url: URL.temporaryDirectory
                .appending(path: "PortastudioPreviewCanvas")
                .appending(path: filename),
            rawFilename: filename,
            byteCount: 4_608_000
        )
    }

    private static func twoDigitTrackNumber(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }

    private static func region(filename: String, start: Int, length: Int) -> TimelineRegion {
        TimelineRegion(
            startSample: start,
            endSample: start + length,
            lengthSample: length,
            sourceFilename: filename,
            sourceURL: URL.temporaryDirectory
                .appending(path: "PortastudioPreviewCanvas")
                .appending(path: filename),
            evidenceLevel: .hypothesis
        )
    }

    private static func setting(name: String, offset: Int, byte: UInt8) -> MixerSetting {
        MixerSetting(
            name: name,
            primaryOffset: offset,
            primaryByte: byte,
            mirrorOffset: offset + 0x0200,
            mirrorByte: byte,
            evidenceLevel: .confirmed
        )
    }

    private static func previewContainer() -> ModelContainer {
        let schema = Schema([
            LibrarySourceRecord.self,
            LibrarySongRecord.self,
            TrackAnnotationRecord.self,
            MixOverrideRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
#endif
