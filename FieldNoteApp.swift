import SwiftUI

@main
struct FieldNoteApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isLoading {
                    ProgressView("Opening FieldNote…")
                } else if session.isSignedIn {
                    MainTabView()
                        .environmentObject(session)
                } else {
                    SignInView()
                        .environmentObject(session)
                }
            }
            .tint(FieldNoteStyle.ink)
            .fontDesign(.rounded)
            .preferredColorScheme(.dark)
        }
    }
}

enum FieldNoteStyle {
    static let ink = Color(red: 0.94, green: 0.92, blue: 0.87)
    static let paper = Color(red: 0.025, green: 0.045, blue: 0.055)
    static let muted = Color(red: 0.56, green: 0.60, blue: 0.62)
    static let accent = Color(red: 0.84, green: 0.63, blue: 0.32)
    static let violet = accent
    static let sage = Color(red: 0.43, green: 0.69, blue: 0.58)
    static let clay = Color(red: 0.80, green: 0.45, blue: 0.34)
    static let cardInk = ink
    static let cardMuted = muted
    static let line = Color(red: 0.16, green: 0.20, blue: 0.22)
    static let card = Color(red: 0.055, green: 0.085, blue: 0.10)
    static let strongCard = Color(red: 0.015, green: 0.025, blue: 0.03)
    static let buttonGradient = LinearGradient(colors: [Color(red: 0.91, green: 0.69, blue: 0.37), accent], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct FieldNoteBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.065, green: 0.085, blue: 0.09), FieldNoteStyle.paper, Color(red: 0.018, green: 0.03, blue: 0.037)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for lane in 0..<9 {
                        let y = size.height * CGFloat(lane) / 8
                        let jog = size.width * (0.28 + CGFloat(lane % 3) * 0.12)
                        var trace = Path()
                        trace.move(to: CGPoint(x: 0, y: y))
                        trace.addLine(to: CGPoint(x: jog, y: y))
                        trace.addLine(to: CGPoint(x: jog + 18, y: y - 18))
                        trace.addLine(to: CGPoint(x: size.width, y: y - 18))
                        context.stroke(trace, with: .color(FieldNoteStyle.accent.opacity(0.025)), lineWidth: 1)
                        let node = CGRect(x: jog + 14, y: y - 22, width: 8, height: 8)
                        context.fill(Path(ellipseIn: node), with: .color(FieldNoteStyle.accent.opacity(0.07)))
                    }
                }
                Circle().fill(FieldNoteStyle.violet.opacity(0.36)).frame(width: 230).blur(radius: 75)
                    .position(x: proxy.size.width * 0.9, y: proxy.size.height * 0.12)
                Circle().fill(FieldNoteStyle.accent.opacity(0.18)).frame(width: 190).blur(radius: 78)
                    .position(x: proxy.size.width * 0.06, y: proxy.size.height * 0.56)
                Circle().fill(Color(red: 0.27, green: 0.12, blue: 0.78).opacity(0.28)).frame(width: 260).blur(radius: 90)
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.88)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: FieldNoteTab = .today
    @State private var showingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                TodayView(openSettings: { showingProfile = true }).tag(FieldNoteTab.today)
                TrendsView(openSettings: { showingProfile = true }).tag(FieldNoteTab.trends)
                PhotosView(openSettings: { showingProfile = true }).tag(FieldNoteTab.photos)
                InsightsView(openSettings: { showingProfile = true }).tag(FieldNoteTab.insights)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 0) {
                tabButton(.today, title: "Today", symbol: "waveform.path")
                tabButton(.trends, title: "Trends", symbol: "chart.xyaxis.line")
                tabButton(.photos, title: "Photos", symbol: "camera")
                tabButton(.insights, title: "Insights", symbol: "sparkles")
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(FieldNoteStyle.paper.opacity(0.96))
        }
        .background(FieldNoteBackground())
        .task { await session.loadDashboard() }
        .sheet(isPresented: $showingProfile) { ProfileView() }
    }

    private func tabButton(_ tab: FieldNoteTab, title: String, symbol: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.22)) { selectedTab = tab } } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular, design: .rounded))
                Text(title).font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular, design: .rounded))
            }
            .foregroundStyle(selectedTab == tab ? FieldNoteStyle.accent : FieldNoteStyle.muted)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}

enum FieldNoteTab: Hashable { case today, trends, photos, insights }

struct FieldNoteTopBar: View {
    let openSettings: () -> Void

    var body: some View {
        HStack {
            Text("F")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(FieldNoteStyle.paper)
                .frame(width: 38, height: 38)
                .background(FieldNoteStyle.ink, in: Circle())
            Spacer()
            Text("FIELDNOTE · BODY LOG")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(FieldNoteStyle.muted)
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FieldNoteStyle.muted)
                    .frame(width: 38, height: 38)
                    .background(FieldNoteStyle.card, in: Circle())
                    .overlay(Circle().stroke(FieldNoteStyle.line, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.bottom, 18)
    }
}
