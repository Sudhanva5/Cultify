import SwiftUI

struct SleepSection: View {
    @State private var sleptAt: Date = defaultSlept()
    @State private var wokeAt: Date = defaultWoke()
    @State private var existing: SleepLog?
    @State private var editing = false
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "sleep")

            VStack(spacing: 16) {
                if let existing, !editing {
                    summary(existing)
                } else {
                    editor
                }
            }
            .cardSurface()
        }
        .task { await load() }
    }

    private func summary(_ log: SleepLog) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.avatarBg)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textPrimary.opacity(0.7))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatHours(log.duration_hours ?? 0))
                    .font(Font2.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(DateHelpers.timeShort(log.slept_at).lowercased()) → \(DateHelpers.timeShort(log.woke_at).lowercased())")
                    .font(Font2.rowSubtitle)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button("edit") {
                sleptAt = log.slept_at
                wokeAt = log.woke_at
                editing = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.surfaceMuted)
            .clipShape(Capsule())
        }
    }

    private var editor: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                pillTime(label: "slept at", date: $sleptAt)
                pillTime(label: "woke at", date: $wokeAt)
            }

            Text("duration · \(formatSeconds(duration))")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: submit) {
                ZStack {
                    if saving { ProgressView().tint(.white) }
                    else { Text("log sleep").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
            }
            .disabled(saving || duration <= 0)
            .opacity(duration <= 0 ? 0.4 : 1)
        }
    }

    @ViewBuilder
    private func pillTime(label: String, date: Binding<Date>) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(Font2.sectionLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.textMuted)
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
    }

    private var duration: TimeInterval { max(0, wokeAt.timeIntervalSince(sleptAt)) }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours); let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        let total = Int(value); let h = total / 3600; let m = (total % 3600) / 60
        return "\(h)h \(m)m"
    }

    private func load() async {
        do {
            if let sleep = try await APIClient.shared.getSleep(date: Date()) {
                existing = sleep
                sleptAt = sleep.slept_at
                wokeAt = sleep.woke_at
            }
        } catch { }
    }

    private func submit() {
        saving = true
        Task {
            do {
                let saved = try await APIClient.shared.logSleep(date: Date(), sleptAt: sleptAt, wokeAt: wokeAt)
                existing = saved
                editing = false
            } catch { }
            saving = false
        }
    }

    private static func defaultSlept() -> Date {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) ?? yesterday
    }
    private static func defaultWoke() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
