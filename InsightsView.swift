import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var session: AppSession
    let openSettings: () -> Void
    @State private var busy = false
    @State private var errorMessage: String?

    private var insight: String? {
        guard let text = session.profile?.last_insight, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        FieldNoteTopBar(openSettings: openSettings)
                        VStack(alignment: .leading, spacing: 6) {
                            SectionEyebrow(text: "Insights")
                            Text("An honest read")
                                .font(.system(size: 29, weight: .semibold, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.ink)
                        }

                        FieldNotePanel(padding: 20) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle().fill(FieldNoteStyle.accent.opacity(0.16)).frame(width: 40, height: 40)
                                    Circle().fill(FieldNoteStyle.accent).frame(width: 12, height: 12)
                                        .scaleEffect(busy ? 1.3 : 1).opacity(busy ? 0.55 : 1)
                                        .animation(busy ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true) : .default, value: busy)
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        SectionEyebrow(text: "AI insight", color: FieldNoteStyle.accent)
                                        Spacer()
                                        if let generatedAt = session.profile?.last_insight_at {
                                            Text(relativeDate(generatedAt))
                                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                                .foregroundStyle(FieldNoteStyle.muted)
                                        }
                                    }
                                    Text(busy ? "Reading your log…" : (insight ?? emptyCopy))
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .lineSpacing(5)
                                        .foregroundStyle(FieldNoteStyle.ink.opacity(0.9))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        Button(action: generate) {
                            HStack(spacing: 9) {
                                if busy { ProgressView().tint(FieldNoteStyle.paper) }
                                else { Image(systemName: "sparkles") }
                                Text(busy ? "Thinking…" : (insight == nil ? "Get my insight" : "Refresh insight"))
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(FieldNoteStyle.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy || session.entries.filter { $0.weight_kg != nil || $0.waist_cm != nil || $0.photo_path != nil }.count < 2)
                        .opacity(busy || session.entries.count >= 2 ? 1 : 0.52)

                        if let errorMessage { InlineMessage(text: errorMessage) }

                        Text("Uses your weights, tape measurements and notes to describe recent patterns. FieldNote’s insights are for reflection, not medical advice.")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .lineSpacing(4)
                            .foregroundStyle(FieldNoteStyle.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable { await session.loadDashboard() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var emptyCopy: String {
        session.entries.count < 2 ? "Log at least two check-ins to get an honest read of your trend." : "No insight yet. Generate a summary from your recent check-ins."
    }

    private func generate() {
        busy = true
        errorMessage = nil
        Task {
            do { try await session.generateInsight() }
            catch { errorMessage = error.localizedDescription }
            busy = false
        }
    }

    private func relativeDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }
}
