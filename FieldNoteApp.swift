import SwiftUI

@main
struct FieldNoteApp: App {
    @StateObject private var session = AppSession()
    @UIApplicationDelegateAdaptor(FieldNoteAppDelegate.self) private var appDelegate

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
            .tint(FieldNoteStyle.accent)
            .fontDesign(.rounded)
            .preferredColorScheme(.dark)
        }
    }
}

enum FieldNoteStyle {
    static let ink = Color(red: 0.97, green: 0.95, blue: 1.00)
    static let paper = Color(red: 0.027, green: 0.016, blue: 0.055)
    static let muted = Color(red: 0.66, green: 0.61, blue: 0.75)
    static let accent = Color(red: 0.93, green: 0.31, blue: 1.00)
    static let violet = Color(red: 0.49, green: 0.19, blue: 1.00)
    static let sage = Color(red: 0.75, green: 0.62, blue: 1.00)
    static let clay = Color(red: 1.00, green: 0.43, blue: 0.66)
    static let cardInk = ink
    static let cardMuted = muted
    static let line = Color(red: 0.23, green: 0.15, blue: 0.34)
    static let card = Color(red: 0.075, green: 0.047, blue: 0.12)
    static let strongCard = Color(red: 0.035, green: 0.020, blue: 0.065)
    static let buttonGradient = LinearGradient(colors: [Color(red: 1.00, green: 0.36, blue: 0.91), accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct FieldNoteBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.105, green: 0.055, blue: 0.18), FieldNoteStyle.paper, Color(red: 0.018, green: 0.010, blue: 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for lane in 0..<9 {
                        let y = size.height * CGFloat(lane) / 8
                        let jog = size.width * (0.28 + CGFloat(lane % 3) * 0.12)
                        var trace = Path()
                        trace.move(to: CGPoint(x: 0, y: y))
                        trace.addLine(to: CGPoint(x: jog, y: y))
                        trace.addLine(to: CGPoint(x: jog + 18, y: y - 18))
                        trace.addLine(to: CGPoint(x: size.width, y: y - 18))
                        context.stroke(trace, with: .color(FieldNoteStyle.violet.opacity(0.055)), lineWidth: 1)
                        let node = CGRect(x: jog + 14, y: y - 22, width: 8, height: 8)
                        context.fill(Path(ellipseIn: node), with: .color(FieldNoteStyle.accent.opacity(0.12)))
                    }
                }
                Circle().fill(FieldNoteStyle.violet.opacity(0.34)).frame(width: 230).blur(radius: 75)
                    .position(x: proxy.size.width * 0.9, y: proxy.size.height * 0.12)
                Circle().fill(FieldNoteStyle.accent.opacity(0.20)).frame(width: 190).blur(radius: 78)
                    .position(x: proxy.size.width * 0.06, y: proxy.size.height * 0.56)
                Circle().fill(FieldNoteStyle.violet.opacity(0.24)).frame(width: 260).blur(radius: 90)
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
        .onReceive(NotificationCenter.default.publisher(for: .fieldNoteOpenToday)) { _ in
            withAnimation(.easeInOut(duration: 0.22)) { selectedTab = .today }
        }
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
