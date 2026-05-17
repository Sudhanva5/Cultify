import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("cultify")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("welcome back")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 22)

                    field("email", text: $email, keyboard: .emailAddress)
                    field("password", text: $password, secure: true)

                    if let error {
                        Text(error)
                            .foregroundStyle(Theme.danger)
                            .font(.callout)
                    }

                    Button(action: submit) {
                        ZStack {
                            if loading { ProgressView().tint(.white) }
                            else { Text("log in").fontWeight(.semibold).foregroundStyle(.white) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
                    }
                    .disabled(loading)

                    Button { showRegister = true } label: {
                        HStack {
                            Spacer()
                            Text("no account? ").foregroundStyle(Theme.textSecondary)
                            + Text("sign up").foregroundStyle(Theme.textPrimary).bold()
                            Spacer()
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
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
        guard !email.isEmpty, !password.isEmpty else {
            error = "email and password required"; return
        }
        loading = true
        Task {
            do {
                let r = try await APIClient.shared.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
                session.signIn(token: r.access_token, user: r.user)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "login failed"
            }
            loading = false
        }
    }
}
