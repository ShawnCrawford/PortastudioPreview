//
//  ByteReader.swift
//  PortastudioPreview
//

import Foundation

struct ByteReader {
    let data: Data

    func readUInt8(at offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < data.count else {
            throw ByteReaderError.truncated(offset: offset, requiredLength: offset + 1, actualLength: data.count)
        }

        return data[data.startIndex + offset]
    }
}

enum ByteReaderError: Error, Equatable, LocalizedError {
    case truncated(offset: Int, requiredLength: Int, actualLength: Int)

    var errorDescription: String? {
        switch self {
        case let .truncated(offset, requiredLength, actualLength):
            return "Read at \(HexFormatter.offset(offset)) requires \(requiredLength) bytes, but data has \(actualLength) bytes."
        }
    }
}
