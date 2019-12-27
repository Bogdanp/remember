//
//  JSONChunker.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

fileprivate let BACKSLASH = UInt8(ascii: "\\")
fileprivate let QUOTE = UInt8(ascii: "\"")
fileprivate let OSB = UInt8(ascii: "[")
fileprivate let CSB = UInt8(ascii: "]")
fileprivate let OCB = UInt8(ascii: "{")
fileprivate let CCB = UInt8(ascii: "}")

class JSONChunker {
    private let handler: (Data) -> Void
    private var buf = Data()

    init(chunkHandler: @escaping (Data) -> Void) {
        handler = chunkHandler
    }

    /// Write some data into the chunker.  If the data completes a pending
    /// JSON object, then the handler is called.
    func write(_ data: Data) {
        buf.append(data)

        var lo = 0
        var pc: UInt8 = 0
        var str = false
        var depth = 0
        for i in 0..<buf.count {
            switch buf[i] {
            case QUOTE where pc != BACKSLASH:
                str = !str
                depth += str ? 1 : -1
            case OSB where !str,
                 OCB where !str:
                depth += 1
            case CSB where !str,
                 CCB where !str:
                depth -= 1
            default:
                pc = buf[i]
                continue
            }

            if depth == 0 {
                handler(buf.subdata(in: lo..<i+1))
                lo = i + 1
            }
        }

        buf = buf.subdata(in: lo..<buf.count)
    }
}
