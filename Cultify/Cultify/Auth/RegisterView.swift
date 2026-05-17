import SwiftUI

struct RegisterView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("cultify")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("create your account")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 22)

                field("name", text: $name)
                field("email", text: $email, keyboard: .emailAddress)
                field("password (min 6 chars)", text: $password, secure: true)

                if let error {
                    Text(error)
                        .foregroundStyle(Theme.danger)
                        .font(.callout)
                }

                Button(action: submit) {
                    ZStack {
                        if loading { ProgressView().tint(.white) }
                        else { Text("sign up").fontWeight(.semibold).foregroundStyle(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
                }
                .disabled(loading)

                Button { dismiss() } label: {
                    HStack {
                        Spacer()
                        Text("have an account? ").foregroundStyle(Theme.textSecondary)
                        + Text("log in").foregroundStyle(Theme.textPrimary).bold()
                        Spacer()
                    }
                    .font(.system(size: 14))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
    }

    private func submit() {
        error = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            error = "all fields required"; return
        }
        guard password.count >= 6 else {
            error = "password must be at least 6 characters"; return
        }
        loading = true
        Task {
            do {
                let r = try await APIClient.shared.register(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: name.trimmingCharacters(in: .whitespaces)
                )
                session.signIn(token: r.access_token, user: r.user)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "registration failed"
            }
            loading = false
        }
    }
}
