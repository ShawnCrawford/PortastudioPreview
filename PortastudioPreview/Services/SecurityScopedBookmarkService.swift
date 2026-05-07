//
//  SecurityScopedBookmarkService.swift
//  PortastudioPreview
//

import Foundation

protocol BookmarkServiceProtocol: Sendable {
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
}

/// Production bookmark service that creates and resolves security-scoped bookmarks.
struct SecurityScopedBookmarkService: BookmarkServiceProtocol {
    func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }
}

/// Test seam: encodes and decodes the URL path directly without security scope.
/// Suitable for unit tests that must not depend on real security-scope grants.
struct PassthroughBookmarkService: BookmarkServiceProtocol {
    func createBookmark(for url: URL) throws -> Data {
        guard let data = url.path.data(using: .utf8) else {
            throw BookmarkServiceError.encodingFailed
        }
        return data
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        guard let path = String(data: data, encoding: .utf8) else {
            throw BookmarkServiceError.decodingFailed
        }
        return (URL(fileURLWithPath: path), false)
    }
}

enum BookmarkServiceError: LocalizedError {
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode URL as bookmark data."
        case .decodingFailed: return "Failed to decode bookmark data to URL."
        }
    }
}
