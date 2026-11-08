import SwiftUI
import UIKit

struct ProgressStoryData {
    let entryDate: String
    let currentWeight: Double
    let previousWeight: Double?
    let startingWeight: Double?
    let goalWeight: Double?
    let bodyFat: Double?
    let bodyFatIsEstimate: Bool
    let weightHistory: [Double]
    let goalProgress: Double?

    var changeSinceLast: Double? {
        previousWeight.map { currentWeight - $0 }
    }

    var totalChange: Double? {
        startingWeight.map { currentWeight - $0 }
    }

    var distanceToGoal: Double? {
        goalWeight.map { abs(currentWeight - $0) }
    }

    static func make(entries: [Entry], profile: Profile?, latestMeasurement: Entry?) -> ProgressStoryData? {
        let weighedEntries = entries
            .filter { $0.weight_kg != nil }
            .sorted { $0.entry_date > $1.entry_date }
        guard let latest = weighedEntries.first, let currentWeight = latest.weight_kg else { return nil }

        let startingWeight = weighedEntries.last?.weight_kg
        let goal = profile?.goal_weight_kg
        let progress: Double? = {
            guard let startingWeight, let goal else { return nil }
            let span = goal - startingWeight
            guard abs(span) > 0.01 else { return nil }
            return min(1, max(0, (currentWeight - startingWeight) / span))
        }()

        let measurementEntry = latestMeasurement ?? latest
        let bodyFat = bodyFatOf(measurementEntry, profile: profile)
        return ProgressStoryData(
            entryDate: latest.entry_date,
            currentWeight: currentWeight,
            previousWeight: weighedEntries.dropFirst().first?.weight_kg,
            startingWeight: startingWeight,
            goalWeight: goal,
            bodyFat: bodyFat,
            bodyFatIsEstimate: measurementEntry.body_fat_pct == nil && bodyFat != nil,
            weightHistory: weighedEntries.reversed().suffix(8).compactMap(\.weight_kg),
            goalProgress: progress
        )
    }
}

struct ProgressStoryShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: ProgressStoryData
    @State private var storyImage: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        if let storyImage {
                            Image(uiImage: storyImage)
                                .resizable()
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .frame(maxWidth: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(FieldNoteStyle.ink.opacity(0.13), lineWidth: 1))
                                .shadow(color: FieldNoteStyle.violet.opacity(0.26), radius: 26, y: 10)
                                .accessibilityLabel("Preview of your FieldNote progress story")
                        } else {
                            ProgressView("Preparing your story…")
                                .tint(FieldNoteStyle.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 440)
                        }

                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share your story", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.paper)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(FieldNoteStyle.buttonGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(storyImage == nil)

                        Text("Your exact check-in details are included in the image. Choose where you share it.")
                            .font(.system(size: 10, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(FieldNoteStyle.muted)
                            .frame(maxWidth: 310)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Your progress story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FieldNoteStyle.accent)
                }
            }
            .toolbarBackground(FieldNoteStyle.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingShareSheet) {
                if let storyImage {
                    StoryActivitySheet(image: storyImage)
                        .presentationDetents([.medium, .large])
                }
            }
            .task { renderStoryIfNeeded() }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func renderStoryIfNeeded() {
        guard storyImage == nil else { return }
        let renderer = ImageRenderer(content: FieldNoteStoryCard(data: data))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        storyImage = renderer.uiImage
    }
}

private struct FieldNoteStoryCard: View {
    let data: ProgressStoryData

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.045, green: 0.025, blue: 0.095), Color(red: 0.015, green: 0.012, blue: 0.035), Color(red: 0.055, green: 0.020, blue: 0.105)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            StoryBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 20)
                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "YOUR JOURNEY", color: FieldNoteStyle.accent)
                    Text("Small steps.\nReal change.")
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                        .tracking(-0.5)
                        .lineSpacing(1)
                        .foregroundStyle(FieldNoteStyle.ink)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 18)
                weightPanel
                Spacer(minLength: 13)
                metricRow
                Spacer(minLength: 12)
                goalPanel
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, 25)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 360, height: 640)
        .clipped()
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [FieldNoteStyle.accent, FieldNoteStyle.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "waveform.path")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FieldNoteStyle.paper)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("FIELDNOTE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(FieldNoteStyle.ink)
                Text("BODY LOG · PERSONAL PROGRESS")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(FieldNoteStyle.muted)
            }
            Spacer(minLength: 4)
            Text(displayDate(data.entryDate).uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var weightPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionEyebrow(text: "CURRENT WEIGHT")
                Spacer()
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FieldNoteStyle.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(String(format: "%.1f", data.currentWeight))
                    .font(.system(size: 57, weight: .medium, design: .rounded))
                    .tracking(-2.2)
                    .foregroundStyle(FieldNoteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("kg")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(FieldNoteStyle.muted)
            }
            StorySparkline(values: data.weightHistory)
                .frame(height: 34)
            Text(data.weightHistory.count > 1 ? "YOUR WEIGHT TREND · LAST CHECK-INS" : "YOUR FIRST CHECK-IN")
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(FieldNoteStyle.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(16)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(LinearGradient(colors: [FieldNoteStyle.accent.opacity(0.38), FieldNoteStyle.line.opacity(0.8), FieldNoteStyle.violet.opacity(0.32)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    private var metricRow: some View {
        HStack(spacing: 9) {
            storyMetric(title: "SINCE LAST", value: data.changeSinceLast.map { "\(signed($0)) kg" } ?? "First log", tint: FieldNoteStyle.sage)
            storyMetric(title: "TOTAL CHANGE", value: data.totalChange.map { "\(signed($0)) kg" } ?? "—", tint: FieldNoteStyle.accent)
            storyMetric(title: data.bodyFatIsEstimate ? "BODY FAT · NAVY" : "BODY FAT", value: data.bodyFat.map { String(format: "%.1f%%", $0) } ?? "Add tape", tint: FieldNoteStyle.clay)
        }
    }

    private func storyMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(FieldNoteStyle.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(FieldNoteStyle.line.opacity(0.75), lineWidth: 1))
    }

    private var goalPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow(text: "NEXT MILESTONE", color: FieldNoteStyle.muted)
                Spacer()
                if let distance = data.distanceToGoal {
                    Text("\(String(format: "%.1f", distance)) kg to go")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(FieldNoteStyle.ink)
                } else {
                    Text("Set a goal when you’re ready")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(FieldNoteStyle.muted)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    if let progress = data.goalProgress {
                        Capsule()
                            .fill(LinearGradient(colors: [FieldNoteStyle.accent, FieldNoteStyle.violet], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(7, geometry.size.width * progress))
                    }
                }
            }
            .frame(height: 7)
            HStack {
                if let startingWeight = data.startingWeight {
                    Text("START  \(String(format: "%.1f", startingWeight)) kg")
                }
                Spacer()
                if let goal = data.goalWeight {
                    Text("GOAL  \(String(format: "%.1f", goal)) kg")
                }
            }
            .font(.system(size: 7, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(FieldNoteStyle.muted)
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FieldNoteStyle.line.opacity(0.8), lineWidth: 1))
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FieldNoteStyle.accent)
            Text("Showing up is the win.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FieldNoteStyle.ink.opacity(0.92))
            Spacer()
            Text("CHECK-IN · \(displayDate(data.entryDate))")
                .font(.system(size: 7, weight: .regular, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.muted.opacity(0.8))
                .lineLimit(1)
        }
    }
}

private struct StorySparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geometry in
            let points = chartPoints(in: geometry.size)
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(LinearGradient(colors: [FieldNoteStyle.accent, FieldNoteStyle.violet], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    if let last = points.last {
                        Circle().fill(FieldNoteStyle.ink).frame(width: 6, height: 6).position(last)
                        Circle().fill(FieldNoteStyle.accent.opacity(0.35)).frame(width: 16, height: 16).position(last)
                    }
                } else {
                    Capsule().fill(FieldNoteStyle.accent.opacity(0.45)).frame(height: 2).frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let minimum = values.min(), let maximum = values.max() else { return [] }
        let span = max(maximum - minimum, 0.2)
        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let y = size.height - 4 - (CGFloat(value - minimum) / CGFloat(span)) * (size.height - 8)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct StoryBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle().fill(FieldNoteStyle.violet.opacity(0.26)).frame(width: 250).blur(radius: 85)
                    .position(x: proxy.size.width * 0.88, y: proxy.size.height * 0.12)
                Circle().fill(FieldNoteStyle.accent.opacity(0.13)).frame(width: 220).blur(radius: 90)
                    .position(x: proxy.size.width * 0.03, y: proxy.size.height * 0.72)
                Canvas { context, size in
                    for index in 0..<7 {
                        let y = size.height * CGFloat(index) / 6
                        let bend = size.width * (0.58 + CGFloat(index % 3) * 0.1)
                        var trace = Path()
                        trace.move(to: CGPoint(x: 0, y: y))
                        trace.addLine(to: CGPoint(x: bend, y: y))
                        trace.addLine(to: CGPoint(x: bend + 16, y: y - 16))
                        trace.addLine(to: CGPoint(x: size.width, y: y - 16))
                        context.stroke(trace, with: .color(FieldNoteStyle.accent.opacity(0.07)), lineWidth: 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StoryActivitySheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
