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

    public static let totalDownloadBytes = Int64(ModelFile.all.reduce(0) { $0 + $1.size })

    public var downloadedBytes: Int64 {
        Int64(ModelFile.all.filter {
            Self.hasExpectedSize(directory.appendingPathComponent($0.path), size: $0.size)
        }.reduce(0) { $0 + $1.size })
    }

    public static func download(
        to directory: URL = defaultDirectory,
        progress: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws -> ModelAssets {
        try await ModelDownloader.fetchAssets(to: directory, progress: progress)
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
