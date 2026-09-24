import Foundation
import Testing
import AgentsModels
@testable import IndiceAgents

struct ChatContentTests {
    private let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE1sAAAAASUVORK5CYII="

    private func item(_ value: String?, type: String? = nil, name: String? = nil) throws -> ChatContentItem {
        try #require(ChatContentMapper.items(for: .init(parts: [.init(value: value, contentType: type, name: name)])).first)
    }

    @Test func mixedMessagePreservesPartOrderAndProseOnlyConvenience() throws {
        let html = "<section><h3>Γεια 👋</h3><p>A card</p></section>"
        let rawHTML = "data:text/html;base64," + Data(html.utf8).base64EncodedString()
        let raw = DexChatMessage(role: .assistant, content: .init(parts: [
            .init(value: "First", contentType: "text/plain"),
            .init(value: rawHTML, contentType: "text/html"),
            .init(value: "data:image/png;base64," + png, contentType: "image/png", name: "Pixel"),
            .init(value: "**Last**", contentType: "text/markdown")
        ]))
        let message = ChatSessionService.Message(value: raw)
        #expect(message.items.map(\.id) == [0, 1, 2, 3])
        #expect(message.items[0].content == .text("First"))
        #expect(message.items[1].content == .html(html))
        #expect(message.items[2].content == .imageData(try #require(Data(base64Encoded: png)), mediaType: "image/png"))
        #expect(message.items[2].caption == "Pixel")
        #expect(message.items[3].content == .markdown("**Last**"))
        #expect(message.text == "First**Last**")
        #expect(message.value == raw) // Raw API values remain untouched.
        #expect(!message.text.contains("base64"))
    }

    @Test func htmlAcceptsLiteralBase64AndPercentEncoding() throws {
        let html = "<p>Ελληνικά + 👋</p>"
        #expect(try item(html, type: " Text/HTML; charset=UTF-8 ").content == .html(html))
        let encoded = Data(html.utf8).base64EncodedString()
        #expect(try item("DATA:text/html;charset=UTF-8;BASE64," + encoded, type: "text/html").content == .html(html))
        #expect(try item("data:text/html,%3Cp%3E%CE%93%CE%B5%CE%B9%CE%B1%20+%3C%2Fp%3E", type: "text/html").content == .html("<p>Γεια +</p>"))
        #expect(try item("data:text/html;charset=iso-8859-1,%3Cp%3Ecaf%E9%3C%2Fp%3E", type: "text/html").content == .html("<p>café</p>"))
    }

    @Test func dataURITypeIdentifiesMissingOrGenericPartType() throws {
        let value = "data:text/html;base64," + Data("<p>Card</p>".utf8).base64EncodedString()
        #expect(try item(value).content == .html("<p>Card</p>"))
        #expect(try item(value, type: "text").content == .html("<p>Card</p>"))
        #expect(try item("data:,Hello%20world").content == .text("Hello world"))
        #expect(try item("data:text/markdown,%2A%2Abold%2A%2A").content == .markdown("**bold**"))
    }

    @Test func imageBytesSVGAndPercentEncodedBinary() throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><circle r=\"4\"/></svg>"
        #expect(try item("data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString(), type: "image/svg+xml").content == .imageData(Data(svg.utf8), mediaType: "image/svg+xml"))
        #expect(try item("data:image/png,%89PNG%00%FF", type: "image/png").content == .imageData(Data([0x89, 0x50, 0x4e, 0x47, 0, 255]), mediaType: "image/png"))
        // A literal '+' is a base64 character, not a form-encoded space.
        #expect(try item("data:image/png;base64,+w==", type: "image/png").content == .imageData(Data([251]), mediaType: "image/png"))
        #expect(try item("data:image/png;base64,%2Bw%3D%3D", type: "image/png").content == .imageData(Data([251]), mediaType: "image/png"))
    }

    @Test func imageEnvelopeAndLegacyFields() throws {
        let url = URL(string: "https://example.com/image.png")!
        #expect(try item(url.absoluteString, type: "image/png").content == .imageURL(url))
        let current = try item(#"{"uri":"https://example.com/image.png","caption":"Caption"}"#, type: "application/vnd.indice.image+json", name: "Name")
        #expect(current.content == .imageURL(url))
        #expect(current.caption == "Caption")
        let legacy = try item(#"{"url":"https://example.com/image.png","alt":"Old caption"}"#, type: "application/vnd.indice.image+json")
        #expect(legacy.content == .imageURL(url))
        #expect(legacy.caption == "Old caption")
        let inline = try item("{\"uri\":\"data:image/png;base64,\(png)\"}", type: "application/vnd.indice.image+json", name: "Name")
        #expect(inline.caption == "Name")
        guard case .imageData = inline.content else { Issue.record("Expected decoded inline image"); return }
    }

    @Test func vendorComponentsExposeTypedPayloadsInMessageOrder() throws {
        let raw = DexChatMessage(content: .init(parts: [
            .init(value: "Choose next", contentType: "text/plain"),
            .init(value: #"{"options":[" One ","Two"]}"#, contentType: " APPLICATION/VND.INDICE.MULTIPLE-CHOICE+JSON; charset=utf-8 "),
            .init(value: #"{"severity":"warning","title":"Careful","text":"First line\nSecond line"}"#, contentType: "application/vnd.indice.callout+json", name: "Notice"),
            .init(value: #"{"prompt":"Continue?","confirmText":" Proceed ","cancelText":"Stop"}"#, contentType: "application/vnd.indice.confirm+json")
        ]))
        let message = ChatSessionService.Message(value: raw)
        #expect(message.items.map(\.id) == [0, 1, 2, 3])
        #expect(message.items[1].content == .multipleChoice(.init(options: [" One ", "Two"])))
        #expect(message.items[2].content == .callout(.init(severity: .warning, title: "Careful", text: "First line\nSecond line")))
        #expect(message.items[2].caption == "Notice")
        #expect(message.items[3].content == .confirmation(.init(prompt: "Continue?", confirmText: " Proceed ", cancelText: "Stop")))
        #expect(message.text == "Choose next")
        #expect(message.value == raw)

        // Payloads remain APIModel values consumers can persist or construct.
        let choice = MultipleChoice(options: ["One", "Two"])
        #expect(try APIJSON.decoder().decode(MultipleChoice.self, from: APIJSON.encoder().encode(choice)) == choice)
        let callout = Callout(severity: .warning, title: "Title", text: "Body")
        #expect(try APIJSON.decoder().decode(Callout.self, from: APIJSON.encoder().encode(callout)) == callout)
        let encodedCallout = try JSONDecoder().decode([String: String].self, from: APIJSON.encoder().encode(callout))
        #expect(encodedCallout["severity"] == "warning")
        #expect(try APIJSON.decoder().decode(Callout.self, from: Data(#"{"severity":"future","text":"Body"}"#.utf8)).severity == .info)
        let confirmation = Confirmation(prompt: "Continue?")
        #expect(try APIJSON.decoder().decode(Confirmation.self, from: APIJSON.encoder().encode(confirmation)) == confirmation)
    }

    @Test func vendorComponentDefaultsMatchWebAndKeepActionLabelsVerbatim() throws {
        let multipleChoice = "application/vnd.indice.multiple-choice+json"
        #expect(try item(#"{"options":[" One ",null,42,"  ","Two"]}"#, type: multipleChoice).content == .multipleChoice(.init(options: [" One ", "Two"])))
        for value in ["{}", #"{"options":null}"#, #"{"options":"One"}"#] {
            #expect(try item(value, type: multipleChoice).content == .multipleChoice(.init()))
        }
        let callout = "application/vnd.indice.callout+json"
        for severity in Callout.Severity.allCases {
            #expect(try item("{\"severity\":\"\(severity.rawValue)\",\"text\":\"Body\"}", type: callout).content == .callout(.init(severity: severity, text: "Body")))
        }
        for value in [#"{"text":"Body"}"#, #"{"severity":"future","title":"  ","text":"Body"}"#, #"{"severity":42,"title":false,"text":"Body"}"#] {
            #expect(try item(value, type: callout).content == .callout(.init(text: "Body")))
        }
        let confirmation = "application/vnd.indice.confirm+json"
        for value in ["{}", #"{"prompt":" ","confirmText":null,"cancelText":"  "}"#, #"{"prompt":42,"confirmText":false,"cancelText":7}"#] {
            #expect(try item(value, type: confirmation).content == .confirmation(.init()))
        }
    }

    @Test func malformedVendorComponentsRecoverWhenStreamingJSONCompletes() throws {
        for type in ["application/vnd.indice.multiple-choice+json", "application/vnd.indice.callout+json", "application/vnd.indice.confirm+json"] {
            for value in ["broken JSON", "{", "[]", "null", "true", "42", #""text""#] {
                #expect(try item(value, type: type).content == .unavailable(mediaType: type))
            }
        }
        for value in ["{}", #"{"text":"  "}"#, #"{"text":42}"#] {
            #expect(try item(value, type: "application/vnd.indice.callout+json").content == .unavailable(mediaType: "application/vnd.indice.callout+json"))
        }
        var message = ChatSessionService.Message(value: .init(content: .init(parts: [
            .init(value: #"{"options":["One""#, contentType: "application/vnd.indice.multiple-choice+json")
        ])), delivery: .streaming)
        let id = message.items[0].id
        #expect(message.items[0].content == .unavailable(mediaType: "application/vnd.indice.multiple-choice+json"))
        message.value.content?.parts?[0].value = #"{"options":["One","Two"]}"#
        #expect(message.items[0].id == id)
        #expect(message.items[0].content == .multipleChoice(.init(options: ["One", "Two"])))
    }

    @Test func malformedKnownContentNeverBecomesProse() throws {
        for value in ["data:text/html;base64,%%%", "data:text/html;base64,SGVsb", "data:text/html,%ZZ", "data:text/html;charset=unknown,hello", "data:text/html,%FF"] {
            let mapped = try item(value, type: "text/html")
            guard case .unavailable = mapped.content else { Issue.record("Expected unavailable for malformed HTML"); continue }
        }
        for value in ["javascript:alert(1)", "file:///private/file.png", "//example.com/file.png", "data:text/html;base64,PGgxPkJvb208L2gxPg==", "not an image", "https://user:password@example.com/image.png"] {
            guard case .unavailable = try item(value, type: "image/png").content else { Issue.record("Invalid image source was accepted"); continue }
        }
        #expect(try item("broken JSON", type: "application/vnd.indice.image+json").content == .unavailable(mediaType: "application/vnd.indice.image+json"))
    }

    @Test func unsupportedPartsAreIdentifiableAndOrdinaryProseIsNotSplit() throws {
        let prose = "The syntax is data:text/html;base64,... in a data URI."
        #expect(try item(prose, type: "text/plain").content == .text(prose))
        #expect(try item(prose, type: "text/markdown").content == .markdown(prose))
        #expect(try item("{\"key\":\"value\"}", type: "application/vnd.indice.future+json").content == .unsupported(mediaType: "application/vnd.indice.future+json"))
        #expect(try item("data:application/pdf;base64,AA==").content == .unsupported(mediaType: "application/pdf"))
        #expect(ChatContentMapper.items(for: nil).isEmpty)
    }

    @Test func streamingUpdatesKeepItemIdentityAndReclassifyCompletedPayloads() throws {
        let value = "data:text/html;base64," + Data("<h3>Card</h3>".utf8).base64EncodedString()
        var message = ChatSessionService.Message(value: .init(content: .init(parts: [
            .init(value: "Hello", contentType: "text/markdown"),
            .init(value: "data:text/html;base64,PG", contentType: "text/html")
        ])), delivery: .streaming)
        let ids = message.items.map(\.id)
        guard case .unavailable = message.items[1].content else { Issue.record("Expected incomplete HTML placeholder"); return }
        message.value.content?.parts?[1].value = value
        #expect(message.items.map(\.id) == ids)
        #expect(message.items[1].content == .html("<h3>Card</h3>"))
        let htmlItem = message.items[1]
        message.value.content?.parts?[0].value = "Hello there"
        message.value.content?.parts?.append(.init(value: "After", contentType: "text/plain"))
        #expect(message.items[1] == htmlItem)
        #expect(message.items.map(\.id) == [0, 1, 2])
        #expect(message.text == "Hello thereAfter")
    }
}
