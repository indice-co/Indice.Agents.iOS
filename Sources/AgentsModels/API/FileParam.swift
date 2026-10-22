import Foundation

/// A local file to send as a binary multipart part. Its Codable representation is
/// upload metadata for local storage, not a JSON request body accepted by the API.
/// The repository reads `fileURL` through NetworkUtilities' multipart builder.
public struct FileParam: APIModel, Hashable {
    public var fileURL: URL
    public var fileName: String
    public var contentType: String

    public init(fileURL: URL, fileName: String? = nil, contentType: String = "application/octet-stream") {
        self.fileURL = fileURL
        self.fileName = fileName ?? fileURL.lastPathComponent
        self.contentType = contentType
    }
}
