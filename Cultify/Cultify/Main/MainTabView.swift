import SwiftUI

enum Tab: Hashable {
    case log
    case analysis

    var label: String {
        switch self {
        case .log: return "log"
        case .analysis: return "analysis"
        }
    }

    var icon: String {
        switch self {
        case .log: return "house.fill"
        case .analysis: return "chart.pie.fill"
        }
    }
}

struct MainTabView: View {
    @State private var current: Tab = .log

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch current {
                case .log:      LogView()
                case .analysis: AnalysisView()
                }
            }
            .ignoresSafeArea(edges: .bottom)

            FloatingTabBar(current: $current)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Floating pill tab bar

private struct FloatingTabBar: View {
    @Binding var current: Tab

    var body: some View {
        HStack(spacing: 0) {
            TabPill(tab: .log, current: $current)
            TabPill(tab: .analysis, current: $current)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Theme.surface)
        )
        .overlay(
            Capsule().stroke(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

private struct TabPill: View {
    let tab: Tab
    @Binding var current: Tab

    var body: some View {
        let active = current == tab
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                current = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(active ? Theme.textPrimary : Theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(active ? Theme.surfaceMuted : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
