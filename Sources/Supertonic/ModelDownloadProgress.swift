import Foundation

public struct ModelDownloadProgress: Sendable, Equatable {
    public let downloadedBytes: Int64
    public let totalBytes: Int64

    public init(downloadedBytes: Int64, totalBytes: Int64) {
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
    }

    public var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(downloadedBytes) / Double(totalBytes)))
    }
}
