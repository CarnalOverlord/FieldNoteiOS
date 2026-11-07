import SwiftUI

struct FieldNotePanel<Content: View>: View {
    var padding: CGFloat = 18
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(FieldNoteStyle.line, lineWidth: 1))
    }
}

struct SectionEyebrow: View {
    let text: String
    var color: Color = FieldNoteStyle.muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(2)
            .foregroundStyle(color)
    }
}

struct FieldNoteMetric: View {
    let title: String
    let value: String
    var color: Color = FieldNoteStyle.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionEyebrow(text: title)
            Text(value)
                .font(.system(size: 19, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FieldNoteStatus: View {
    let text: String
    var color: Color = FieldNoteStyle.sage

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct PhotoPlaceholder: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "photo").font(.system(size: 20, weight: .light))
            SectionEyebrow(text: "No photo")
        }
        .foregroundStyle(FieldNoteStyle.muted.opacity(0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FieldNoteStyle.paper.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FieldNoteStyle.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
