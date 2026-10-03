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

    static func fetchAssets(
        to directory: URL,
        progress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> ModelAssets {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 1800
        configuration.httpMaximumConnectionsPerHost = 4
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let assets = ModelAssets(directory: directory)
        var downloadedBytes = assets.downloadedBytes
        progress?(ModelDownloadProgress(downloadedBytes: downloadedBytes, totalBytes: ModelAssets.totalDownloadBytes))
        for file in ModelFile.all {
            try Task.checkCancellation()
            guard !ModelAssets.hasExpectedSize(directory.appendingPathComponent(file.path), size: file.size) else { continue }
            let completedBytes = downloadedBytes
            let report: (@Sendable (Int64) -> Void)?
            if let progress {
                report = { receivedBytes in
                    progress(ModelDownloadProgress(downloadedBytes: completedBytes + receivedBytes, totalBytes: ModelAssets.totalDownloadBytes))
                }
            } else {
                report = nil
            }
            try await fetch(file, to: directory, session: session, progress: report)
            downloadedBytes += Int64(file.size)
            progress?(ModelDownloadProgress(downloadedBytes: downloadedBytes, totalBytes: ModelAssets.totalDownloadBytes))
        }
        try Task.checkCancellation()
        return assets
    }

    private static func fetch(_ file: ModelFile, to directory: URL, session: URLSession, progress: (@Sendable (Int64) -> Void)?) async throws {
        let destination = directory.appendingPathComponent(file.path)
        if ModelAssets.hasExpectedSize(destination, size: file.size) { return }
        let sources = try [ModelSource.huggingFace, .githubRelease].map { try $0.url(for: file) }
        let temporaryURL = try await download(file, from: sources[...], session: session, progress: progress)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try install(temporaryURL, at: destination, expectedSize: file.size)
    }

    static func download(_ file: ModelFile, from sources: ArraySlice<URL>, session: URLSession, progress: (@Sendable (Int64) -> Void)? = nil) async throws
        -> URL
    {
        guard let source = sources.first else {
            throw SupertonicError.invalidModel("No model download sources are available")
        }
        do {
            return try await download(file, from: source, session: session, progress: progress)
        } catch let error where sources.count > 1 && canRetryDownload(after: error) {
            try Task.checkCancellation()
            return try await download(file, from: sources.dropFirst(), session: session, progress: progress)
        }
    }

    private static func download(_ file: ModelFile, from source: URL, session: URLSession, progress: (@Sendable (Int64) -> Void)?) async throws -> URL
    {
        let reporting = progress.map { reportProgress(session: session, fileBytes: Int64(file.size), progress: $0) }
        defer { reporting?.cancel() }
        let (temporaryURL, response) = try await session.download(from: source)
        var isValidated = false
        defer {
            if !isValidated { try? FileManager.default.removeItem(at: temporaryURL) }
        }
        try Task.checkCancellation()
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw SupertonicError.download(file.path, status) }
        guard ModelAssets.hasExpectedSize(temporaryURL, size: file.size) else {
            throw SupertonicError.invalidModel("Downloaded \(file.path) has an unexpected size")
        }
        isValidated = true
        progress?(Int64(file.size))
        return temporaryURL
    }

    private static func reportProgress(
        session: URLSession, fileBytes: Int64, progress: @escaping @Sendable (Int64) -> Void
    ) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                let tasks: [URLSessionTask] = await withCheckedContinuation { continuation in
                    session.getAllTasks { continuation.resume(returning: $0) }
                }
                guard !Task.isCancelled else { return }
                if let task = tasks.first { progress(min(fileBytes, task.countOfBytesReceived)) }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    private static func canRetryDownload(after error: any Error) -> Bool {
        if let error = error as? URLError { return error.code != .cancelled }
        guard let error = error as? SupertonicError else { return false }
        switch error {
        case .download, .invalidModel: return true
        case .runtime, .playback, .invalidVoice: return false
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
