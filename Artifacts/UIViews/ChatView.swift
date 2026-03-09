//
//  ChatView.swift
//  Artifacts
//
//  Created by Swapnil Puri on 2/24/26.
//

//
//  ChatView.swift
//  Artifacts
//
//  Created by OpenAI on 2/24/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionManager

    let friend: FriendUser

    private let chatService = ChatService()

    @State private var threadId: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var listener: ListenerRegistration?

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var myUid: String { session.user?.uid ?? "" }
    private var isReady: Bool { !threadId.isEmpty && !myUid.isEmpty }

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            ChatBackground()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                messagesPane
                composer
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .onAppear {
            Task { await configureThreadAndListener() }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle().stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(friend.username)")
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(1)

                Text("Direct messages")
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.60))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(ChatCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 10)
    }

    private var messagesPane: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if messages.isEmpty {
                        EmptyChatState()
                            .padding(.top, 18)
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                            let showDateHeader = shouldShowDateHeader(forIndex: index)
                            let showTimestamp = shouldShowTimestamp(forIndex: index)

                            VStack(spacing: 8) {
                                if showDateHeader {
                                    DateSeparator(title: dayLabel(for: msg.createdAt))
                                        .padding(.top, index == 0 ? 6 : 10)
                                }

                                ChatBubble(
                                    text: msg.text,
                                    isMine: msg.senderUid == myUid,
                                    timeText: showTimestamp ? timeLabel(for: msg.createdAt) : nil
                                )
                                .id(msg.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .background(ChatCardBackground())
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 10)
            .onChange(of: messages) { _, newValue in
                guard let last = newValue.last else { return }
                withAnimation(.easeInOut(duration: 0.20)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Message")
                        .font(.custom("Poppins-Regular", size: 15))
                        .foregroundColor(Color.white.opacity(0.38))
                }

                TextField("", text: $inputText, axis: .vertical)
                    .font(.custom("Poppins-Regular", size: 15))
                    .foregroundColor(Color.white.opacity(0.92))
                    .tint(Color("MintGreen"))
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .focused($isInputFocused)
            }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .background(Color("MintGreen"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!isReady || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((!isReady || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.55 : 1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("MintGreen").opacity(0.14), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func attachListener(threadId: String) {
        listener?.remove()
        listener = chatService.listenMessages(threadId: threadId) { msgs in
            Task { @MainActor in
                self.messages = msgs
            }
        }
    }

    private func computeThreadId() -> String {
        ChatService.threadId(uidA: myUid, uidB: friend.id)
    }

    private func ensureThreadExists(threadId: String) async {
        let participants = [myUid, friend.id]
        do {
            try await chatService.ensureThread(threadId: threadId, participants: participants)
        } catch {
            print("ensureThread error:", error)
        }
    }

    private func configureThreadAndListener() async {
        guard !myUid.isEmpty else { return }
        let tId = computeThreadId()
        await MainActor.run { self.threadId = tId }

        await ensureThreadExists(threadId: tId)

        await MainActor.run {
            self.attachListener(threadId: tId)
        }
    }

    private func send() {
        guard !myUid.isEmpty else { return }
        let friendUid = friend.id
        let tId = threadId.isEmpty ? computeThreadId() : threadId
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        Task {
            let needsSetup = await MainActor.run { self.threadId.isEmpty || self.listener == nil }
            if needsSetup {
                await MainActor.run { self.threadId = tId }
                await ensureThreadExists(threadId: tId)
                await MainActor.run {
                    if self.listener == nil {
                        self.attachListener(threadId: tId)
                    }
                }
            }

            do {
                try await chatService.sendMessage(threadId: tId, to: friendUid, text: text)
            } catch {
                await MainActor.run { inputText = text }
                print("sendMessage error:", error)
            }
        }
    }

    // MARK: Date and time grouping logic

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func minuteKey(_ date: Date) -> Int {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        let h = comps.hour ?? 0
        let min = comps.minute ?? 0
        return (((y * 100 + m) * 100 + d) * 100 + h) * 100 + min
    }

    private func shouldShowDateHeader(forIndex index: Int) -> Bool {
        guard index >= 0 && index < messages.count else { return false }
        if index == 0 { return true }
        let curr = messages[index].createdAt
        let prev = messages[index - 1].createdAt
        return startOfDay(curr) != startOfDay(prev)
    }

    private func shouldShowTimestamp(forIndex index: Int) -> Bool {
        guard index >= 0 && index < messages.count else { return false }
        let curr = messages[index]

        if index == messages.count - 1 { return true }

        let next = messages[index + 1]

        let currDay = startOfDay(curr.createdAt)
        let nextDay = startOfDay(next.createdAt)
        if currDay != nextDay { return true }

        let currMinute = minuteKey(curr.createdAt)
        let nextMinute = minuteKey(next.createdAt)

        if curr.senderUid != next.senderUid { return true }
        if currMinute != nextMinute { return true }

        return false
    }

    private func dayLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func timeLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

private struct ChatBubble: View {
    let text: String
    let isMine: Bool
    let timeText: String?

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(.custom("Poppins-Regular", size: 15))
                    .foregroundColor(isMine ? Color.black.opacity(0.92) : Color.white.opacity(0.90))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(isMine ? Color("MintGreen") : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isMine ? Color("MintGreen").opacity(0.20) : Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .cornerRadius(16)
                    .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)

                if let timeText {
                    Text(timeText)
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundColor(Color.white.opacity(0.50))
                        .padding(.horizontal, 6)
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 10)
    }
}

private struct DateSeparator: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()

            Text(title)
                .font(.custom("Poppins-SemiBold", size: 12))
                .foregroundColor(Color.white.opacity(0.70))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(Capsule())

            Spacer()
        }
    }
}

private struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color("MintGreen").opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            Text("Start a conversation")
                .font(.custom("Poppins-SemiBold", size: 14))
                .foregroundColor(Color.white.opacity(0.90))

            Text("Send a message and it will appear here.")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundColor(Color.white.opacity(0.65))
        }
        .padding(.vertical, 10)
    }
}

private struct ChatBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.60),
                    .init(color: Color.black.opacity(0.96), location: 1.00)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                gradient: Gradient(colors: [
                    Color("MintGreen").opacity(0.08),
                    Color.clear
                ]),
                startPoint: .topTrailing,
                endPoint: .center
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.60)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 640
            )
        }
    }
}

private struct ChatCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}
