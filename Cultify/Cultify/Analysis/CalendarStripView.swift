import SwiftUI

struct CalendarStripView: View {
    @Binding var selected: Date

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (-14...0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        let active = Calendar.current.isDate(d, inSameDayAs: selected)
                        Button {
                            selected = d
                        } label: {
                            VStack(spacing: 4) {
                                Text(DateHelpers.weekdayShort(d).lowercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(active ? .white.opacity(0.75) : Theme.textMuted)
                                Text(DateHelpers.dayNumber(d))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(active ? .white : Theme.textPrimary)
                            }
                            .frame(minWidth: 46)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                            .background(active ? Theme.accent : Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .id(d)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(Calendar.current.startOfDay(for: Date()), anchor: .trailing)
            }
        }
    }
}
