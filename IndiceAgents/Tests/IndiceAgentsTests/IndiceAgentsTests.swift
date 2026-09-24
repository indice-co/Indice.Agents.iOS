import Foundation
import Testing
import AgentsModels
import IdentityClient
@testable import IndiceAgents

@Test func modelContract() throws {
    let json = #"{"conversationId":"9c205432-4b5b-4d44-a969-f1470206c973","messages":[{"messageId":"opaque-message-id","role":"assistant","content":{"parts":[{"value":"Γεια 👋","contentType":"text/markdown"}]},"citations":[{"score":"0.75","number":"1"}],"sources":[]}],"usage":{"totalTokenCount":"9223372036854775807"},"createdAt":"2026-09-23T09:00:00.1234567+03:00","finishReason":"stop","text":"Γεια 👋"}"#
    let response = try APIJSON.decoder().decode(DexChatResponse.self, from: Data(json.utf8))
    #expect(response.messages?.first?.messageId == "opaque-message-id")
    #expect(response.messages?.first?.citations?.first?.score == 0.75)
    #expect(response.usage?.totalTokenCount == Int64.max)
    #expect(response.createdAt != nil)
    #expect(response.finishReason == .stop)
    #expect(try APIJSON.decoder().decode(Profile.self, from: Data(#"{"createdAt":"2026-09-23T06:00:00Z"}"#.utf8)).createdAt != nil)
    #expect(throws: DecodingError.self) { try APIJSON.decoder().decode(GuestSession.self, from: Data("{}".utf8)) }
    #expect(throws: DecodingError.self) { try APIJSON.decoder().decode(DexChatUsage.self, from: Data(#"{"totalTokenCount":"nonsense"}"#.utf8)) }
    #expect(throws: DecodingError.self) { try APIJSON.decoder().decode(AgentInfo.self, from: Data("{}".utf8)) }
}

@Test func requestAndDiscoveryRoundTrip() throws {
    let request = ChatRequest(text: "hello", authorName: "Reader", agentName: "support")
    #expect(try APIJSON.decoder().decode(ChatRequest.self, from: APIJSON.encoder().encode(request)) == request)
    let agent = AgentInfo(name: "support", description: "Help", inputContentTypes: ["text/plain"], outputContentTypes: ["text/markdown"], metadata: ["enabled": .bool(true), "version": .integer(2)])
    #expect(try APIJSON.decoder().decode(AgentInfo.self, from: APIJSON.encoder().encode(agent)) == agent)
    let feedback = try JSONSerialization.jsonObject(with: APIJSON.encoder().encode(LikeRequest(like: nil))) as? [String: Any]
    #expect(feedback?["like"] is NSNull)
    #expect(DocumentType.markdown.rawValue == "Markdown")
    let problems = try APIJSON.decoder().decode(HttpValidationProblemDetails.self, from: Data(#"{"status":"400","errors":{"text":["Required"]}}"#.utf8))
    #expect(problems.status == 400)
    #expect(problems.errors?["text"] == ["Required"])
}

@Test func arbitraryJSONAndFrameDiscriminators() throws {
    let json = #"{"type":"delta","path":"/usage","op":"add","value":{"count":9223372036854775807,"fraction":0.125,"items":[true,null,"text"]}}"#
    let frame = try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: Data(json.utf8))
    #expect(try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: APIJSON.encoder().encode(frame)) == frame)
    let future = Data(#"{"type":"future","extra":[1,false]}"#.utf8)
    let unknown = try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: future)
    guard case .unknown(let type, _) = unknown else { Issue.record("Unknown type was not preserved"); return }
    #expect(type == "future")
    #expect(try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: APIJSON.encoder().encode(unknown)) == unknown)
    #expect(throws: DecodingError.self) { try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: Data(#"{"type":"error"}"#.utf8)) }
}

@Test func sseFramingHandlesUnicodeCRLFMetadataAndMultilineData() throws {
    let wire = "\u{FEFF}: heartbeat\r\nid: 42\r\nretry: 1200\r\nevent: delta\r\ndata: {\r\ndata:  \"text\":\"Γεια 👋\"}\r\n\r\ndata: next\r\r"
    var parser = SSEParser()
    var frames: [SSEParser.Frame] = []
    for byte in wire.utf8 { if let frame = try parser.consume(byte) { frames.append(frame) } }
    #expect(frames.count == 2)
    #expect(String(decoding: frames[0].data, as: UTF8.self) == "{\n \"text\":\"Γεια 👋\"}")
    #expect(frames[0].eventType == "delta")
    #expect(frames[1].eventType == "message")
    #expect(frames[1].eventID == "42")
    #expect(frames[1].retryMilliseconds == 1200)
}

@Test func sseIgnoresCommentsUnknownFieldsAndIncompleteTail() throws {
    var parser = SSEParser()
    let wire = ": comment\nunknown: x\nid: a\n\nid: bad\0id\nretry: invalid\ndata:\n\nid:\ndata: ok\n\ndata: incomplete"
    var frames: [SSEParser.Frame] = []
    for byte in wire.utf8 { if let frame = try parser.consume(byte) { frames.append(frame) } }
    #expect(frames.count == 2)
    #expect(frames[0].data.isEmpty)
    #expect(frames[0].eventID == "a")
    #expect(frames[1].eventID == "")
    #expect(frames[1].retryMilliseconds == nil)
}

@Test func sseRejectsInvalidUTF8AndOversizedFrames() throws {
    var parser = SSEParser()
    _ = try parser.consume(0xFF)
    #expect(throws: SSEError.self) { try parser.consume(10) }
    var small = SSEParser(maximumFrameBytes: 4)
    for byte in "data".utf8 { _ = try small.consume(byte) }
    #expect(throws: SSEError.self) { try small.consume(58) }
}

@Test func patchCompactionArraysEscapesAndRoot() throws {
    var patcher = JSONPointerPatcher()
    var document: JSONValue = .object([:])
    try patcher.apply(.init(path: "/items", op: .add, value: .array([])), to: &document)
    try patcher.apply(.init(path: "/items/-", value: .string("world")), to: &document)
    try patcher.apply(.init(path: "/items/0", value: .string("Hello")), to: &document)
    try patcher.apply(.init(op: .append, value: .string(" ")), to: &document)
    try patcher.apply(.init(value: .string("there")), to: &document)
    try patcher.apply(.init(path: "/a~1b~0", op: .add, value: .bool(true)), to: &document)
    #expect(document == .object(["items": .array([.string("Hello there"), .string("world")]), "a/b~": .bool(true)]))
    try patcher.apply(.init(path: "", op: .replace, value: .object(["replaced": .bool(true)])), to: &document)
    #expect(document == .object(["replaced": .bool(true)]))
    try patcher.apply(.init(path: "/replaced", value: nil), to: &document)
    #expect(document == .object(["replaced": .null]))
}

@Test func invalidPatchesFailInsteadOfCorruptingResponse() throws {
    var patcher = JSONPointerPatcher()
    var document: JSONValue = .object([:])
    #expect(throws: AgentsError.self) { try patcher.apply(.init(value: .string("x")), to: &document) }
    #expect(throws: AgentsError.self) { try patcher.apply(.init(path: "/missing", op: .replace, value: .null), to: &document) }
    #expect(throws: AgentsError.self) { try patcher.apply(.init(path: "/invalid~2", op: .add, value: .null), to: &document) }
    try patcher.apply(.init(path: "/items", op: .add, value: .array([])), to: &document)
    #expect(throws: AgentsError.self) { try patcher.apply(.init(path: "/items/2", value: .null), to: &document) }
    #expect(throws: AgentsError.self) { try patcher.apply(.init(path: "/items", op: .append, value: .string("x")), to: &document) }
}

@Test func assembledStreamMatchesRESTResponse() throws {
    var assembler = ChatStreamAssembler()
    var completed: DexChatResponse?
    for frame in try TurnFixture.frames() {
        if case .completed(let response) = try assembler.consume(frame) { completed = response }
    }
    let expected = try APIJSON.decoder().decode(DexChatResponse.self, from: Data(TurnFixture.rest.utf8))
    #expect(completed == expected)
    #expect(assembler.isComplete)
    #expect(throws: AgentsError.self) { try assembler.consume(.done(.init())) }
}

@Test func terminalFailureAndPrematureCompletion() throws {
    var assembler = ChatStreamAssembler()
    _ = try assembler.consume(.start(.init(conversationId: TurnFixture.id)))
    _ = try assembler.consume(.unknown(type: "future", payload: .object([:])))
    #expect(throws: AgentsError.self) { try assembler.consume(.done(.init())) }
    #expect(!assembler.isComplete)
    #expect(throws: AgentsError.self) { try assembler.consume(.error(.init(reason: "Unavailable"))) }
    #expect(!assembler.isComplete)
    var noStart = ChatStreamAssembler()
    #expect(throws: AgentsError.self) { try noStart.consume(.status(.init(value: "Working"))) }
}

@Test func limitResponseIsCompleteWithoutPersistedMessageID() throws {
    var assembler = ChatStreamAssembler()
    _ = try assembler.consume(.start(.init(conversationId: TurnFixture.id)))
    let response = DexChatResponse(messages: [.init(role: .assistant, content: .init(parts: [.init(value: "Limit reached", contentType: "text/plain")]))], finishReason: .limit, limitReached: true)
    let json = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(response))
    _ = try assembler.consume(.delta(.init(path: "", op: .add, value: json)))
    guard case .completed(let final) = try assembler.consume(.done(.init())) else { Issue.record("Expected completion"); return }
    #expect(final.limitReached == true)
    #expect(final.text == "Limit reached")
    #expect(final.messages?.first?.messageId == nil)
}

enum TurnFixture {
    static let id = UUID(uuidString: "9c205432-4b5b-4d44-a969-f1470206c973")!
    static let payloads = [
        #"{"type":"start","conversationId":"9c205432-4b5b-4d44-a969-f1470206c973"}"#,
        #"{"type":"status","value":"Retrieving context"}"#,
        #"{"type":"delta","path":"/conversationId","op":"add","value":"9c205432-4b5b-4d44-a969-f1470206c973"}"#,
        #"{"type":"delta","path":"/messages","value":[{"role":"assistant","content":{"parts":[]}}]}"#,
        #"{"type":"delta","path":"/messages/0/content/parts/-","value":{"value":"","contentType":"text/markdown"}}"#,
        #"{"type":"delta","path":"/messages/0/content/parts/0/value","op":"append","value":"Γεια "}"#,
        #"{"type":"future","extra":true}"#,
        #"{"type":"status","value":"Writing answer"}"#,
        #"{"type":"delta","value":"👋"}"#,
        #"{"type":"delta","path":"/messages/0/messageId","op":"add","value":"opaque-id"}"#,
        #"{"type":"delta","path":"/messages/0/citations","value":[{"title":"Source","score":0.9,"number":1}]}"#,
        #"{"type":"delta","path":"/messages/0/sources","value":[{"fileName":"source.md","sourceUrl":"https://example.com/source"}]}"#,
        #"{"type":"delta","path":"/responseId","value":"response-1"}"#,
        #"{"type":"delta","path":"/modelId","value":"example-model"}"#,
        #"{"type":"delta","path":"/createdAt","value":"2026-09-23T06:00:00.123Z"}"#,
        #"{"type":"delta","path":"/finishReason","value":"stop"}"#,
        #"{"type":"delta","path":"/usage","value":{"inputTokenCount":"12","outputTokenCount":3,"totalTokenCount":15}}"#,
        #"{"type":"delta","path":"/limitReached","value":false}"#,
        #"{"type":"done"}"#
    ]
    static var wire: Data { Data(payloads.map { "data: \($0)\r\n\r\n" }.joined().utf8) }
    static func frames() throws -> [DexChatResponseUpdate] {
        try payloads.map { try APIJSON.decoder().decode(DexChatResponseUpdate.self, from: Data($0.utf8)) }
    }
    static let rest = #"{"conversationId":"9c205432-4b5b-4d44-a969-f1470206c973","responseId":"response-1","messages":[{"messageId":"opaque-id","role":"assistant","content":{"parts":[{"value":"Γεια 👋","contentType":"text/markdown"}]},"citations":[{"title":"Source","score":0.9,"number":1}],"sources":[{"fileName":"source.md","sourceUrl":"https://example.com/source"}]}],"modelId":"example-model","createdAt":"2026-09-23T06:00:00.123Z","finishReason":"stop","usage":{"inputTokenCount":12,"outputTokenCount":3,"totalTokenCount":15},"limitReached":false,"text":"Γεια 👋"}"#
}

@Test func numericStringsRemainStringsInArbitraryJSON() throws {
    #expect(try APIJSON.decoder().decode(JSONValue.self, from: Data(#""42""#.utf8)) == .string("42"))
    #expect(throws: DecodingError.self) { try APIJSON.decoder().decode(Citation.self, from: Data(#"{"score":"NaN"}"#.utf8)) }
    #expect(try APIJSON.decoder().decode(ConversationListItemResultSet.self, from: Data(#"{"count":"1000","items":[]}"#.utf8)).count == 1000)
}

@Test func ingestionScopeIsOptIn() throws {
    let pkce = PKCE.generateData().pkce
    let regular = AgentsClient().createLoginURL(for: pkce)
    let ingestion = AgentsClient(requestIngestionScope: true).createLoginURL(for: pkce)
    func scopes(_ url: URL) -> [Substring] {
        (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "scope" }?.value ?? "").split(separator: " ")
    }
    #expect(!scopes(regular).contains("ingest"))
    #expect(scopes(regular).contains("chat"))
    #expect(scopes(ingestion).contains("ingest"))
}
