import Foundation
import Combine
import Testing
import AgentsModels
import NetworkClient
@testable import IndiceAgents

/// URLProtocol exercises the actual URLSession.shared byte transport without
/// credentials, live backend mutations, or an external test-server dependency.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct TransportRepositoryTests {
    init() { URLProtocol.registerClass(FixtureHTTP.self) }

    @Test func transportYieldsBeforeEOFAndCancelsConnection() async throws {
        FixtureHTTP.state.configure { _ in .init(body: TurnFixture.wire, keepOpen: true) }
        let client = NetworkClient()
        let stream = try await client.openSSEStream(DexChatResponseUpdate.self, request: URLRequest(url: endpoint), decoder: APIJSON.decoder)
        var count = 0
        for try await event in stream {
            count += 1
            if case .done = event.data { break }
        }
        #expect(count == TurnFixture.payloads.count)
        stream.cancel()
        try await eventually { FixtureHTTP.state.stopCount > 0 }
        #expect(FixtureHTTP.state.requests.first?.value(forHTTPHeaderField: "Accept") == "text/event-stream")
    }

    @Test func responseValidationAndDecodeFailures() async throws {
        for (status, contentType) in [(404, "application/problem+json"), (200, "application/json")] {
            FixtureHTTP.state.configure { _ in .init(status: status, contentType: contentType, body: Data("{}".utf8)) }
            do {
                _ = try await NetworkClient().openSSEStream(DexChatResponseUpdate.self, request: URLRequest(url: endpoint))
                Issue.record("Expected transport validation error")
            } catch let error as SSEError {
                if status == 404 {
                    guard case .http(let code, let body) = error else { Issue.record("Expected HTTP error"); continue }
                    #expect(code == 404)
                    #expect(body == Data("{}".utf8))
                } else {
                    guard case .unexpectedContentType = error else { Issue.record("Expected content-type error"); continue }
                }
            }
        }
        FixtureHTTP.state.configure { _ in .init(body: Data("data: {broken}\n\n".utf8)) }
        let stream = try await NetworkClient().openSSEStream(DexChatResponseUpdate.self, request: URLRequest(url: endpoint))
        defer { stream.cancel() }
        await #expect(throws: DecodingError.self) { for try await _ in stream {} }
    }

    @Test func cancellationStopsBlockedConsumer() async throws {
        FixtureHTTP.state.configure { _ in .init(body: Data(), keepOpen: true) }
        let task = Task {
            let stream = try await NetworkClient().openSSEStream(DexChatResponseUpdate.self, request: URLRequest(url: endpoint))
            defer { stream.cancel() }
            for try await _ in stream {}
            try Task.checkCancellation()
        }
        try await eventually { FixtureHTTP.state.requests.count == 1 }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        try await eventually { FixtureHTTP.state.stopCount > 0 }
    }

    @Test func iteratorKeepsTemporarySequenceAlive() async throws {
        FixtureHTTP.state.configure { _ in .init(body: TurnFixture.wire) }
        var iterator = try await NetworkClient().openSSEStream(DexChatResponseUpdate.self, request: URLRequest(url: endpoint)).makeAsyncIterator()
        var count = 0
        while let _ = try await iterator.next() { count += 1 }
        #expect(count == TurnFixture.payloads.count)
    }

    @Test func transportPreservesBurstForSlowConsumer() async throws {
        let wire = Data((0..<512).map { "data: \($0)\n\n" }.joined().utf8)
        FixtureHTTP.state.configure { _ in .init(body: wire) }
        let stream = try await NetworkClient().openSSEStream(Int.self, request: URLRequest(url: endpoint))
        defer { stream.cancel() }
        var received: [Int] = []
        for try await event in stream {
            received.append(event.data)
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(received == Array(0..<512))
    }

    @Test func explicitCancelUnblocksFullTransportQueue() async throws {
        let wire = Data((0..<512).map { "data: \($0)\n\n" }.joined().utf8)
        FixtureHTTP.state.configure { _ in .init(body: wire, keepOpen: true) }
        let stream = try await NetworkClient().openSSEStream(Int.self, request: URLRequest(url: endpoint))
        var iterator = stream.makeAsyncIterator()
        #expect(try await iterator.next()?.data == 0)
        try await Task.sleep(for: .milliseconds(50))
        stream.cancel()
        await #expect(throws: CancellationError.self) { try await iterator.next() }
        try await eventually { FixtureHTTP.state.stopCount > 0 }
    }

    @MainActor @Test(arguments: [Duration.milliseconds(75), .seconds(60)])
    func serviceBatchesLargeBurstAndFlushesOnDone(interval: Duration) async throws {
        let chunk = "Γεια 👋 "
        let count = 2_000
        var payloads = Array(TurnFixture.payloads.prefix(5))
        payloads.append(#"{"type":"delta","path":"/messages/0/content/parts/0/value","op":"append","value":"Γεια 👋 "}"#)
        payloads += Array(repeating: #"{"type":"delta","value":"Γεια 👋 "}"#, count: count - 1)
        payloads.append(#"{"type":"done"}"#)
        let wire = Data(payloads.map { "data: \($0)\n\n" }.joined().utf8)
        FixtureHTTP.state.configure { request in
            request.httpMethod == "GET" ? ConversationFixture.reply : .init(body: wire, keepOpen: true)
        }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil, streamUpdateInterval: interval)
        var snapshots: [[ChatSessionService.Message]] = []
        let token = session.messages.sink { snapshots.append($0) }
        defer { token.cancel() }
        try await session.sendStream(message: "Hello")
        try await waitForMetadata(session, title: "Planning")
        #expect(session.messages.value.last?.text == String(repeating: chunk, count: count))
        #expect(session.messages.value.last?.delivery == .complete)
        #expect(await session.lastResponse?.text == String(repeating: chunk, count: count))
        if interval == .seconds(60) {
            #expect(snapshots.count == 3) // Subscription, user message, final batch.
        } else {
            #expect(snapshots.count < count / 10)
        }
        #expect(session.streamState.value == .completed)
    }

    @MainActor @Test func cancellationFlushesUnpublishedTextAndAllowsNextTurn() async throws {
        let wire = Data(TurnFixture.payloads.prefix(9).map { "data: \($0)\n\n" }.joined().utf8)
        FixtureHTTP.state.configure { _ in .init(body: wire, keepOpen: true) }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil, streamUpdateInterval: .seconds(60))
        var metadata = ChatSessionMetadata()
        let metadataToken = session.metadata.sink { metadata = $0 }
        defer { metadataToken.cancel() }
        let task = Task { try await session.sendStream(message: "Hello") }
        defer { task.cancel() }
        try await eventually { await session.chatID == TurnFixture.id }
        // Let the short fixture drain while the presentation timer stays asleep.
        try await Task.sleep(for: .milliseconds(100))
        #expect(session.messages.value.count == 1)
        #expect(metadata == ChatSessionMetadata(id: TurnFixture.id))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(session.messages.value.last?.text == "Γεια 👋")
        #expect(session.messages.value.last?.delivery == .cancelled)
        #expect(await session.lastResponse == nil)
        #expect(FixtureHTTP.state.requests.allSatisfy { $0.httpMethod == "POST" })
        try await eventually { FixtureHTTP.state.stopCount > 0 }
        let stoppedMessageID = session.messages.value.last?.id

        FixtureHTTP.state.configure { request in
            request.httpMethod == "GET" ? ConversationFixture.reply : .init(body: TurnFixture.wire)
        }
        try await session.sendStream(message: "Continue")
        try await waitForMetadata(session, title: "Planning")
        #expect(session.messages.value.count == 4)
        #expect(session.messages.value[1].id == stoppedMessageID)
        #expect(session.messages.value[1].delivery == .cancelled)
        #expect(session.messages.value.last?.delivery == .complete)
        #expect(session.streamState.value == .completed)
        #expect(metadata.title == "Planning")
    }

    @MainActor @Test func servicePublishesPendingBatchDuringServerPause() async throws {
        let wire = Data(TurnFixture.payloads.prefix(9).map { "data: \($0)\n\n" }.joined().utf8)
        FixtureHTTP.state.configure { _ in .init(body: wire, keepOpen: true) }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil)
        var publicationCount = 0
        let token = session.messages.sink { _ in publicationCount += 1 }
        defer { token.cancel() }
        let task = Task { try await session.sendStream(message: "Hello") }
        defer { task.cancel() }
        try await eventually { await MainActor.run { session.messages.value.last?.text == "Γεια 👋" } }
        #expect(session.messages.value.last?.delivery == .streaming)
        #expect(await session.lastResponse == nil)
        let countAtPause = publicationCount
        try await Task.sleep(for: .milliseconds(175))
        #expect(publicationCount == countAtPause)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(session.messages.value.last?.delivery == .cancelled)
        let countAtCancel = publicationCount
        try await Task.sleep(for: .milliseconds(175))
        #expect(publicationCount == countAtCancel)
    }

    @Test func streamRefreshesOnceBeforeOpeningAndDoesNotReplay() async throws {
        let credentials = Credentials()
        let auth = StreamAuthorization(credentials: { credentials.snapshot }, refresh: { credentials.refreshed() })
        FixtureHTTP.state.configure { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" { return .init(status: 401, body: Data(), keepOpen: true) }
            return .init(body: TurnFixture.wire)
        }
        let repository = makeRepository(auth: auth)
        let stream = try await repository.createOnStream(chatRequest: .init(text: "Hello"))
        for try await _ in stream {}
        #expect(credentials.refreshCount == 1)
        #expect(FixtureHTTP.state.requests.count == 2)
        #expect(FixtureHTTP.state.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
        #expect(FixtureHTTP.state.requests.last?.url?.path == "/api/my/chats/stream")
        #expect(FixtureHTTP.state.requests.last?.httpMethod == "POST")

        FixtureHTTP.state.configure { _ in .init(status: 401, body: Data()) }
        do {
            _ = try await repository.streamOnMessage(message: .init(text: "Again"), onChatId: TurnFixture.id)
            Issue.record("Expected rejected credentials")
        } catch let error as SSEError {
            guard case .http(let status, _) = error else { Issue.record("Expected 401"); return }
            #expect(status == 401)
        }
        #expect(FixtureHTTP.state.requests.count == 2)
        #expect(FixtureHTTP.state.requests.last?.url?.path.lowercased() == "/api/my/chats/\(TurnFixture.id.uuidString.lowercased())/messages/stream")

        FixtureHTTP.state.configure { _ in .init(body: Data(("data: " + TurnFixture.payloads[0] + "\n\ndata: {broken}\n\n").utf8)) }
        let broken = try await repository.createOnStream(chatRequest: .init(text: "Hello"))
        defer { broken.cancel() }
        await #expect(throws: DecodingError.self) { for try await _ in broken {} }
        #expect(FixtureHTTP.state.requests.count == 1)
    }

    @Test func expiredCredentialsAreRefreshedBeforeRequest() async throws {
        let credentials = Credentials(expired: true)
        let auth = StreamAuthorization(credentials: { credentials.snapshot }, refresh: { credentials.refreshed() })
        async let first = auth.authorize(URLRequest(url: endpoint))
        async let second = auth.authorize(URLRequest(url: endpoint))
        let results = try await [first, second]
        #expect(credentials.refreshCount == 1)
        #expect(results.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer new" })
    }

    @MainActor @Test func servicePublishesStableProgressAndCommitsOnlyOnDone() async throws {
        FixtureHTTP.state.configure { request in
            request.httpMethod == "GET" ? ConversationFixture.reply : .init(body: TurnFixture.wire, keepOpen: true, delayChunks: true)
        }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil)
        var snapshots: [[ChatSessionService.Message]] = []
        let token = session.messages.sink { snapshots.append($0) }
        defer { token.cancel() }
        try await session.sendStream(message: "Hello")
        try await waitForMetadata(session, title: "Planning")
        #expect(await session.chatID == TurnFixture.id)
        #expect(await session.lastResponse?.text == "Γεια 👋")
        let partials = snapshots.flatMap { $0.filter { $0.delivery == .streaming && !$0.text.isEmpty } }
        #expect(!partials.isEmpty)
        let final = try #require(session.messages.value.last)
        #expect(partials.allSatisfy { $0.id == final.id })
        #expect(final.delivery == .complete)
        #expect(final.value.messageId == "opaque-id")
        #expect(session.streamState.value == .completed)
        try await eventually { FixtureHTTP.state.stopCount > 0 }
    }

    @MainActor @Test func servicePreservesInterruptedTextAndDiscardsFailedAnswer() async throws {
        let prefix = TurnFixture.payloads.prefix(9).map { "data: \($0)\n\n" }.joined()
        FixtureHTTP.state.configure { _ in .init(body: Data(prefix.utf8)) }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil, streamUpdateInterval: .seconds(60))
        await #expect(throws: AgentsError.self) { try await session.sendStream(message: "Hello") }
        #expect(session.messages.value.last?.delivery == .interrupted)
        #expect(session.messages.value.last?.text == "Γεια 👋")
        #expect(await session.lastResponse == nil)

        FixtureHTTP.state.configure { _ in .init(body: Data((prefix + "data: {\"type\":\"error\",\"reason\":\"Unavailable\"}\n\n").utf8)) }
        let failed = ChatSessionService(repository: makeRepository(), chatID: nil, streamUpdateInterval: .seconds(60))
        await #expect(throws: AgentsError.self) { try await failed.sendStream(message: "Hello") }
        #expect(failed.messages.value.count == 1)
        #expect(failed.messages.value.first?.value.role == .user)
        #expect(failed.streamState.value == .failed("Unavailable"))
    }

    @MainActor @Test func serviceCancellationAndConcurrentSendGuard() async throws {
        let prefix = TurnFixture.payloads.prefix(9).map { "data: \($0)\n\n" }.joined()
        FixtureHTTP.state.configure { _ in .init(body: Data(prefix.utf8), keepOpen: true) }
        let session = ChatSessionService(repository: makeRepository(), chatID: nil)
        let task = Task { try await session.sendStream(message: "Hello") }
        try await eventually { await MainActor.run { session.messages.value.last?.text == "Γεια 👋" } }
        await #expect(throws: AgentsError.self) { try await session.send(message: "Another") }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(session.messages.value.last?.delivery == .cancelled)
        #expect(session.streamState.value == .cancelled)
        #expect(await session.lastResponse == nil)
        #expect(FixtureHTTP.state.requests.count == 1)
    }

    @MainActor @Test func loadingConversationPublishesMetadataWithoutAnotherRequest() async throws {
        FixtureHTTP.state.configure { _ in ConversationFixture.reply }
        let service = ChatService(repository: makeRepository())
        let session = try await service.chat(id: TurnFixture.id)
        var metadata = ChatSessionMetadata()
        let token = session.metadata.sink { metadata = $0 }
        defer { token.cancel() }

        #expect(metadata.id == TurnFixture.id)
        #expect(metadata.title == "Planning")
        #expect(metadata.createdAt == Date(timeIntervalSince1970: 0))
        #expect(metadata.lastActivityAt == Date(timeIntervalSince1970: 60))
        #expect(metadata.messageCount == 20)
        #expect(metadata.usage == DexChatUsage(inputTokenCount: 600, outputTokenCount: 300,
            totalTokenCount: 900, questionsUsedCount: 4, questionsLimitCount: 10))
        #expect(session.messages.value.map(\.text) == ["Saved history"])
        #expect(FixtureHTTP.state.requests.count == 1)
    }

    @MainActor @Test(arguments: [false, true])
    func newConversationPublishesIDThenServerMetadata(streaming: Bool) async throws {
        FixtureHTTP.state.configure { request in
            if request.httpMethod == "GET" { return ConversationFixture.reply }
            return streaming ? .init(body: TurnFixture.wire) : .json(TurnFixture.rest)
        }
        let session = await ChatService(repository: makeRepository()).newChat()
        var snapshots: [ChatSessionMetadata] = []
        let token = session.metadata.sink { snapshots.append($0) }
        defer { token.cancel() }

        #expect(snapshots == [.init()])
        if streaming { try await session.sendStream(message: "Hello") }
        else { try await session.send(message: "Hello") }
        try await waitForMetadata(session, title: "Planning")

        #expect(snapshots.count == 3)
        #expect(snapshots.dropFirst().first == .init(id: TurnFixture.id))
        #expect(snapshots.last?.title == "Planning")
        #expect(snapshots.last?.usage?.totalTokenCount == 900)
        #expect(snapshots.last?.messageCount == 20)
        #expect(await session.lastResponse?.usage?.totalTokenCount == 15)
        #expect(session.messages.value.map(\.text) == ["Hello", "Γεια 👋"])
        #expect(session.messages.value.last?.delivery == .complete)
        let requests = FixtureHTTP.state.requests
        #expect(requests.map(\.httpMethod) == ["POST", "GET"])
        #expect(requests.last?.url?.path.lowercased() == "/api/my/chats/\(TurnFixture.id.uuidString.lowercased())")
    }

    @MainActor @Test(arguments: [false, true])
    func eachCompletedTurnRefreshesMetadataAndPreservesLiveMessages(streaming: Bool) async throws {
        FixtureHTTP.state.configure { _ in ConversationFixture.reply }
        let session = try await ChatService(repository: makeRepository()).chat(id: TurnFixture.id)
        var metadata = ChatSessionMetadata()
        let token = session.metadata.sink { metadata = $0 }
        defer { token.cancel() }

        for turn in 1...2 {
            let previous = session.messages.value
            FixtureHTTP.state.configure { request in
                if request.httpMethod == "GET" {
                    // Omitted ID is valid; retain the session ID. Server counts
                    // need not match the number of locally displayed messages.
                    return .json("{\"title\":\"Turn \(turn)\",\"messageCount\":\(20 + turn),\"usage\":{\"totalTokenCount\":\(900 + turn)},\"messages\":[]}")
                }
                return streaming ? .init(body: TurnFixture.wire) : .json(TurnFixture.rest)
            }
            if streaming { try await session.sendStream(message: "Next") }
            else { try await session.send(message: "Next") }
            try await waitForMetadata(session, title: "Turn \(turn)")

            #expect(metadata.id == TurnFixture.id)
            #expect(metadata.title == "Turn \(turn)")
            #expect(metadata.messageCount == 20 + turn)
            #expect(metadata.usage?.totalTokenCount == Int64(900 + turn))
            #expect(Array(session.messages.value.prefix(previous.count)) == previous)
            #expect(session.messages.value.count == previous.count + 2)
            #expect(FixtureHTTP.state.requests.map(\.httpMethod) == ["POST", "GET"])
        }
    }

    @MainActor @Test(arguments: [false, true], ["http", "decode", "wrongConversation"])
    func failedMetadataRefreshRetainsValuesAndSuccessfulReply(streaming: Bool, failure: String) async throws {
        FixtureHTTP.state.configure { _ in ConversationFixture.reply }
        let session = try await ChatService(repository: makeRepository()).chat(id: TurnFixture.id)
        var metadata = ChatSessionMetadata()
        var snapshots: [ChatSessionMetadata] = []
        let token = session.metadata.sink { metadata = $0; snapshots.append($0) }
        defer { token.cancel() }
        let previous = metadata
        FixtureHTTP.state.configure { request in
            if request.httpMethod != "GET" {
                return streaming ? .init(body: TurnFixture.wire) : .json(TurnFixture.rest)
            }
            if FixtureHTTP.state.requests.filter({ $0.httpMethod == "GET" }).count > 1 {
                return .json(#"{"title":"Updated","messageCount":24}"#)
            }
            switch failure {
            case "http": return .init(status: 503, contentType: "application/json", body: Data())
            case "decode": return .json("{broken")
            default: return .json("{\"id\":\"\(UUID())\",\"title\":\"Wrong chat\"}")
            }
        }
        if streaming { try await session.sendStream(message: "Hello") }
        else { try await session.send(message: "Hello") }

        #expect(metadata == previous)
        #expect(session.messages.value.last?.text == "Γεια 👋")
        #expect(session.messages.value.last?.delivery == .complete)
        #expect(await session.lastResponse?.text == "Γεια 👋")
        if streaming { #expect(session.streamState.value == .completed) }
        try await eventually { FixtureHTTP.state.requests.contains { $0.httpMethod == "GET" } }
        if streaming { try await session.sendStream(message: "Continue") }
        else { try await session.send(message: "Continue") }
        try await waitForMetadata(session, title: "Updated")
        #expect(snapshots.count == 2)
        #expect(snapshots.first == previous)
        #expect(snapshots.last?.title == "Updated")
    }

    @MainActor @Test(arguments: [false, true])
    func slowMetadataRefreshAllowsNextTurnAndDiscardsStaleResult(streaming: Bool) async throws {
        let gate = ReplyGate()
        defer { Task { await gate.open() } }
        FixtureHTTP.state.configure { request in
            if request.httpMethod == "GET" {
                if FixtureHTTP.state.requests.filter({ $0.httpMethod == "GET" }).count == 1 {
                    var reply = FixtureHTTP.Reply.json(#"{"title":"Stale","messageCount":2}"#)
                    reply.gate = gate
                    return reply
                }
                return ConversationFixture.reply
            }
            return streaming ? .init(body: TurnFixture.wire, keepOpen: true) : .json(TurnFixture.rest)
        }
        let session = await ChatService(repository: makeRepository()).newChat()
        var snapshots: [ChatSessionMetadata] = []
        let token = session.metadata.sink { snapshots.append($0) }
        defer { token.cancel() }
        if streaming { try await session.sendStream(message: "Hello") }
        else { try await session.send(message: "Hello") }
        try await eventually { FixtureHTTP.state.requests.contains { $0.httpMethod == "GET" } }
        #expect(session.messages.value.last?.delivery == .complete)
        if streaming {
            #expect(session.streamState.value == .completed)
            try await eventually { FixtureHTTP.state.stopCount > 0 }
        }
        if streaming { try await session.sendStream(message: "Continue") }
        else { try await session.send(message: "Continue") }
        #expect(FixtureHTTP.state.requests.filter { $0.httpMethod == "GET" }.count == 1)
        #expect(snapshots.last == .init(id: TurnFixture.id))
        await gate.open()
        try await waitForMetadata(session, title: "Planning")
        #expect(!snapshots.contains { $0.title == "Stale" })
        #expect(FixtureHTTP.state.requests.filter { $0.httpMethod == "GET" }.count == 2)
        #expect(session.messages.value.count == 4)
        #expect(session.messages.value.allSatisfy { $0.delivery == .complete })
    }

    @Test func restRepositoriesUseCorrectPathsAndBodies() async throws {
        FixtureHTTP.state.configure { request in
            let path = request.url!.path
            if request.httpMethod == "DELETE" || path.hasSuffix("/like") || path.hasSuffix("/clear") { return .init(status: 204, contentType: "application/json", body: Data()) }
            if path == "/api/agents" { return .json("[]") }
            if path == "/api/my/chats", request.httpMethod == "GET" { return .json(#"{"count":"0","items":[]}"#) }
            return .json("{}")
        }
        let client = mockClient()
        let chat = makeRepository(client: client)
        _ = try await chat.chats(paging: .init(page: 1000, size: 2000, sort: "title-"), filter: .init(search: "a & b"))
        _ = try await chat.session(forChatId: TurnFixture.id)
        _ = try await chat.create(chatRequest: .init(text: "Hi", authorName: "Me", agentName: "support"))
        _ = try await chat.send(message: .init(text: "Again"), onChatId: TurnFixture.id)
        try await chat.like(chatID: TurnFixture.id, messageID: TurnFixture.id, request: .init(like: nil))
        try await chat.delete(chatId: TurnFixture.id)
        _ = try await AgentsRepository(endpoint: endpoint, client: client).agents()
        let profile = ProfileRepository(endpoint: endpoint, client: client)
        _ = try await profile.profile()
        _ = try await profile.profile(updateRequest: .init(preferredLanguage: "el", responseStyle: "concise", preferredCategories: ["FAQ"]))
        try await DocumentsRepository(endpoint: endpoint, client: client).clear()
        let requests = FixtureHTTP.state.requests
        #expect(requests.count == 10)
        let query = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first { $0.name == "page" }?.value == "1000")
        #expect(query?.first { $0.name == "size" }?.value == "2000")
        #expect(query?.first { $0.name == "search" }?.value == "a & b")
        #expect(query?.first { $0.name == "sort" }?.value == "title-")
        #expect(requests[1].url?.path.lowercased() == "/api/my/chats/\(TurnFixture.id.uuidString.lowercased())")
        #expect(requests[2].httpMethod == "POST")
        #expect(try APIJSON.decoder().decode(ChatRequest.self, from: #require(requests[2].httpBody)).agentName == "support")
        #expect(requests[3].url?.path.hasSuffix("/messages") == true)
        #expect(requests[4].httpMethod == "PUT")
        let feedback = try JSONSerialization.jsonObject(with: #require(requests[4].httpBody)) as? [String: Any]
        #expect(feedback?["like"] is NSNull)
        #expect(requests[5].httpMethod == "DELETE")
        #expect(requests[7].url?.path == "/api/my/profile")
        #expect(requests[8].httpMethod == "PUT")
        #expect(requests[9].url?.path == "/api/documents/clear")
    }

    @Test func multipartAndBinarySourcesUseNetworkClient() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try Data("# Knowledge".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let binary = Data([0x89, 0x50, 0x4e, 0x47, 0, 255])
        FixtureHTTP.state.configure { request in
            if request.url?.path == "/api/documents/ingest" { return .json(#"{"chunksCreated":"2","skipped":false}"#) }
            return .init(contentType: "image/png", body: binary)
        }
        let client = mockClient()
        let documents = DocumentsRepository(endpoint: endpoint, client: client)
        let report = try await documents.ingest(request: .init(documentType: .markdown, category: "FAQ", language: "el", markdownSourceFile: .init(fileURL: source, fileName: "knowledge.md", contentType: "text/markdown"), actualSourceUrl: "https://example.com/source", isPrivate: true))
        #expect(report.chunksCreated == 2)
        _ = try await documents.ingest(request: .init(markdownSourceFile: .init(fileURL: source), actualSourceFile: .init(fileURL: source, fileName: "original.md")))
        let sources = SourcesRepository(endpoint: endpoint, client: client)
        let resource = try await sources.source(path: "folder/file name#.md", download: true)
        #expect(resource.data == binary)
        #expect(resource.contentType == "image/png")
        _ = try await sources.favicon(sourceID: TurnFixture.id)
        _ = try await sources.favicon(domain: "example.com")
        let requests = FixtureHTTP.state.requests
        let multipart = String(decoding: try #require(requests[0].httpBody), as: UTF8.self)
        #expect(multipart.contains("name=\"markdownSourceFile\""))
        #expect(multipart.contains("filename=\"knowledge.md\""))
        #expect(multipart.contains("name=\"actualSourceUrl\""))
        #expect(multipart.contains("name=\"isPrivate\""))
        #expect(multipart.contains("true"))
        #expect(multipart.contains("Markdown"))
        #expect(String(decoding: try #require(requests[1].httpBody), as: UTF8.self).contains("name=\"actualSourceFile\""))
        #expect(requests[2].url?.path == "/api/sources/folder/file name#.md")
        #expect(requests[2].url?.fragment == nil)
        #expect(requests[2].url?.query == "download=true")
        #expect(requests[3].url?.path.hasSuffix("/favicon") == true)
        #expect(requests[4].url?.query == "domain=example.com")
        await #expect(throws: AgentsError.self) { try await sources.source(path: "../escape") }
    }

    private var endpoint: URL { URL(string: "https://agents-fixture.test")! }
    private func mockClient() -> NetworkClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureHTTP.self]
        return NetworkClient(decoder: AgentsResponseDecoder(), session: URLSession(configuration: configuration))
    }
    private func makeRepository(client: NetworkClient? = nil, auth: StreamAuthorization? = nil) -> ChatRepository {
        .init(endpoint: endpoint, client: client ?? mockClient(), streamAuthorization: auth ?? StreamAuthorization(credentials: { ("Bearer fixture", false) }, refresh: {}))
    }
}

@MainActor
private func waitForMetadata(_ session: ChatSessionService, title: String) async throws {
    var current: ChatSessionMetadata?
    let token = session.metadata.sink { current = $0 }
    defer { token.cancel() }
    try await eventually { await MainActor.run { current?.title == title } }
}

private actor ReplyGate {
    private var isOpen = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}

private enum ConversationFixture {
    static let reply = FixtureHTTP.Reply.json("""
        {"id":"\(TurnFixture.id)","title":"Planning","createdAt":"1970-01-01T00:00:00Z",
        "lastActivityAt":"1970-01-01T00:01:00Z","messageCount":20,
        "usage":{"inputTokenCount":600,"outputTokenCount":300,"totalTokenCount":900,
        "questionsUsedCount":4,"questionsLimitCount":10},
        "messages":[{"role":"assistant","content":{"parts":[{"value":"Saved history","contentType":"text/plain"}]}}]}
        """)
}

private func eventually(_ predicate: @escaping @Sendable () async -> Bool) async throws {
    for _ in 0..<400 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for fixture condition")
    throw AgentsError.invalidStream("Fixture timeout")
}

private final class Credentials: @unchecked Sendable {
    private let lock = NSLock()
    private var header = "Bearer old"
    private var expired: Bool
    private var count = 0
    init(expired: Bool = false) { self.expired = expired }
    var snapshot: (header: String?, expired: Bool) { lock.withLock { (header, expired) } }
    var refreshCount: Int { lock.withLock { count } }
    func refreshed() { lock.withLock { count += 1; header = "Bearer new"; expired = false } }
}

private final class FixtureHTTP: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable {
        var status = 200
        var contentType = "text/event-stream"
        var body: Data
        var keepOpen = false
        var delayChunks = false
        var gate: ReplyGate?
        static func json(_ string: String) -> Reply { .init(contentType: "application/json", body: Data(string.utf8)) }
    }
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var handler: @Sendable (URLRequest) -> Reply = { _ in .json("{}") }
        private var recorded: [URLRequest] = []
        private var stops = 0
        var requests: [URLRequest] { lock.withLock { recorded } }
        var stopCount: Int { lock.withLock { stops } }
        func configure(_ handler: @escaping @Sendable (URLRequest) -> Reply) {
            lock.withLock { self.handler = handler; recorded = []; stops = 0 }
        }
        func reply(for request: URLRequest) -> Reply {
            let callback = lock.withLock { recorded.append(request); return handler }
            return callback(request)
        }
        func stopped() { lock.withLock { stops += 1 } }
    }
    static let state = State()
    private let lock = NSLock()
    private var operation: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "agents-fixture.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let input = captured.httpBodyStream {
            input.open()
            defer { input.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while input.hasBytesAvailable {
                let size = input.read(&buffer, maxLength: buffer.count)
                if size <= 0 { break }
                body.append(contentsOf: buffer.prefix(size))
            }
            captured.httpBody = body
        }
        let reply = Self.state.reply(for: captured)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": reply.contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        lock.withLock {
            operation = Task { @Sendable [self, reply] in
                if let gate = reply.gate { await gate.wait() }
                // Small chunks deliberately split UTF-8 sequences and SSE lines.
                for offset in stride(from: 0, to: reply.body.count, by: 13) {
                    if Task.isCancelled { return }
                    self.client?.urlProtocol(self, didLoad: reply.body.subdata(in: offset..<min(offset + 13, reply.body.count)))
                    if reply.delayChunks { try? await Task.sleep(for: .milliseconds(1)) }
                }
                if !reply.keepOpen, !Task.isCancelled { self.client?.urlProtocolDidFinishLoading(self) }
            }
        }
    }
    override func stopLoading() {
        lock.withLock { operation?.cancel() }
        Self.state.stopped()
    }
}
