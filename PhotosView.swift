import SwiftUI

struct PhotosView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedPhoto: Entry?
    @State private var showingEditor = false

    private var photos: [Entry] { session.entries.filter { $0.photo_path != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                if photos.isEmpty {
                    ContentUnavailableView {
                        Label("Your progress photos", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Add a photo to any check-in. Your photos are private and appear here in date order.")
                    } actions: {
                        Button("Add a check-in") { showingEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(photos) { entry in
                                Button { selectedPhoto = entry } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RemoteProgressPhoto(path: entry.photo_path!)
                                            .frame(height: 210)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        Text(displayDate(entry.entry_date))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(FieldNoteStyle.ink)
                                        if let weight = entry.weight_kg {
                                            Text(String(format: "%.1f kg", weight))
                                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                                .foregroundStyle(FieldNoteStyle.muted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await session.loadDashboard() }
                }
            }
            .navigationTitle("Progress photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a progress photo")
                }
            }
            .sheet(isPresented: $showingEditor) { EntryEditorView(date: Date()) }
            .sheet(item: $selectedPhoto) { entry in PhotoCompareView(entries: photos, initialEntry: entry) }
        }
    }
}

private struct PhotoCompareView: View {
    let entries: [Entry]
    @State private var selected: Entry
    @Environment(\.dismiss) private var dismiss

    init(entries: [Entry], initialEntry: Entry) {
        self.entries = entries
        _selected = State(initialValue: initialEntry)
    }

    private var olderPhoto: Entry? { entries.filter { $0.entry_date < selected.entry_date }.max { $0.entry_date < $1.entry_date } }
    private var newerPhoto: Entry? { entries.filter { $0.entry_date > selected.entry_date }.min { $0.entry_date < $1.entry_date } }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        RemoteProgressPhoto(path: selected.photo_path ?? "")
                            .frame(maxWidth: .infinity).frame(height: 430)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        Text(displayDate(selected.entry_date)).font(.headline)
                        if let weight = selected.weight_kg {
                            Text(String(format: "%.1f kg", weight)).font(.title2.weight(.semibold)).foregroundStyle(FieldNoteStyle.accent)
                        }
                        if let other = olderPhoto {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("COMPARE WITH AN EARLIER PHOTO").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(FieldNoteStyle.muted)
                                Button { selected = other } label: {
                                    HStack(spacing: 12) {
                                        RemoteProgressPhoto(path: other.photo_path ?? "").frame(width: 78, height: 90).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(displayDate(other.entry_date)).font(.subheadline.weight(.semibold))
                                            Text("View this check-in").font(.caption).foregroundStyle(FieldNoteStyle.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.left.arrow.right")
                                    }
                                    .padding(12).background(FieldNoteStyle.card.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Photo check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0, let newerPhoto { selected = newerPhoto }
                if value.translation.width > 0, let olderPhoto { selected = olderPhoto }
            })
        }
    }
}
