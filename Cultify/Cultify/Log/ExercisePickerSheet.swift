import SwiftUI

struct ExercisePickerSheet: View {
    let onPick: (ExerciseReference) -> Void

    @State private var search = ""
    @State private var bodyPart = "All"
    @State private var items: [ExerciseReference] = []
    @State private var loading = false

    private let parts = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                title
                searchBar
                pillRow

                if loading && items.isEmpty {
                    Spacer(); ProgressView().tint(Theme.textPrimary); Spacer()
                } else if items.isEmpty {
                    Spacer()
                    Text("no exercises found")
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                } else {
                    list
                }
            }
        }
        .task(id: search + "|" + bodyPart) { await load() }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("pick an exercise")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(items.count) options · cult-relevant only")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
            TextField("", text: $search, prompt: Text("search").foregroundStyle(Theme.textMuted))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.textPrimary)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
        .padding(.horizontal, 20)
    }

    private var pillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(parts, id: \.self) { p in
                    let active = p == bodyPart
                    Button {
                        bodyPart = p
                    } label: {
                        Text(p.lowercased())
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(active ? .white : Theme.textSecondary)
                            .background(active ? Theme.accent : Theme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { ex in
                    Button { onPick(ex) } label: { row(ex) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func row(_ ex: ExerciseReference) -> some View {
        let part = BodyPart(name: ex.body_part)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(part.bg)
                if let url = APIClient.shared.staticURL(ex.gif_path) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(part.fg)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(part.fg)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Font2.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text((ex.equipment ?? "—").lowercased())
                    .font(Font2.rowSubtitle)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let bp = ex.body_part {
                Text(bp.lowercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(part.fg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(part.bg)
                    .clipShape(Capsule())
            }
        }
        .listItem()
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            items = try await APIClient.shared.listExercises(
                bodyPart: bodyPart == "All" ? nil : bodyPart,
                search: search.isEmpty ? nil : search
            )
        } catch { items = [] }
    }
}
