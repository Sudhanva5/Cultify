import SwiftUI

struct LogView: View {
    @Environment(SessionStore.self) private var session
    @State private var refreshTrigger = UUID()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    greeting
                    monthChip
                    WorkoutSection(refreshTrigger: $refreshTrigger)
                    FoodSection(refreshTrigger: $refreshTrigger)
                    SleepSection()
                    WeightSection()
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
            .refreshable { refreshTrigger = UUID() }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("today")
                .font(Font2.pageTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("good \(timeOfDay). here's how your day is going.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var monthChip: some View {
        HStack(spacing: 8) {
            Text(DateHelpers.headerLong(Date()).lowercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
    }

    private var timeOfDay: String {
        let h = Calendar.current.component(.hour, from: Date())
        return (h < 12) ? "morning" : (h < 17) ? "afternoon" : "evening"
    }
}
