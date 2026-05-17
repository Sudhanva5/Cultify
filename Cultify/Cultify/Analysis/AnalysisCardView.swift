import SwiftUI

struct AnalysisCardView: View {
    let data: DailyAnalysis?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data {
                section("today's remark")
                Text(data.day_remark ?? "—")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                divider

                section("recommendations")
                ForEach(Array((data.recommendations ?? []).enumerated()), id: \.offset) { _, r in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(Theme.surfaceMuted)
                            Text("•").foregroundStyle(Theme.textPrimary)
                        }
                        .frame(width: 18, height: 18)
                        Text(r)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 8)
                }
                divider

                section("weight projection")
                Text(data.weight_projection ?? "not enough data yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
            } else {
                VStack(spacing: 8) {
                    Text("not generated yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("reports run automatically every night at 10pm")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .cardSurface()
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Font2.sectionLabel)
            .tracking(0.7)
            .foregroundStyle(Theme.textMuted)
            .padding(.bottom, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
            .padding(.vertical, 14)
    }
}
