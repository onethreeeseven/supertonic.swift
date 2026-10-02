import Foundation

public struct ModelAssets: Sendable {
    public static let revision = "aafc6e32416a594460b32413efc49d7fe4ce6d46"
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        let base =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Supertonic/3/\(revision)", isDirectory: true)
    }

    public static func download(to directory: URL = defaultDirectory) async throws -> ModelAssets {
        try await ModelDownloader.shared.download(to: directory)
    }

    public var isComplete: Bool {
        ModelFile.all.allSatisfy {
            Self.hasExpectedSize(directory.appendingPathComponent($0.path), size: $0.size)
        }
    }

    static func hasExpectedSize(_ url: URL, size: Int) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let actualSize = attributes[.size] as? NSNumber
        else { return false }
        return actualSize.intValue == size
    }
}
