//
//  TrackTableView.swift
//  PortastudioPreview
//

import SwiftUI

struct TrackTableView: View {
    let tracks: [TrackPreview]
    @Binding var selectedTrackID: TrackPreview.ID?
    var annotationStore: TrackAnnotationStore? = nil

    var body: some View {
        Table(tracks, selection: $selectedTrackID) {
            TableColumn("Track") { track in
                Text("\(track.trackNumber)")
            }
            .width(48)

            TableColumn("Name") { track in
                if let name = annotationStore?.trackName(for: track.trackNumber) {
                    Text(name)
                } else {
                    Text("–")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Mapped WAV") { track in
                Text(track.candidateWAV?.rawFilename ?? "Unassigned")
                    .foregroundStyle(track.candidateWAV == nil ? .secondary : .primary)
            }
            .width(min: 150, ideal: 220)

            TableColumn("Mute") { track in
                Text(settingDisplay(track.mixerSetting?.mute))
            }
            .width(72)

            TableColumn("Pan") { track in
                if let pan = track.mixerSetting?.pan {
                    Text(PanMapper.displayValue(for: pan.primaryByte))
                } else {
                    Text("n/a")
                        .foregroundStyle(.secondary)
                }
            }
            .width(84)

            TableColumn("Level") { track in
                if let level = track.mixerSetting?.level {
                    Text(LevelMapper.displayValue(for: level.primaryByte))
                } else {
                    Text("n/a")
                        .foregroundStyle(.secondary)
                }
            }
            .width(84)

            TableColumn("Raw Bytes") { track in
                Text(rawBytes(for: track))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 260, ideal: 420)

            TableColumn("Evidence") { track in
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.mixerSetting?.level.evidenceLevel.rawValue ?? EvidenceLevel.observed.rawValue)

                    if track.candidateWAV != nil {
                        Text("WAV: \(track.candidateWAVEvidence.rawValue)")
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

    private func rawBytes(for track: TrackPreview) -> String {
        var parts: [String] = []

        if let mixerSetting = track.mixerSetting {
            parts.append(mixerSetting.rawBytesDescription)
        }

        if let activeTake = track.track1ActiveTakeCandidate {
            parts.append("\(HexFormatter.offset(EdlTableParser.track1ActiveTakeCandidateOffset))=\(HexFormatter.byte(activeTake))")
        }

        return parts.isEmpty ? "n/a" : parts.joined(separator: " | ")
    }
}
