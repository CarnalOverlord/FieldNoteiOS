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
    static let ink = Color(red: 0.96, green: 0.96, blue: 1.00)
    static let paper = Color(red: 0.035, green: 0.025, blue: 0.15)
    static let muted = Color(red: 0.70, green: 0.69, blue: 0.88)
    static let accent = Color(red: 0.04, green: 0.82, blue: 1.00)
    static let violet = Color(red: 0.48, green: 0.11, blue: 1.00)
    static let cardInk = Color(red: 0.10, green: 0.08, blue: 0.31)
    static let cardMuted = Color(red: 0.38, green: 0.37, blue: 0.56)
    static let line = Color(red: 0.35, green: 0.27, blue: 0.64)
    static let card = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let buttonGradient = LinearGradient(colors: [violet, Color(red: 0.35, green: 0.08, blue: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct FieldNoteBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.08, green: 0.035, blue: 0.31), FieldNoteStyle.paper, Color(red: 0.035, green: 0.025, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for lane in 0..<9 {
                        let y = size.height * CGFloat(lane) / 8
                        let jog = size.width * (0.28 + CGFloat(lane % 3) * 0.12)
                        var trace = Path()
                        trace.move(to: CGPoint(x: 0, y: y))
                        trace.addLine(to: CGPoint(x: jog, y: y))
                        trace.addLine(to: CGPoint(x: jog + 18, y: y - 18))
                        trace.addLine(to: CGPoint(x: size.width, y: y - 18))
                        context.stroke(trace, with: .color(FieldNoteStyle.accent.opacity(0.07)), lineWidth: 1)
                        let node = CGRect(x: jog + 14, y: y - 22, width: 8, height: 8)
                        context.fill(Path(ellipseIn: node), with: .color(FieldNoteStyle.accent.opacity(0.16)))
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

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                TodayView().tag(FieldNoteTab.today)
                PhotosView().tag(FieldNoteTab.photos)
                HistoryView().tag(FieldNoteTab.journal)
                ProfileView(selectedTab: $selectedTab).tag(FieldNoteTab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 0) {
                tabButton(.today, title: "Today", symbol: "sun.max")
                tabButton(.photos, title: "Photos", symbol: "photo.on.rectangle")
                tabButton(.journal, title: "Journal", symbol: "book.closed")
                tabButton(.profile, title: "Profile", symbol: "person.crop.circle")
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(FieldNoteStyle.paper.opacity(0.96))
        }
        .background(FieldNoteBackground())
        .task { await session.loadDashboard() }
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

enum FieldNoteTab: Hashable { case today, photos, journal, profile }
