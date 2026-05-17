import SwiftUI

struct WorkoutSection: View {
    @Binding var refreshTrigger: UUID
    @State private var logs: [ExerciseLog] = []
    @State private var pickerShown = false
    @State private var pickedExercise: ExerciseReference?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "workout")

            if logs.isEmpty {
                Text("no exercises yet today")
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
        .sheet(isPresented: $pickerShown) {
            ExercisePickerSheet { ref in
                pickerShown = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    pickedExercise = ref
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $pickedExercise) { ref in
            ExerciseLogSheet(exercise: ref) {
                pickedExercise = nil
                Task { await load() }
            }
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.visible)
        }
        .task(id: refreshTrigger) { await load() }
    }

    private var addButton: some View {
        Button {
            pickerShown = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("add exercise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.top, 4)
    }

    private func row(_ log: ExerciseLog) -> some View {
        let part = BodyPart(name: log.body_part)
        return HStack(alignment: .center, spacing: 14) {
            IconAvatar(systemName: iconFor(part), tint: part.fg, size: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(log.displayName)
                    .font(Font2.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text((log.body_part ?? "—").lowercased())
                    .font(Font2.rowSubtitle)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(log.summary)
                    .font(Font2.value)
                    .foregroundStyle(Theme.textPrimary)
                Text(DateHelpers.rowStamp(log.logged_at))
                    .font(Font2.dateMicro)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .contentShape(Rectangle())
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

    private func iconFor(_ p: BodyPart) -> String {
        switch p {
        case .chest:     return "figure.strengthtraining.traditional"
        case .back:      return "figure.strengthtraining.functional"
        case .shoulders: return "figure.boxing"
        case .arms:      return "dumbbell.fill"
        case .legs:      return "figure.run"
        case .core:      return "figure.core.training"
        case .cardio:    return "heart.fill"
        case .other:     return "dumbbell.fill"
        }
    }

    private func load() async {
        do { logs = try await APIClient.shared.listExerciseLogs(date: Date()) }
        catch { logs = [] }
    }

    private func delete(_ log: ExerciseLog) async {
        do {
            try await APIClient.shared.deleteExerciseLog(id: log.id)
            logs.removeAll { $0.id == log.id }
        } catch { }
    }
}
