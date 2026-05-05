//
//  WAVInventoryItem.swift
//  PortastudioPreview
//

import Foundation

struct WAVInventoryItem: Identifiable, Hashable {
    let url: URL
    let rawFilename: String
    let byteCount: Int?

    var id: String { url.path }
}
