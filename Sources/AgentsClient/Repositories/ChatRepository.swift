import Foundation
import AgentsModels

internal struct ChatRepository: Sendable {
    let endpoint: URL
    let client: AgentsClient.NetworkProcessor

    func create(chatRequest: ChatRequest) async throws -> DexChatResponse {
        try await client.fetch(request: .builder()
            .post(url: endpoint.appendingPathComponent("api/my/chats"))
            .bodyJson(of: chatRequest)
            .build()).item
    }

    func createOnStream(chatRequest: ChatRequest) async throws -> MessageStream {
        try await openStream(request: .builder()
            .post(url: endpoint.appendingPathComponent("api/my/chats/stream"))
            .bodyJson(of: chatRequest)
            .build())
    }

    func delete(chatId: UUID) async throws {
        try await client.fetch(request: .builder()
            .delete(url: endpoint.appendingPathComponent("api/my/chats/\(chatId)"))
            .build()).item
    }

    func chats(paging: PagingOptions, filter: FilterOptions?) async throws -> ResultSet<ConversationListItem> {
        try await client.fetch(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/my/chats"))
            .add(paging: paging)
            .add(query: "search", value: filter?.search)
            .build()).item
    }

    func session(forChatId chatID: UUID) async throws -> DexConversation {
        try await client.fetch(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/my/chats/\(chatID)"))
            .build()).item
    }

    func send(message: ChatRequest, onChatId chatID: UUID) async throws -> DexChatResponse {
        try await client.fetch(request: .builder()
            .post(url: endpoint.appendingPathComponent("api/my/chats/\(chatID)/messages"))
            .bodyJson(of: message)
            .build()).item
    }

    func like(chatID: UUID, messageID: DexChatMessage.ID, request: LikeRequest) async throws {
        try await client.fetch(request: .builder()
            .put(url: endpoint.appendingPathComponent("api/my/chats/\(chatID)/messages/\(messageID)/like"))
            .bodyJson(of: request)
            .build()).item
    }

    func streamOnMessage(message: ChatRequest, onChatId chatID: UUID) async throws -> MessageStream {
        try await openStream(request: .builder()
            .post(url: endpoint.appendingPathComponent("api/my/chats/\(chatID)/messages/stream"))
            .bodyJson(of: message)
            .build())
    }

    private func openStream(request: URLRequest) async throws -> MessageStream {
        try await client
            .openSSEStream(DexChatResponseUpdate.self, request: request)
            .item
        // try await client.openSSEStream(DexChatResponseUpdate.self, request: authorized, decoder: APIJSON.decoder)
    }
}
