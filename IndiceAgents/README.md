# IndiceAgents

`AgentsModels` contains raw Codable/Sendable API values. Every API payload adopts
`APIModel`. `IndiceAgents` contains internal repositories, the service actors, and
`AgentsClient`, the consumer entry point. Ordinary requests keep using Indice
NetworkClient 1.5.2 and its URLRequest builder.

## Using the services

```swift
import IndiceAgents
import AgentsModels

let agents = AgentsClient()
// Complete the existing login flow before making API calls.
let available = try await agents.agentsService.agents()
let page = try await agents.chatsService.chats(
    paging: .init(page: 1, size: 20, sort: "lastActivityAt-"),
    filter: .init(search: "support")
)
let profile = try await agents.profileService.profile()
```

The existing showcase identity configuration and service URLs remain the default.
Document ingestion/clearing additionally requires the `ingest` OAuth scope. Opt in
before login with `AgentsClient(requestIngestionScope: true)` when the identity
client registration and user have that permission. Default chat login scopes do
not change. Guest response payloads are modeled; guest authentication is not
implemented in this version.

For source files use `sourcesService.source(path:download:)`. The result contains
raw bytes, content type, suggested filename, and final URL. Favicon methods return
the same result and use NetworkClient's normal redirect handling.

Document ingestion takes `DocumentIngestRequest`. `FileParam` describes a **local
file**, filename, and MIME type; the repository sends its bytes in multipart form.
Its Codable representation is for local storage, not a JSON upload body. The API
requires `markdownSourceFile`; `actualSourceFile` and `actualSourceUrl` are mutually
exclusive. An ingestion convenience method accepts a local markdown URL.

## Streaming a conversation

```swift
let conversation = await agents.chatsService.newChat()
// On MainActor, subscribe to conversation.messages and conversation.streamState.
// Subscribe before starting the task to see the first reply grow.
let task = Task {
    try await conversation.sendStream(
        request: .init(text: "Hello", agentName: available.first?.name)
    )
}
// task.cancel() stops the current reply and closes its connection.
```

Both new chats and follow-ups use the same session service. `send(request:)`
provides the non-streaming alternative. `chat(id:)` loads existing history.
Messages have a stable local UUID for display and a separate optional server
`messageId` string. The feedback endpoint requires a persisted UUID message ID;
pass a UUID only when the server's message ID can be converted to one. `like: true`
likes, `false` dislikes, and `nil` clears feedback.

Service observation uses MainActor Combine subjects. `messages` publishes content
parts as they grow; `streamState` publishes transient progress labels and terminal
states. A completed response is also available as `lastResponse`. Only `done`
commits a streamed response. Cancellation/disconnection preserves visible partial
text with an incomplete delivery state; a server `error` frame discards the failed
answer. One send at a time is allowed per session. Cancel the task before starting
another turn. The showcase demonstrates first-turn streaming, progress, stopping,
and incomplete reply labels.

Incoming patches are applied in order on a separate actor, independently of UI
rendering. The service materializes and publishes the accumulated response at
75 ms intervals while it changes, coalescing progress labels too. A slow UI has
only one publication in flight; newer patches remain in the accumulator. `done`
flushes immediately. Cancellation and disconnection also preserve changes that
have not reached a presentation tick. Timer tasks finish before terminal state
is published, so they cannot overwrite completion or a later turn.

## Rendering message content

Use each service message's `items` array to render the ordered `content.parts`.
A single message can contain text, an HTML card, an image, and more text. Each
`ChatContentItem` has an ID (its part index), optional caption, and a `content` enum:

```swift
for item in message.items {
    switch item.content {
    case .text(let text): /* plain text component */ break
    case .markdown(let markdown): /* Markdown component */ break
    case .html(let html): /* HTML component */ break
    case .imageData(let data, let mediaType): /* decoded image bytes */ break
    case .imageURL(let url): /* remote image component */ break
    case .multipleChoice(let choice): /* choice.options */ break
    case .callout(let callout): /* callout.severity, title, text */ break
    case .confirmation(let confirmation): /* prompt, confirmText, cancelText */ break
    case .unsupported(let mediaType): /* custom component or placeholder */ break
    case .unavailable(let mediaType): /* loading/error placeholder */ break
    }
}
```

The mapper decodes whole data URIs: `data:text/html;base64,...` becomes `.html`,
whereas `data:image/png;base64,...` becomes `.imageData`. It also handles literal
HTML, percent-encoded data URIs, and the web client's image JSON envelope. It uses
the API's part boundaries rather than scanning or splitting ordinary prose.
`ChatContentMapper.items(for:)` is also available when working with raw models.

The raw API payload remains in `message.value`. `message.text` is a prose-only
convenience for previews; rendering it alone intentionally omits HTML and images.
Part IDs stay stable during appended text, and unchanged decoded parts are reused
between streaming updates. Malformed or incomplete encoded content gets an
unavailable item instead of exposing the encoded bytes as chat text. Data URI
payloads are limited to 8 MiB after decoding.

The showcase provides native text, inline Markdown, local/remote images, and an
automatically sized HTML view. HTML uses isolated, nonpersistent WebKit storage,
disabled content scripts, and restricted resource loading. Links open externally
only on a tap. Callouts, confirmations, and multiple-choice prompts have typed
payloads and separate `EmptyView()` branches in `ChatContentItemView`, ready for
host-provided UIs. When implementing selection actions, send the chosen label
verbatim as the next user message.
The mapper matches the web defaults: unknown callout severity becomes `info`,
confirmation labels default to Yes/No, and blank/non-string options are ignored.
Other custom media types produce an unsupported-content placeholder. Original
values remain available in `message.value.content?.parts`, indexed by `item.id`.

## Moving SSE support into NetworkClient later

The implementation contains detailed comments at the transport boundaries:

1. **`Streaming/NetworkClient+SSE.swift`** opens a fully prepared request through
   `URLSession.shared.bytes(for:)`, validates HTTP headers, and starts a byte-reading
   task. It does not access NetworkClient internals, interceptors, task storage,
   logging, decoders, or error mapping. Initial HTTP errors throw before returning
   the sequence; later errors arrive through iteration. The caller supplies a
   fresh JSON decoder factory.
2. **`Streaming/SSEParser.swift`** turns arbitrary byte fragments into SSE frames.
   It handles CR/LF/CRLF, UTF-8/BOM, comments, multiline data, `event`, `id`, and
   `retry`. Only a blank line commits an event. Incomplete data at EOF is discarded.
   SSE `event:` metadata and the JSON payload's `type` are distinct.
3. **`Streaming/ServerSentEvent.swift`** carries the typed payload and metadata and
   owns cancellation. The iterator retains the connection lifetime, including when
   iterating a temporary sequence. Cancel explicitly on an early exit; dropping all
   owners also cancels. `SSEEventChannel` buffers up to 32 events and targets a
   512 KiB payload budget, suspending the producer when full. It never drops
   patches because a consumer is slow. One larger frame may occupy the queue by
   itself; individual frames are limited to 8 MiB, and a suspended producer may
   retain one additional frame. Payload bytes are a queue budget, not a bound on
   decoded object memory, the assembled response, or URLSession's own buffers.
4. **`Streaming/StreamAuthorization.swift`** stays in Agents: it attaches the current
   IdentityClient credential and coalesces stream token refreshes. ChatRepository
   retries one rejected HTTP handshake after refreshing. It never replays an
   established stream. `retry` and `id` metadata do not enable automatic reconnects
   because these POSTs create chat turns.
5. **`Streaming/ChatStreamAssembler.swift`** also stays in Agents. It interprets
   start/status/delta/error/done and applies JSON Pointer patches. Missing/null
   path and op inherit their previous effective values; an empty path denotes the
   document root. Value never inherits. Unknown frame types are ignored. The bare
   done event commits the response already assembled from patches. The backend
   omits computed `text` from patches, so the assembler derives it from the parts.

The transport uses a single-consumer async sequence. Do not iterate a stream twice.
Normal HTTP errors retain status and a bounded response body in `SSEError.http`;
401 bodies are not read before the credential retry. The transport intentionally
has no automatic reconnection, login, or chat-specific termination policy.

## Contract source and compatibility

The supplied September 23 `agents.json` defines endpoint/model scope. Its five-way
stream discriminator agrees with the backend and web patch implementation. The
older streaming prose in endpoint descriptions is stale. Patch values are modeled
as arbitrary JSON even though OpenAPI describes the .NET `object` value narrowly.
Backend-only additions such as `ChatRequest.topic` are intentionally not included.

Raw names now follow the current contract (`DexConversation`, `DexChatResponse`,
`DexChatMessage`, `ConversationListItem`); obsolete Session/ChatResponse models are
removed. `ConversationListItemResultSet` aliases the shared `ResultSet` in
AgentsModels. `DexChatStreamStart` and the other concrete frame types also have
aliases matching OpenAPI's longer generated names. Use `APIJSON.decoder()` and
`APIJSON.encoder()` when decoding/encoding raw models outside the client to get the
same ISO date handling. Quoted numeric values are accepted by model decoding.

## Verification

Run `swift test` from this package. Tests cover raw contracts, SSE framing and
fragmentation, JSON Pointer compaction, streamed/REST response parity, errors,
cancellation, token refresh, request construction, multipart upload names, binary
resources, typed content ordering, data URI decoding, and partial content updates.
Streaming tests also cover queue capacity/byte budgets, slow consumers, large
bursts, pending publication acknowledgements, and timer/terminal flushing.
Transport tests use a local URLProtocol fixture while exercising
`URLSession.shared`; they do not call or mutate the live Agents backend.
