import SwiftUI
import FirebaseAuth

struct CommunityChatView: View {

    let communityId: String
    let community: CommunityModel
    @ObservedObject var viewModel: CommunityChatViewModel
    @ObservedObject var pollViewModel: CommunityPollViewModel
    @State private var inputText = ""
    @State private var profanityError = false
    @State private var reportTarget: ChatMessage?
    @State private var showReportAlert = false
    @State private var blockTarget: ChatMessage?
    @State private var showBlockAlert = false
    @State private var showCreatePoll = false
    @State private var availableMatchesForPoll: [MatchData] = []

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var isAdmin: Bool { community.adminId == myUid }

    var body: some View {
        VStack(spacing: 0) {
            messagesView
            Divider().background(Color.white.opacity(0.08))
            inputBar
        }
        .background(Color.oneKickBlack)
        .alert("Nachricht melden?", isPresented: $showReportAlert, presenting: reportTarget) { msg in
            Button("Melden", role: .destructive) {
                viewModel.reportMessage(communityId: communityId, messageId: msg.id)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Diese Nachricht wird als unangemessen markiert.")
        }
        .alert("Nutzer blockieren?", isPresented: $showBlockAlert, presenting: blockTarget) { msg in
            Button("Blockieren", role: .destructive) {
                Task { await viewModel.blockUser(uid: msg.userId) }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { msg in
            Text("Du siehst keine Nachrichten von \(msg.displayName) mehr.")
        }
        .task { await viewModel.loadBlockedUsers() }
        .sheet(isPresented: $showCreatePoll) {
            CreatePollView(
                community: community,
                communityId: communityId,
                pollViewModel: pollViewModel,
                availableMatches: availableMatchesForPoll
            ) { pollId in
                viewModel.sendPollMessage(communityId: communityId, pollId: pollId)
            }
        }
    }

    // MARK: Messages

    @ViewBuilder
    private var messagesView: some View {
        if viewModel.messages.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Text("💬").font(.system(size: 40))
                Text("Noch keine Nachrichten")
                    .font(.system(size: 15, weight: .medium)).foregroundColor(.gray)
                Text("Startet die Diskussion!")
                    .font(.caption).foregroundColor(.gray.opacity(0.6))
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.messages) { msg in
                            if msg.type == "poll", let pollId = msg.pollId,
                               let poll = pollViewModel.polls[pollId] {
                                PollCardView(
                                    poll: poll,
                                    communityId: communityId,
                                    community: community,
                                    pollViewModel: pollViewModel
                                )
                                .padding(.horizontal, 4)
                                .id(msg.id)
                            } else {
                                ChatBubbleView(message: msg, isOwn: msg.userId == myUid)
                                    .contextMenu {
                                        if msg.userId != myUid {
                                            Button(role: .destructive) {
                                                reportTarget = msg
                                                showReportAlert = true
                                            } label: {
                                                Label("Melden", systemImage: "flag")
                                            }
                                            Button(role: .destructive) {
                                                blockTarget = msg
                                                showBlockAlert = true
                                            } label: {
                                                Label("Nutzer blockieren", systemImage: "person.crop.circle.badge.xmark")
                                            }
                                        }
                                    }
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if profanityError {
                Text("Dieser Begriff ist nicht erlaubt.")
                    .font(.caption).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
            }
            if let err = viewModel.errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Admin: Poll-Button
                if isAdmin {
                    Button {
                        Task {
                            let league = Array(community.activeLeagues)
                                .filter { $0 != "Relegation" }.sorted().first ?? ""
                            if !league.isEmpty {
                                let matches = await APIFootballService()
                                    .fetchCurrentAndUpcomingMatches(for: LeagueMapper.getID(for: league))
                                if !matches.isEmpty { availableMatchesForPoll = matches }
                            }
                            showCreatePoll = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.oneKickNeon)
                    }
                    .frame(width: 36, height: 36)
                }

                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Nachricht...")
                            .foregroundColor(.gray).font(.system(size: 14))
                            .padding(.top, 8).padding(.leading, 4)
                    }
                    TextEditor(text: $inputText)
                        .font(.system(size: 14)).foregroundColor(.white)
                        .frame(minHeight: 36, maxHeight: 100)
                        .scrollContentBackground(.hidden).background(Color.clear)
                        .onChange(of: inputText) { _, new in
                            if new.count > 300 { inputText = String(new.prefix(300)) }
                            profanityError = false
                        }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.oneKickDarkGray).cornerRadius(16)

                if inputText.count > 250 {
                    Text("\(inputText.count)/300")
                        .font(.caption2)
                        .foregroundColor(inputText.count >= 300 ? .red : .gray)
                }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .oneKickNeon)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.oneKickDarkGray.opacity(0.5))
        }
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if ProfanityFilter.containsProfanity(trimmed) { profanityError = true; return }
        viewModel.sendMessage(communityId: communityId, text: trimmed)
        inputText = ""
        profanityError = false
        viewModel.errorMessage = nil
    }
}

// MARK: - Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 60) }
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
                if !isOwn {
                    Text(message.displayName)
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.oneKickNeon)
                        .padding(.leading, 4)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.text).font(.system(size: 14)).foregroundColor(.white).lineSpacing(3)
                    Text(message.timeString).font(.system(size: 10)).foregroundColor(.gray.opacity(0.7))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isOwn ? Color.oneKickNeon.opacity(0.15) : Color.oneKickDarkGray)
                .cornerRadius(isOwn ? 16 : 16, corners: isOwn ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            }
            if !isOwn { Spacer(minLength: 60) }
        }
    }
}

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
