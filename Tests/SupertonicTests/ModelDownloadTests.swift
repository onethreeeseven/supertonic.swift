import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Supertonic

struct ModelDownloadTests {
    @Test func progressHandlesEmptyAndOutOfRangeTotals() {
        #expect(ModelDownloadProgress(downloadedBytes: 10, totalBytes: 0).fraction == 0)
        #expect(ModelDownloadProgress(downloadedBytes: -1, totalBytes: 10).fraction == 0)
        #expect(ModelDownloadProgress(downloadedBytes: 20, totalBytes: 10).fraction == 1)
    }

    @Test func cachedDownloadReportsCompletionWithoutNetworkRequests() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let directory = URL(fileURLWithPath: path)
        try #require(ModelAssets(directory: directory).isComplete)
        let reported = Progress(totalUnitCount: ModelAssets.totalDownloadBytes)
        let assets = try await ModelAssets.download(to: directory) { reported.completedUnitCount = $0.downloadedBytes }
        #expect(assets.isComplete)
        #expect(assets.downloadedBytes == ModelAssets.totalDownloadBytes)
        #expect(reported.completedUnitCount == ModelAssets.totalDownloadBytes)
    }

    @Test func wrongSizedCachedFilesDoNotCountAsDownloaded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: directory.appendingPathComponent("LICENSE"))
        let assets = ModelAssets(directory: directory)
        #expect(!assets.isComplete)
        #expect(assets.downloadedBytes == 0)
    }

    @Test func cancellingAnActiveDownloadReleasesItsAwaiter() async throws {
        guard ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] != nil else { return }
        let file = ModelFile(path: "onnx/vector_estimator.onnx", size: 256_534_781)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = try ModelSource.githubRelease.url(for: file)
        let download = Task { try await ModelDownloader.download(file, from: [source][...], session: session) }
        try await Task.sleep(for: .milliseconds(200))
        download.cancel()
        do {
            let destination = try await download.value
            try? FileManager.default.removeItem(at: destination)
            Issue.record("Cancelled download unexpectedly completed")
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        }
    }

    @Test func realNetworkDownloadReportsReceivedBytes() async throws {
        guard ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] != nil else { return }
        let file = ModelFile(path: "onnx/tts.json", size: 8253)
        let reported = Progress(totalUnitCount: ModelAssets.totalDownloadBytes)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = try ModelSource.githubRelease.url(for: file)
        let downloaded = try await ModelDownloader.download(file, from: [source][...], session: session) {
            reported.completedUnitCount = 100 + $0
        }
        defer { try? FileManager.default.removeItem(at: downloaded) }
        #expect(reported.completedUnitCount == 100 + Int64(file.size))
    }
}
