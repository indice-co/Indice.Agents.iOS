import Foundation

/// Raw API payload from agents.json: `DexChatUsage`.
public struct DexChatUsage: APIModel, Hashable {
    public var inputTokenCount: Int64?
    public var outputTokenCount: Int64?
    public var totalTokenCount: Int64?
    public var questionsUsedCount: Int64?
    public var questionsLimitCount: Int64?

    public init(
        inputTokenCount: Int64? = nil,
        outputTokenCount: Int64? = nil,
        totalTokenCount: Int64? = nil,
        questionsUsedCount: Int64? = nil,
        questionsLimitCount: Int64? = nil
    ) {
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.totalTokenCount = totalTokenCount
        self.questionsUsedCount = questionsUsedCount
        self.questionsLimitCount = questionsLimitCount
    }

    private enum CodingKeys: String, CodingKey {
        case inputTokenCount, outputTokenCount, totalTokenCount, questionsUsedCount, questionsLimitCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokenCount = try container.decodeAPINumberIfPresent(Int64.self, forKey: .inputTokenCount)
        outputTokenCount = try container.decodeAPINumberIfPresent(Int64.self, forKey: .outputTokenCount)
        totalTokenCount = try container.decodeAPINumberIfPresent(Int64.self, forKey: .totalTokenCount)
        questionsUsedCount = try container.decodeAPINumberIfPresent(Int64.self, forKey: .questionsUsedCount)
        questionsLimitCount = try container.decodeAPINumberIfPresent(Int64.self, forKey: .questionsLimitCount)
    }
}
