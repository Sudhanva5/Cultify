import SwiftUI

struct NutritionArtifactView: View {
    let data: Nutrition?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "nutrition snapshot")

            if let data {
                let calPct = pct(data.calories_consumed, data.calories_target)
                let protPct = pct(data.protein_consumed, data.protein_target)
                let eff = data.efficiency_pct ?? 0

                HStack(alignment: .top, spacing: 18) {
                    metricColumn(
                        title: "calories",
                        pct: calPct,
                        valueLine: "\(Int(data.calories_consumed ?? 0)) / \(Int(data.calories_target ?? 0)) kcal"
                    )
                    metricColumn(
                        title: "protein",
                        pct: protPct,
                        valueLine: "\(Int(data.protein_consumed ?? 0)) / \(Int(data.protein_target ?? 0))g"
                    )
                }

                HStack(spacing: 8) {
                    Text("overall efficiency · \(Int(eff.rounded()))%")
                        .foregroundStyle(Theme.textPrimary)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(color(forPct: eff)).frame(width: 7, height: 7)
                        Text(label(forPct: eff))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color(forPct: eff))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color(forPct: eff).opacity(0.1))
                    .clipShape(Capsule())
                }

                if let s = data.suggestion, !s.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.warning)
                            .padding(.top, 1)
                        Text(s)
                            .foregroundStyle(Theme.textPrimary)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("no nutrition data for this day")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        }
        .cardSurface()
    }

    private func metricColumn(title: String, pct: Double, valueLine: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(Int(pct))%")
                    .foregroundStyle(color(forPct: pct))
                    .font(.system(size: 12, weight: .semibold))
            }
            ProgressBar(pct: pct)
            Text(valueLine).foregroundStyle(Theme.textSecondary).font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pct(_ consumed: Double?, _ target: Double?) -> Double {
        guard let t = target, t > 0 else { return 0 }
        return ((consumed ?? 0) / t) * 100
    }

    private func color(forPct p: Double) -> Color {
        if p < 60 { return Theme.danger }
        if p < 80 { return Theme.warning }
        return Theme.success
    }

    private func label(forPct p: Double) -> String {
        if p < 60 { return "needs work" }
        if p < 80 { return "getting there" }
        if p < 95 { return "on track" }
        return "nailed it"
    }
}

private struct ProgressBar: View {
    let pct: Double

    var body: some View {
        GeometryReader { geo in
            let safe = max(0, min(100, pct))
            let color: Color = {
                if safe < 60 { return Theme.danger }
                if safe < 80 { return Theme.warning }
                return Theme.success
            }()
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule().fill(color).frame(width: geo.size.width * CGFloat(safe / 100))
            }
        }
        .frame(height: 8)
    }
}
