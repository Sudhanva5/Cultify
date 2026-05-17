import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var used = 0
    @State private var sending = false
    @FocusState private var inputFocused: Bool

    private let limit = AppConfig.chatDailyLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "ask claude")
                Spacer()
                Text("\(used)/\(limit) today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceMuted)
                    .clipShape(Capsule())
            }

            VStack(spacing: 0) {
                messageList
                inputRow
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .task { await load() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        placeholder
                    } else {
                        ForEach(messages) { m in
                            bubble(m).id(m.id)
                        }
                    }
                    if sending {
                        HStack {
                            TypingDots()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Theme.surfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 200, maxHeight: 380)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(Theme.textMuted)
            Text("ask about your data")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("\"was my protein enough today?\"")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == "user" { Spacer(minLength: 40) }
            Text(m.content)
                .font(.system(size: 14))
                .foregroundStyle(m.role == "user" ? .white : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(m.role == "user" ? Theme.accent : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if m.role != "user" { Spacer(minLength: 40) }
        }
    }

    private var inputRow: some View {
        let atLimit = used >= limit
        let placeholderText = atLimit
            ? "daily limit reached. resets tomorrow."
            : "ask something…"

        return HStack(alignment: .bottom, spacing: 8) {
            TextField(
                "",
                text: $input,
                prompt: Text(placeholderText).foregroundStyle(Theme.textMuted),
                axis: .vertical
            )
            .lineLimit(1...4)
            .focused($inputFocused)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
            .disabled(atLimit || sending)
            .opacity(atLimit ? 0.6 : 1)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(11)
                    .background(Theme.accent)
                    .clipShape(Circle())
            }
            .disabled(atLimit || sending || input.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity((atLimit || input.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.35 : 1)
        }
        .padding(10)
    }

    private func load() async {
        do {
            let r = try await APIClient.shared.chatToday()
            messages = r.messages
            used = r.messages_used
        } catch { }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !sending, used < limit else { return }
        input = ""
        sending = true
        let optimistic = ChatMessage(id: UUID().uuidString, role: "user", content: text, created_at: Date())
        messages.append(optimistic)

        Task {
            do {
                let resp = try await APIClient.shared.chatSend(text)
                used = resp.messages_used
                messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", content: resp.response, created_at: Date()))
            } catch {
                let err = (error as? LocalizedError)?.errorDescription ?? "failed to send"
                messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", content: "⚠️ \(err)", created_at: Date()))
                if case APIError.rateLimited(_, let lim) = error { used = lim }
            }
            sending = false
        }
    }
}

private struct TypingDots: View {
    @State private var t: Double = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.textMuted)
                    .frame(width: 6, height: 6)
                    .opacity(0.4 + 0.6 * sin(t + Double(i) * 0.5))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }
}
