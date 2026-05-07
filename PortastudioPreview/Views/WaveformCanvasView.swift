//
//  WaveformCanvasView.swift
//  PortastudioPreview
//

import SwiftUI

/// Renders the waveform and region block for a single timeline lane using `Canvas`.
///
/// The canvas is always the full timeline width. The region is drawn at its sample-derived
/// x offset within that space.
struct WaveformCanvasView: View {

    let region: TimelineRegionPresentation
    let peakState: WaveformPeakState?
    let totalSampleExtent: Int
    let canvasWidth: CGFloat
    let laneHeight: CGFloat

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let regionX = regionXOffset(in: size)
            let regionW = regionPixelWidth(in: size)

            drawRegionBackground(context: context, x: regionX, w: regionW, h: size.height)
            drawWaveform(context: context, x: regionX, w: regionW, h: size.height)
            drawSelectionHighlight(context: context, x: regionX, w: regionW, h: size.height)
            drawEvidenceBadge(context: context, x: regionX, w: regionW, h: size.height)
        }
        .frame(width: canvasWidth, height: laneHeight)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Private: Layout

    private func regionXOffset(in size: CGSize) -> CGFloat {
        TimelineVisualizationBuilder.sampleToX(
            sample: region.startSample,
            totalExtent: totalSampleExtent,
            width: size.width
        )
    }

    private func regionPixelWidth(in size: CGSize) -> CGFloat {
        guard region.lengthSample > 0, totalSampleExtent > 0 else {
            return max(size.width * 0.05, 8)
        }
        let w = CGFloat(region.lengthSample) / CGFloat(totalSampleExtent) * size.width
        return max(w, 4)
    }

    // MARK: - Private: Drawing

    private func drawRegionBackground(
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        let rect = CGRect(x: x, y: 2, width: w, height: h - 4)
        let fillColor = laneColor.opacity(0.25)
        let path = Path(roundedRect: rect, cornerRadius: 4)

        switch region.playState {
        case .missingSource:
            // Dashed border, no fill.
            context.stroke(
                path,
                with: .color(laneColor.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
        case .suppressed:
            context.fill(path, with: .color(fillColor.opacity(0.4)))
            context.stroke(path, with: .color(laneColor.opacity(0.3)), lineWidth: 1)
        case .ambiguousTiming:
            context.fill(path, with: .color(fillColor.opacity(0.6)))
            context.stroke(path, with: .color(laneColor.opacity(0.4)), lineWidth: 1)
        case .playable:
            context.fill(path, with: .color(fillColor))
            context.stroke(path, with: .color(laneColor.opacity(0.5)), lineWidth: 1)
        }
    }

    private func drawWaveform(
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        switch peakState {
        case .available(let summary) where !summary.peaks.isEmpty:
            drawPeaks(peaks: summary.peaks, context: context, x: x, w: w, h: h)
        case .generating:
            drawGeneratingPlaceholder(context: context, x: x, w: w, h: h)
        default:
            break
        }
    }

    private func drawPeaks(
        peaks: [WaveformPeak],
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        guard peaks.count > 1, w > 2 else { return }

        let midY = h / 2
        let amplitude = (h - 8) / 2
        let pixelPerBucket = w / CGFloat(peaks.count)
        let waveColor = laneColor.opacity(region.playState == .playable ? 0.8 : 0.4)

        var topPath = Path()
        var bottomPath = Path()

        for (i, peak) in peaks.enumerated() {
            let bx = x + CGFloat(i) * pixelPerBucket
            let topY = midY - CGFloat(peak.maxAmplitude) * amplitude
            let botY = midY - CGFloat(peak.minAmplitude) * amplitude

            if i == 0 {
                topPath.move(to: CGPoint(x: bx, y: topY))
                bottomPath.move(to: CGPoint(x: bx, y: botY))
            } else {
                topPath.addLine(to: CGPoint(x: bx, y: topY))
                bottomPath.addLine(to: CGPoint(x: bx, y: botY))
            }
        }

        // Close into a filled shape.
        var fullPath = topPath
        for i in (0..<peaks.count).reversed() {
            let bx = x + CGFloat(i) * pixelPerBucket
            let botY = h / 2 - CGFloat(peaks[i].minAmplitude) * amplitude
            fullPath.addLine(to: CGPoint(x: bx, y: botY))
        }
        fullPath.closeSubpath()

        context.fill(fullPath, with: .color(waveColor))
    }

    private func drawGeneratingPlaceholder(
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        // Thin centre line as a loading indicator.
        let midY = h / 2
        let linePath = Path { p in
            p.move(to: CGPoint(x: x + 4, y: midY))
            p.addLine(to: CGPoint(x: x + w - 4, y: midY))
        }
        context.stroke(linePath, with: .color(laneColor.opacity(0.3)), lineWidth: 1)
    }

    private func drawSelectionHighlight(
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        guard region.isSelected else { return }
        let rect = CGRect(x: x, y: 2, width: w, height: h - 4)
        let path = Path(roundedRect: rect, cornerRadius: 4)
        context.stroke(
            path,
            with: .color(.accentColor),
            lineWidth: 2
        )
    }

    private func drawEvidenceBadge(
        context: GraphicsContext,
        x: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) {
        // Only draw a badge for non-playable states where the label fits.
        guard w > 40 else { return }
        let label: String
        switch region.playState {
        case .suppressed(let reason):
            label = reason
        case .missingSource:
            label = "No audio"
        case .ambiguousTiming:
            label = "Timing unresolved"
        case .playable:
            return
        }

        let text = Text(label)
            .font(.system(size: 9))
            .foregroundColor(laneColor.opacity(0.7))
        let resolved = context.resolve(text)
        let textSize = resolved.measure(in: CGSize(width: w - 8, height: h))
        let textX = x + 4
        let textY = (h - textSize.height) / 2
        context.draw(resolved, at: CGPoint(x: textX, y: textY), anchor: .topLeading)
    }

    // MARK: - Colour palette

    private static let palette: [Color] = [
        .blue, .purple, .green, .orange, .pink, .teal, .indigo, .mint, .cyan, .yellow
    ]

    private var laneColor: Color {
        Self.palette[region.colorIndex % Self.palette.count]
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        "\(region.sourceFilename) at ≈ \(region.startTimeDisplay), length ≈ \(region.lengthDisplay). Evidence: \(region.evidenceLevel.rawValue)."
    }

    private var accessibilityValue: String {
        switch region.playState {
        case .playable: return "Playable"
        case .suppressed(let reason): return "Suppressed: \(reason)"
        case .missingSource: return "Audio file unavailable"
        case .ambiguousTiming: return "Timing ambiguous"
        }
    }
}
