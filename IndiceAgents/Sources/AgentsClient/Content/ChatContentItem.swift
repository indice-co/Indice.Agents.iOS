import Foundation
import AgentsModels

/// A presentation value, separate from the raw API's ChatMessagePart. One message
/// can contain many of these, in exactly the order of `content.parts`.
public struct ChatContentItem: Sendable, Equatable, Identifiable {
    /// The part's position in its message. It remains stable while text is appended
    /// to that part and while subsequent parts arrive during streaming.
    public let id: Int
    public let content: Content
    public let caption: String?

    public enum Content: Sendable, Equatable {
        case text(String)
        case markdown(String)
        /// Decoded markup, whether the API sent literal HTML or an HTML data URI.
        case html(String)
        /// Already decoded bytes. Base64 is a wire encoding, not an image format;
        /// the media type distinguishes PNG/JPEG/SVG/etc. for the chosen renderer.
        case imageData(Data, mediaType: String)
        case imageURL(URL)
        case multipleChoice(MultipleChoice)
        case callout(Callout)
        case confirmation(Confirmation)
        /// Retained as a distinct item so a consumer can provide another renderer.
        case unsupported(mediaType: String?)
        /// A known content kind whose payload cannot currently be decoded. During
        /// streaming this may be temporary; encoded payloads never become prose.
        case unavailable(mediaType: String?)
    }
}

/// Maps API parts to view-independent content. It performs no networking and does
/// not depend on UIKit, SwiftUI or WebKit; each host chooses its own components.
public enum ChatContentMapper {
    public static func items(for content: ChatMessageContent?) -> [ChatContentItem] {
        items(for: content, previousParts: [], previousItems: [])
    }

    // Reuse unchanged parts when a later text delta arrives. Decoding a large
    // image again for every following token would waste CPU and allocation work.
    static func items(for content: ChatMessageContent?, previousParts: [ChatMessagePart], previousItems: [ChatContentItem]) -> [ChatContentItem] {
        (content?.parts ?? []).enumerated().map { index, part in
            if previousParts.indices.contains(index), previousItems.indices.contains(index), previousParts[index] == part {
                return previousItems[index]
            }
            let parsed = classify(part)
            return ChatContentItem(id: index, content: parsed.content, caption: parsed.caption)
        }
    }

    private static func classify(_ part: ChatMessagePart) -> (content: ChatContentItem.Content, caption: String?) {
        let type = mediaType(part.contentType)
        let caption = nonempty(part.name)
        guard let value = part.value else { return (.unavailable(mediaType: type), caption) }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // These JSON envelopes become typed payloads for host-provided views.
        // Match the web client's defaults and preserve actionable labels verbatim.
        switch type {
        case "application/vnd.indice.multiple-choice+json":
            guard let fields = jsonObject(value) else { return (.unavailable(mediaType: type), caption) }
            let options: [String]
            if case .array(let values) = fields["options"] {
                options = values.compactMap(payloadString)
            } else { options = [] }
            return (.multipleChoice(.init(options: options)), caption)
        case "application/vnd.indice.callout+json":
            guard let fields = jsonObject(value), let text = payloadString(fields["text"]) else {
                return (.unavailable(mediaType: type), caption)
            }
            let severity = payloadString(fields["severity"]) ?? "info"
            return (.callout(.init(
                severity: Callout.Severity(rawValue: severity) ?? .info,
                title: payloadString(fields["title"]), text: text
            )), caption)
        case "application/vnd.indice.confirm+json":
            guard let fields = jsonObject(value) else { return (.unavailable(mediaType: type), caption) }
            return (.confirmation(.init(
                prompt: payloadString(fields["prompt"]),
                confirmText: payloadString(fields["confirmText"]) ?? "Yes",
                cancelText: payloadString(fields["cancelText"]) ?? "No"
            )), caption)
        default: break
        }

        // `image+json` is the web client's image envelope. Also accept the older
        // persisted url/alt spellings; raw image/* parts already carry their URI.
        if type == "application/vnd.indice.image+json" {
            guard let image = try? JSONDecoder().decode(ImageReference.self, from: Data(value.utf8)),
                  let uri = image.uri ?? image.url else { return (.unavailable(mediaType: type), caption) }
            return (imageContent(uri, declaredType: nil), nonempty(image.caption) ?? nonempty(image.alt) ?? caption)
        }

        if type?.hasPrefix("image/") == true {
            return (imageContent(trimmed, declaredType: type), caption)
        }

        // Classify an entire data URI, never search arbitrary prose for "data:".
        // The API already provides boundaries in parts; splitting concatenated
        // response.text would lose them and could reinterpret ordinary text/code.
        if trimmed.prefix(5).lowercased() == "data:", type == nil || type?.hasPrefix("text/") == true || type == "text" {
            guard let uri = DataURI(trimmed) else { return (.unavailable(mediaType: type), caption) }
            if uri.mediaType.hasPrefix("image/") {
                return (.imageData(uri.data, mediaType: uri.mediaType), caption)
            }
            guard ["text/html", "text/plain", "text/markdown", "text"].contains(uri.mediaType) else {
                return (.unsupported(mediaType: uri.mediaType), caption)
            }
            guard let text = uri.text else { return (.unavailable(mediaType: uri.mediaType), caption) }
            return (textContent(text, type: uri.mediaType), caption)
        }

        switch type {
        case nil, "text/plain": return (.text(value), caption)
        case "text/markdown", "text": return (.markdown(value), caption)
        case "text/html": return (.html(value), caption)
        default: return (.unsupported(mediaType: type), caption)
        }
    }

    private static func jsonObject(_ value: String) -> [String: JSONValue]? {
        try? JSONDecoder().decode([String: JSONValue].self, from: Data(value.utf8))
    }

    private static func payloadString(_ value: JSONValue?) -> String? {
        guard case .string(let text) = value, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private static func textContent(_ value: String, type: String) -> ChatContentItem.Content {
        switch type {
        case "text/html": .html(value)
        case "text/markdown", "text": .markdown(value)
        default: .text(value)
        }
    }

    private static func imageContent(_ value: String, declaredType: String?) -> ChatContentItem.Content {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.prefix(5).lowercased() == "data:" {
            guard let uri = DataURI(value), uri.mediaType.hasPrefix("image/") else {
                return .unavailable(mediaType: declaredType)
            }
            return .imageData(uri.data, mediaType: uri.mediaType)
        }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else {
            return .unavailable(mediaType: declaredType)
        }
        return .imageURL(url)
    }

    private static func mediaType(_ value: String?) -> String? {
        nonempty(value?.split(separator: ";", maxSplits: 1).first.map(String.init))?.lowercased()
    }

    private static func nonempty(_ value: String?) -> String? {
        guard
            let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else { return nil }
        
        return text
    }

    private struct ImageReference: APIModel {
        let uri: String?
        let url: String?
        let caption: String?
        let alt: String?
    }
}

/// Data URI decoding is independent of the UI and of the part's declared type.
/// `data:text/html;base64,...` is HTML, not an image. `image/*` is image content.
/// Percent-encoded payloads are decoded as bytes, so non-text images also work.
private struct DataURI {
    let mediaType: String
    let data: Data
    private let charset: String?
    private static let maximumBytes = 8 * 1024 * 1024

    init?(_ raw: String) {
        guard raw.prefix(5).lowercased() == "data:", let comma = raw.firstIndex(of: ",") else { return nil }
        let header = raw[raw.index(raw.startIndex, offsetBy: 5)..<comma]
            .split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        
        let declared = (header.first ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        mediaType = declared.isEmpty ? "text/plain" : declared
        
        let parameters = header
            .dropFirst()
            .map { $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            }
        
        charset = parameters
            .first { $0.hasPrefix("charset=") }
            .map { String($0.dropFirst(8)).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        
        let payload = raw[raw.index(after: comma)...]
        
        // Bound allocation before percent/base64 decoding as well as afterwards.
        guard payload.utf8.count <= Self.maximumBytes * 4,
              let bytes = Self.percentDecodedBytes(payload)
        else { return nil }
        
        if parameters.contains("base64") {
            // Do not use ignoreUnknownCharacters: it can silently turn truncated
            // or malformed data into unrelated bytes. Only transport whitespace
            // is removable. '+' stays '+', unlike form-url-encoded decoding.
            let base64 = bytes.filter { ![9, 10, 13, 32].contains($0) }
            guard let decoded = Data(base64Encoded: Data(base64)), decoded.count <= Self.maximumBytes else { return nil }
            data = decoded
        } else {
            guard bytes.count <= Self.maximumBytes else { return nil }
            data = bytes
        }
    }

    var text: String? {
        let encoding: String.Encoding
        switch charset {
        case nil, "utf-8", "utf8": encoding = .utf8
        case "us-ascii", "ascii": encoding = .ascii
        case "iso-8859-1", "latin1": encoding = .isoLatin1
        case "windows-1252": encoding = .windowsCP1252
        default: return nil
        }
        return String(data: data, encoding: encoding)
    }

    private static func percentDecodedBytes(_ value: Substring) -> Data? {
        var result = Data()
        var iterator = value.utf8.makeIterator()
        while let byte = iterator.next() {
            if byte == 37 { // %HH is an encoded byte, not necessarily a UTF-8 character.
                guard let first = iterator.next(), let second = iterator.next(),
                      let high = hex(first), let low = hex(second) else { return nil }
                result.append(high * 16 + low)
            } else { result.append(byte) }
        }
        return result
    }

    private static func hex(_ value: UInt8) -> UInt8? {
        switch value {
        case 48...57: value - 48
        case 65...70: value - 55
        case 97...102: value - 87
        default: nil
        }
    }
}
