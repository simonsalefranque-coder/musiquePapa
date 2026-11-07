import Foundation

/// Files-provider adapter. A future OAuth Dropbox adapter can implement the same protocol.
/// No remote deletions or background synchronization are performed.
protocol ScoreFolderProvider {
    func resolve(_ link: FolderLink) throws -> (url: URL, refreshedBookmark: Data?)
}
struct FilesFolderProvider: ScoreFolderProvider {
    func resolve(_ link: FolderLink) throws -> (url: URL, refreshedBookmark: Data?) {
        var stale = false
        let url = try URL(resolvingBookmarkData: link.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bookmark = stale ? try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        return (url, bookmark)
    }
    static func link(_ url: URL) throws -> FolderLink {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        return FolderLink(name: url.lastPathComponent, bookmark: bookmark)
    }
}
