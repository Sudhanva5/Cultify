import SwiftUI

struct ExerciseLogSheet: View {
    let exercise: ExerciseReference
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var duration = ""
    @State private var saving = false
    @State private var error: String?

    enum Mode: String, CaseIterable, Hashable {
        case strength = "strength"
        case cardio = "cardio"
    }

    init(exercise: ExerciseReference, onLogged: @escaping () -> Void) {
        self.exercise = exercise
        self.onLogged = onLogged
        let bp = BodyPart(name: exercise.body_part)
        _mode = State(initialValue: bp == .cardio ? .cardio : .strength)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("log a set")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }

                modeSwitch

                if mode == .strength {
                    HStack(spacing: 10) {
                        numField(label: "sets", text: $sets, placeholder: "3")
                        numField(label: "reps", text: $reps, placeholder: "10")
                        numField(label: "weight (kg)", text: $weight, placeholder: "60", decimals: true)
                    }
                } else {
                    numField(label: "duration (min)", text: $duration, placeholder: "30")
                }

                if let error {
                    Text(error).foregroundStyle(Theme.danger).font(.callout)
                }

                Button(action: submit) {
                    ZStack {
                        if saving { ProgressView().tint(.white) }
                        else { Text("log exercise").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
                }
                .disabled(saving)

                Spacer()
            }
            .padding(22)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases, id: \.self) { m in
                let active = m == mode
                Button {
                    mode = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(active ? .white : Theme.textSecondary)
                        .background(active ? Theme.accent : Theme.surfaceMuted)
                        .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func numField(label: String, text: Binding<String>, placeholder: String, decimals: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Font2.sectionLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.textMuted)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
                .keyboardType(decimals ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
        }
    }

    private func submit() {
        error = nil
        var payload = APIClient.ExerciseLogPayload(exercise_ref_id: exercise.id)
        if mode == .strength {
            payload.sets = Int(sets)
            payload.reps = Int(reps)
            payload.weight_kg = Double(weight.replacingOccurrences(of: ",", with: "."))
            if payload.sets == nil || payload.reps == nil {
                error = "sets and reps required"; return
            }
        } else {
            payload.duration_minutes = Int(duration)
            if payload.duration_minutes == nil {
                error = "duration required"; return
            }
        }
        saving = true
        Task {
            do {
                _ = try await APIClient.shared.logExercise(payload)
                onLogged()
                dismiss()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "failed"
            }
            saving = false
        }
    }
}
