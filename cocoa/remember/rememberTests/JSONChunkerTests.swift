//
//  JSONChunkerTests.swift
//  rememberTests
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import XCTest

@testable import remember

class JSONChunkerTests: XCTestCase {
    func testSendingChunks() {
        var theChunk = ""
        let chunker = JSONChunker() {
            theChunk = String(decoding: $0, as: UTF8.self)
        }

        chunker.write("{}".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "{}")

        chunker.write("{}  ".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "{}")

        chunker.write("{}".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "  {}")

        chunker.write("[1, 2".data(using: .utf8)!)
        chunker.write(", [1]".data(using: .utf8)!)
        chunker.write("]".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "[1, 2, [1]]")

        chunker.write("[1, \"]\",".data(using: .utf8)!)
        chunker.write(" 2]".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "[1, \"]\", 2]")

        chunker.write("\"".data(using: .utf8)!)
        chunker.write("hello\"".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "\"hello\"")

        chunker.write("\"\\\"hello\\\" is a 5 letter word\"".data(using: .utf8)!)
        XCTAssertEqual(theChunk, "\"\\\"hello\\\" is a 5 letter word\"")
    }
}
