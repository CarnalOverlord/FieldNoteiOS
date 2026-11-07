import SwiftUI

struct PhotosView: View {
    @EnvironmentObject private var session: AppSession
    let openSettings: () -> Void
    @State private var beforeID: String?
    @State private var afterID: String?
    @State private var compareMode = 0
    @State private var reveal: Double = 50
    @State private var showingEditor = false

    private var photos: [Entry] { session.entries.filter { $0.photo_path != nil }.sorted { $0.entry_date < $1.entry_date } }
    private var before: Entry? { photos.first { $0.id == beforeID } }
    private var after: Entry? { photos.first { $0.id == afterID } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        FieldNoteTopBar(openSettings: openSettings)
                        VStack(alignment: .leading, spacing: 5) {
                            SectionEyebrow(text: "Progress photos")
                            Text("See how far you’ve come")
                                .font(.system(size: 27, weight: .semibold, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.ink)
                        }

                        if photos.isEmpty {
                            FieldNotePanel {
                                VStack(spacing: 14) {
                                    PhotoPlaceholder().frame(height: 250)
                                    Text("Add a photo to a check-in to start your private progress timeline.")
                                        .font(.system(size: 13, design: .rounded)).foregroundStyle(FieldNoteStyle.muted)
                                    addPhotoButton
                                }
                            }
                        } else {
                            comparisonPanel
                            photoPickerPanel
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 95)
                }
                .refreshable { await session.loadDashboard() }

                if !photos.isEmpty {
                    Button { showingEditor = true } label: {
                        Label("Add photo", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(FieldNoteStyle.paper)
                            .padding(.horizontal, 19).padding(.vertical, 13)
                            .background(FieldNoteStyle.buttonGradient, in: Capsule())
                            .shadow(color: FieldNoteStyle.accent.opacity(0.28), radius: 16, y: 7)
                    }
                    .padding(.trailing, 20).padding(.bottom, 15)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEditor) { EntryEditorView(date: Date()) }
            .onAppear(perform: setInitialPhotos)
            .onChange(of: photos.map(\.id)) { _, _ in setInitialPhotos() }
        }
    }

    private var comparisonPanel: some View {
        FieldNotePanel(padding: 15) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionEyebrow(text: "Side by side")
                    Spacer()
                    Picker("Compare mode", selection: $compareMode) {
                        Text("Side by side").tag(0)
                        Text("Slider").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .labelsHidden()
                }

                if compareMode == 0 {
                    HStack(spacing: 9) {
                        photoFace(before, label: "BEFORE")
                        photoFace(after, label: "AFTER")
                    }
                    .frame(height: 300)
                } else {
                    sliderComparison
                        .frame(height: 380)
                }

                HStack(alignment: .top, spacing: 12) {
                    compareDetail(before, title: "Before")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .medium)).foregroundStyle(FieldNoteStyle.accent).padding(.top, 13)
                    Spacer(minLength: 0)
                    compareDetail(after, title: "Latest")
                }
                .padding(.horizontal, 2)

                if let before, let after {
                    HStack(spacing: 14) {
                        if let a = before.weight_kg, let b = after.weight_kg { Label("\(signed(b - a)) kg", systemImage: "scalemass") }
                        if let a = before.waist_cm, let b = after.waist_cm { Label("\(signed(b - a)) cm waist", systemImage: "ruler") }
                    }
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(FieldNoteStyle.sage)
                }
            }
        }
    }

    private var sliderComparison: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                comparisonImage(after)
                if let before, let path = before.photo_path {
                    RemoteProgressPhoto(path: path)
                        .frame(width: geo.size.width * reveal / 100, height: geo.size.height)
                        .clipped()
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(FieldNoteStyle.accent).frame(width: 2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                VStack {
                    HStack {
                        photoTag("BEFORE")
                        Spacer()
                        photoTag("AFTER")
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FieldNoteStyle.paper)
                            .frame(width: 34, height: 34)
                            .background(FieldNoteStyle.accent, in: Circle())
                            .offset(x: geo.size.width * (reveal / 100 - 0.5))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                reveal = min(100, max(0, value.location.x / geo.size.width * 100))
            })
        }
    }

    private var photoPickerPanel: some View {
        FieldNotePanel(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    SectionEyebrow(text: "Your timeline")
                    Spacer()
                    Text("\(photos.count) photos").font(.system(size: 10, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }.padding(16)

                ForEach(photos.reversed()) { entry in
                    HStack(spacing: 11) {
                        RemoteProgressPhoto(path: entry.photo_path ?? "")
                            .frame(width: 54, height: 64).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(displayDate(entry.entry_date)).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(FieldNoteStyle.ink)
                            Text(entry.weight_kg.map { String(format: "%.1f kg", $0) } ?? "Progress photo")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                        }
                        Spacer()
                        selectionButton(entry, before: true)
                        selectionButton(entry, before: false)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(FieldNoteStyle.line).frame(height: 1) }
                }
            }
        }
    }

    private var addPhotoButton: some View {
        Button { showingEditor = true } label: {
            Label("Add a check-in photo", systemImage: "camera")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(FieldNoteStyle.paper)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(FieldNoteStyle.buttonGradient, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func photoFace(_ entry: Entry?, label: String) -> some View {
        VStack(spacing: 8) {
            if let entry, let path = entry.photo_path {
                RemoteProgressPhoto(path: path).clipShape(RoundedRectangle(cornerRadius: 15))
            } else { PhotoPlaceholder() }
            photoTag(label)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func comparisonImage(_ entry: Entry?) -> some View {
        if let path = entry?.photo_path {
            RemoteProgressPhoto(path: path).clipShape(RoundedRectangle(cornerRadius: 17))
        } else { PhotoPlaceholder() }
    }

    private func compareDetail(_ entry: Entry?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionEyebrow(text: title, color: title == "Latest" ? FieldNoteStyle.accent : FieldNoteStyle.muted)
            Text(entry.map { displayDate($0.entry_date) } ?? "Select a photo")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(FieldNoteStyle.ink)
            if let weight = entry?.weight_kg { Text(String(format: "%.1f kg", weight)).font(.system(size: 10, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoTag(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3)
            .foregroundStyle(FieldNoteStyle.ink).padding(.horizontal, 9).padding(.vertical, 6)
            .background(FieldNoteStyle.strongCard.opacity(0.85), in: Capsule())
    }

    private func selectionButton(_ entry: Entry, before isBefore: Bool) -> some View {
        let isSelected = isBefore ? entry.id == beforeID : entry.id == afterID
        return Button {
            if isBefore { beforeID = entry.id } else { afterID = entry.id }
        } label: {
            Text(isBefore ? "A" : "B")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? FieldNoteStyle.paper : FieldNoteStyle.muted)
                .frame(width: 30, height: 30)
                .background(isSelected ? FieldNoteStyle.accent : FieldNoteStyle.paper, in: Circle())
                .overlay(Circle().stroke(FieldNoteStyle.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set as \(isBefore ? "before" : "after") photo")
    }

    private func setInitialPhotos() {
        guard !photos.isEmpty else { beforeID = nil; afterID = nil; return }
        if beforeID == nil || !photos.contains(where: { $0.id == beforeID }) { beforeID = photos.first?.id }
        if afterID == nil || !photos.contains(where: { $0.id == afterID }) { afterID = photos.last?.id }
        if photos.count == 1 { beforeID = photos[0].id; afterID = photos[0].id }
    }
}
