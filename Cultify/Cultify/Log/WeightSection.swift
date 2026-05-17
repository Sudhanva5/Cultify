import SwiftUI

struct WeightSection: View {
    @State private var weight = ""
    @State private var recent: [WeightLog] = []
    @State private var saving = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "weight")

            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    TextField("", text: $weight, prompt: Text("79.0").foregroundStyle(Theme.textMuted))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                    Text("kg")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 8)

                Button(action: submit) {
                    ZStack {
                        if saving { ProgressView().tint(.white) }
                        else { Text("log weight").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(weight.isEmpty ? Theme.accent.opacity(0.35) : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
                }
                .disabled(weight.isEmpty || saving)

                if !recent.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(recent) { entry in
                            HStack {
                                Text(DateHelpers.shortDate(entry.logged_at).lowercased())
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textMuted)
                                Spacer()
                                Text("\(formatWeight(entry.weight_kg)) kg")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .cardSurface()
        }
        .task { await load() }
    }

    private func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func load() async {
        do {
            let all = try await APIClient.shared.listWeight(days: 30)
            recent = Array(all.reversed().prefix(5))
        } catch { recent = [] }
    }

    private func submit() {
        guard let kg = Double(weight.replacingOccurrences(of: ",", with: ".")), kg > 0 else { return }
        saving = true
        Task {
            do {
                _ = try await APIClient.shared.logWeight(kg)
                weight = ""
                focused = false
                await load()
            } catch { }
            saving = false
        }
    }
}
