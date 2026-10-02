import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

actor ModelDownloader {
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
        let sources = try [ModelSource.huggingFace, .githubRelease].map { try $0.url(for: file) }
        let temporaryURL = try await download(file, from: sources[...], session: session)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try install(temporaryURL, at: destination, expectedSize: file.size)
    }

    static func download(_ file: ModelFile, from sources: ArraySlice<URL>, session: URLSession) async throws
        -> URL
    {
        guard let source = sources.first else {
            throw SupertonicError.invalidModel("No model download sources are available")
        }
        do {
            return try await download(file, from: source, session: session)
        } catch let error where sources.count > 1 && canRetryDownload(after: error) {
            try Task.checkCancellation()
            return try await download(file, from: sources.dropFirst(), session: session)
        }
    }

    private static func download(_ file: ModelFile, from source: URL, session: URLSession) async throws -> URL
    {
        let (temporaryURL, response) = try await session.download(from: source)
        var isValidated = false
        defer {
            if !isValidated { try? FileManager.default.removeItem(at: temporaryURL) }
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw SupertonicError.download(file.path, status) }
        guard ModelAssets.hasExpectedSize(temporaryURL, size: file.size) else {
            throw SupertonicError.invalidModel("Downloaded \(file.path) has an unexpected size")
        }
        isValidated = true
        return temporaryURL
    }

    private static func canRetryDownload(after error: any Error) -> Bool {
        if let error = error as? URLError { return error.code != .cancelled }
        guard let error = error as? SupertonicError else { return false }
        switch error {
        case .download, .invalidModel: return true
        case .runtime: return false
        }
    }

    private static func install(_ source: URL, at destination: URL, expectedSize: Int) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.appendingPathExtension(UUID().uuidString + ".partial")
        try manager.copyItem(at: source, to: staging)
        defer { try? manager.removeItem(at: staging) }
        if ModelAssets.hasExpectedSize(destination, size: expectedSize) { return }
        if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
        try manager.moveItem(at: staging, to: destination)
    }
}
