//
//  TrackTableView.swift
//  PortastudioPreview
//

import SwiftUI

struct TrackTableView: View {
    let channels: [MixerChannel]
    @Binding var selectedTrackID: TrackPreview.ID?
    @Binding var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    var annotationStore: TrackAnnotationStore? = nil

    var body: some View {
        Table(channels, selection: $selectedTrackID) {
            TableColumn("Track") { channel in
                Text(channel.trackNumberLabel)
            }
            .width(64)

            TableColumn("Name") { channel in
                if let name = annotationStore?.trackName(for: channel.annotationTrackNumber) {
                    Text(name)
                } else {
                    Text("–")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Mapped WAV") { channel in
                let controlTrack = channel.controlTrack
                let selected = controlTrack?.selectedVirtualTrackOption(
                    selectedOptionID: selectedVirtualTrackIDs[channel.annotationTrackNumber]
                )
                Text(selected?.wavItem.rawFilename ?? controlTrack?.candidateWAV?.rawFilename ?? "Unassigned")
                    .foregroundStyle((selected == nil && controlTrack?.candidateWAV == nil) ? .secondary : .primary)
            }
            .width(min: 150, ideal: 220)

            TableColumn("Mute") { channel in
                Text(settingDisplay(channel.controlTrack?.mixerSetting?.mute))
            }
            .width(72)

            TableColumn("Pan") { channel in
                if let pan = channel.controlTrack?.mixerSetting?.pan {
                    Text(PanMapper.displayValue(for: pan.primaryByte))
                } else {
                    Text("n/a")
                        .foregroundStyle(.secondary)
                }
            }
            .width(84)

            TableColumn("Level") { channel in
                if let level = channel.controlTrack?.mixerSetting?.level {
                    Text(LevelMapper.displayValue(for: level.primaryByte))
                } else {
                    Text("n/a")
                        .foregroundStyle(.secondary)
                }
            }
            .width(84)

            TableColumn("Raw Bytes") { channel in
                Text(rawBytes(for: channel.controlTrack))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 260, ideal: 420)

            TableColumn("Evidence") { channel in
                let controlTrack = channel.controlTrack
                let selected = controlTrack?.selectedVirtualTrackOption(
                    selectedOptionID: selectedVirtualTrackIDs[channel.annotationTrackNumber]
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(controlTrack?.mixerSetting?.level.evidenceLevel.rawValue ?? EvidenceLevel.observed.rawValue)

                    if let selected {
                        Text("WAV: \(selected.evidenceLevel.rawValue)")
                            .foregroundStyle(.secondary)
                    } else if controlTrack?.candidateWAV != nil {
                        Text("WAV: \(controlTrack?.candidateWAVEvidence.rawValue ?? EvidenceLevel.observed.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 110, ideal: 140)
        }
    }

    private func settingDisplay(_ setting: MixerSetting?) -> String {
        guard let setting else {
            return "n/a"
        }

        return HexFormatter.byte(setting.primaryByte)
    }

    private func rawBytes(for track: TrackPreview?) -> String {
        var parts: [String] = []

        if let mixerSetting = track?.mixerSetting {
            parts.append(mixerSetting.rawBytesDescription)
        }

        if let activeTake = track?.track1ActiveTakeCandidate {
            parts.append("\(HexFormatter.offset(EdlTableParser.track1ActiveTakeCandidateOffset))=\(HexFormatter.byte(activeTake))")
        }

        return parts.isEmpty ? "n/a" : parts.joined(separator: " | ")
    }
}
