//
//  TrackLabelEditorView.swift
//  PortastudioPreview
//

import SwiftUI

/// Small inspector editor for a single track's app-owned label.
///
/// Shows a TextField when the annotation context is editable (exact song fingerprint).
/// Shows a read-only value with a status note when the context is missing or non-exact.
/// The inspector is the primary edit surface; the track table shows the saved label read-only.
struct TrackLabelEditorView: View {
    let trackNumber: Int
    let annotationStore: TrackAnnotationStore

    @State private var draft: String = ""
    @FocusState private var textFieldFocused: Bool

    private var context: SongAnnotationContext? { annotationStore.annotationContext }
    private var isEditable: Bool { context?.isEditable == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditable {
                HStack(spacing: 4) {
                    TextField("Track name", text: $draft)
                        .focused($textFieldFocused)
                        .onSubmit { commitDraft() }
                        .onChange(of: textFieldFocused) { _, focused in
                            if !focused { commitDraft() }
                        }

                    if !draft.isEmpty {
                        Button {
                            draft = ""
                            annotationStore.clearTrackName(for: trackNumber)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear track name")
                    }
                }
            } else {
                let name = annotationStore.trackName(for: trackNumber)
                Text(name ?? "–")
                    .foregroundStyle(name == nil ? .tertiary : .primary)
                    .font(.system(.caption, design: .default))

                statusNote
            }
        }
        .task(id: trackNumber) {
            draft = annotationStore.trackName(for: trackNumber) ?? ""
        }
    }

    private var statusNote: some View {
        Group {
            if let ctx = context {
                if !ctx.songFingerprintString.isEmpty, ctx.matchState != .exact {
                    Text("Labels need an exact song match.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if ctx.songFingerprintString.isEmpty {
                    Text("Song fingerprint required.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No song selected.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commitDraft() {
        annotationStore.setTrackName(draft, for: trackNumber)
        // Sync draft with what was actually persisted (empty string → cleared → "").
        draft = annotationStore.trackName(for: trackNumber) ?? ""
    }
}
