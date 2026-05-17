import SwiftUI

struct FoodSection: View {
    @Binding var refreshTrigger: UUID
    @State private var logs: [FoodLog] = []
    @State private var loggerShown = false
    @State private var expanded: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "food")

            if logs.isEmpty {
                Text("no meals yet today")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 18) {
                    ForEach(logs) { log in
                        row(log)
                    }
                }
            }

            addButton
        }
        .sheet(isPresented: $loggerShown) {
            FoodLoggerSheet {
                Task { await load() }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task(id: refreshTrigger) { await load() }
    }

    private var addButton: some View {
        Button {
            loggerShown = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("add meal")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.top, 4)
    }

    private func row(_ log: FoodLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                photo(log)

                VStack(alignment: .leading, spacing: 3) {
                    Text((log.meal_type ?? "meal").lowercased())
                        .font(Font2.rowTitle)
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: 8) {
                        Text("\(Int(log.estimated_calories ?? 0)) kcal · \(Int(log.estimated_protein_g ?? 0))g")
                            .font(Font2.rowSubtitle)
                            .foregroundStyle(Theme.textSecondary)
                        if log.claude_food_analysis != nil {
                            Text("more details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.chipBlueFg)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Theme.chipBlueBg)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(DateHelpers.rowStamp(log.logged_at))
                    .font(Font2.dateMicro)
                    .foregroundStyle(Theme.textMuted)
            }

            if expanded == log.id, let desc = log.claude_food_analysis ?? log.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                    .padding(.leading, 64)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                expanded = (expanded == log.id) ? nil : log.id
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { Task { await delete(log) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) { Task { await delete(log) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func photo(_ log: FoodLog) -> some View {
        if let url = APIClient.shared.uploadURL(log.photo_path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        Circle().fill(Theme.avatarBg)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        } else {
            IconAvatar(systemName: "fork.knife", size: 50)
        }
    }

    private func load() async {
        do { logs = try await APIClient.shared.listFood(date: Date()) }
        catch { logs = [] }
    }

    private func delete(_ log: FoodLog) async {
        do {
            try await APIClient.shared.deleteFood(id: log.id)
            logs.removeAll { $0.id == log.id }
        } catch { }
    }
}
