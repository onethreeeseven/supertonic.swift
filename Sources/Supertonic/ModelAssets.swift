import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ModelAssets: Sendable {
    public static let revision = "aafc6e32416a594460b32413efc49d7fe4ce6d46"
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Supertonic/3/\(revision)", isDirectory: true)
    }

    public static func download(to directory: URL = defaultDirectory) async throws -> ModelAssets {
        try await ModelDownloader.shared.download(to: directory)
    }

    public var isComplete: Bool {
        ModelFile.all.allSatisfy { Self.hasExpectedSize(directory.appendingPathComponent($0.path), size: $0.size) }
    }

    static func hasExpectedSize(_ url: URL, size: Int) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let actualSize = attributes[.size] as? NSNumber else { return false }
        return actualSize.intValue == size
    }
}

private actor ModelDownloader {
    static let shared = ModelDownloader()
    private var downloads: [URL: Task<ModelAssets, Error>] = [:]

    func download(to directory: URL) async throws -> ModelAssets {
        let directory = directory.standardizedFileURL
        if let download = downloads[directory] { return try await download.value }
        let download = Task { try await Self.fetchAssets(to: directory) }
        downloads[directory] = download
        defer { downloads[directory] = nil }
        return try await download.value
    }

    private static func fetchAssets(to directory: URL) async throws -> ModelAssets {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 1800
        configuration.httpMaximumConnectionsPerHost = 4
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        for file in ModelFile.all {
            try Task.checkCancellation()
            try await fetch(file, to: directory, session: session)
        }
        return ModelAssets(directory: directory)
    }

    private static func fetch(_ file: ModelFile, to directory: URL, session: URLSession) async throws {
        let destination = directory.appendingPathComponent(file.path)
        if ModelAssets.hasExpectedSize(destination, size: file.size) { return }
        let endpoint = file.path.hasSuffix(".onnx") ? "resolve" : "raw"
        let address = "https://huggingface.co/supertone-oss-archive/supertonic-3/\(endpoint)/\(ModelAssets.revision)/\(file.path)"
        guard let remoteURL = URL(string: address) else { throw SupertonicError.invalidModel("Invalid model asset URL") }
        let (temporaryURL, response) = try await session.download(from: remoteURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw SupertonicError.download(file.path, status) }
        guard ModelAssets.hasExpectedSize(temporaryURL, size: file.size) else {
            throw SupertonicError.invalidModel("Downloaded \(file.path) has an unexpected size")
        }
        try install(temporaryURL, at: destination, expectedSize: file.size)
    }

    private static func install(_ source: URL, at destination: URL, expectedSize: Int) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.appendingPathExtension(UUID().uuidString + ".partial")
        try manager.copyItem(at: source, to: staging)
        defer { try? manager.removeItem(at: staging) }
        if ModelAssets.hasExpectedSize(destination, size: expectedSize) { return }
        if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
        try manager.moveItem(at: staging, to: destination)
    }
}
