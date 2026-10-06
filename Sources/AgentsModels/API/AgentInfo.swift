import Foundation

/// Raw API payload from agents.json: `AgentInfo`.
public struct AgentInfo: APIModel, Hashable {
    public var name: String
    public var description: String
    public var inputContentTypes: [String]
    public var outputContentTypes: [String]
    public var capabilities: [AgentCapability]?
    public var domains: [String]?
    public var tags: [String]?
    public var links: [AgentLink]?
    public var author: AgentAuthor?
    public var metadata: [String: JSONValue]?
    public var icon: String?

    public init(
        name: String,
        description: String,
        inputContentTypes: [String],
        outputContentTypes: [String],
        capabilities: [AgentCapability]? = nil,
        domains: [String]? = nil,
        tags: [String]? = nil,
        links: [AgentLink]? = nil,
        author: AgentAuthor? = nil,
        metadata: [String: JSONValue]? = nil,
        icon: String? = nil
    ) {
        self.name = name
        self.description = description
        self.inputContentTypes = inputContentTypes
        self.outputContentTypes = outputContentTypes
        self.capabilities = capabilities
        self.domains = domains
        self.tags = tags
        self.links = links
        self.author = author
        self.metadata = metadata
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, inputContentTypes, outputContentTypes, capabilities, domains, tags, links, author, metadata, icon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputContentTypes = try container.decode([String].self, forKey: .inputContentTypes)
        outputContentTypes = try container.decode([String].self, forKey: .outputContentTypes)
        capabilities = try container.decodeIfPresent([AgentCapability].self, forKey: .capabilities)
        domains = try container.decodeIfPresent([String].self, forKey: .domains)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        links = try container.decodeIfPresent([AgentLink].self, forKey: .links)
        author = try container.decodeIfPresent(AgentAuthor.self, forKey: .author)
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
    }
}
