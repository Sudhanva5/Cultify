import SwiftUI
import PhotosUI

struct FoodLoggerSheet: View {
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mealType = "Breakfast"
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showingCamera = false
    @State private var description = ""
    @State private var loading = false
    @State private var error: String?
    @State private var result: FoodLog?

    private let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("log a meal")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("snap a photo and we'll estimate the macros")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    mealRow

                    if let result {
                        resultCard(result)
                    } else {
                        photoBlock
                        descField
                        analyseButton
                        if let error {
                            Text(error)
                                .foregroundStyle(Theme.danger)
                                .font(.callout)
                        }
                    }
                }
                .padding(22)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $image)
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    image = ui
                }
            }
        }
    }

    private var mealRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(meals, id: \.self) { m in
                    let active = mealType == m
                    Button { mealType = m } label: {
                        Text(m.lowercased())
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(active ? .white : Theme.textSecondary)
                            .background(active ? Theme.accent : Theme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var photoBlock: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            } else {
                VStack(spacing: 14) {
                    Button {
                        showingCamera = true
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Theme.surfaceMuted)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .frame(width: 64, height: 64)
                            Text("take a photo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Text("or choose from library")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.chipBlueFg)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    private var descField: some View {
        TextField(
            "",
            text: $description,
            prompt: Text("add a note (optional)").foregroundStyle(Theme.textMuted),
            axis: .vertical
        )
        .lineLimit(2...4)
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
    }

    private var analyseButton: some View {
        Button(action: submit) {
            VStack(spacing: 4) {
                if loading {
                    ProgressView().tint(.white)
                    Text("analysing…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("analyse & log")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(image == nil ? Theme.accent.opacity(0.35) : Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
        }
        .disabled(image == nil || loading)
    }

    @ViewBuilder
    private func resultCard(_ log: FoodLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                Text("meal logged")
                    .foregroundStyle(Theme.textPrimary)
                    .font(.system(size: 17, weight: .semibold))
            }

            Text(macroSummary(log))
                .foregroundStyle(Theme.textSecondary)
                .font(.system(size: 14))

            if let what = log.claude_food_analysis {
                Text(what)
                    .foregroundStyle(Theme.textSecondary)
                    .font(.system(size: 13))
                    .padding(.top, 4)
                    .lineSpacing(2)
            }
            Button {
                onLogged()
                dismiss()
            } label: {
                Text("done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
            }
            .padding(.top, 12)
        }
        .cardSurface()
    }

    private func macroSummary(_ log: FoodLog) -> String {
        let cal = Int(log.estimated_calories ?? 0)
        let p = Int(log.estimated_protein_g ?? 0)
        let c = Int(log.estimated_carbs_g ?? 0)
        let f = Int(log.estimated_fat_g ?? 0)
        return "~\(cal) kcal · \(p)g protein · \(c)g carbs · \(f)g fat"
    }

    private func submit() {
        guard let image else { return }
        loading = true
        error = nil
        Task {
            do {
                let log = try await APIClient.shared.logFood(photo: image, mealType: mealType, description: description)
                result = log
                onLogged()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "upload failed"
            }
            loading = false
        }
    }
}

// MARK: - Camera bridge

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.delegate = context.coordinator
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.allowsEditing = false
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { self.parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
