import SwiftUI

struct AnalysisView: View {
    @Environment(SessionStore.self) private var session
    @State private var selectedDate = Date()
    @State private var analysis: DailyAnalysis?
    @State private var loading = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    greeting
                    CalendarStripView(selected: $selectedDate)
                    AnalysisCardView(data: analysis)
                    NutritionArtifactView(data: analysis?.nutrition_json)
                    ChatView()
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .refreshable { await load() }
        }
        .task(id: DateHelpers.isoDate(selectedDate)) { await load() }
    }

    private var header: some View {
        HStack {
            Spacer()
            Menu {
                if let user = session.user { Text(user.email) }
                Divider()
                Button("Sign out", role: .destructive) { session.signOut() }
            } label: {
                AvatarPill(text: session.user?.name ?? "?")
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("analysis")
                .font(Font2.pageTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("claude reads your data every night at 10pm.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { analysis = try await APIClient.shared.analysis(date: selectedDate) }
        catch { analysis = nil }
    }
}
