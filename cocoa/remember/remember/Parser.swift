//
//  Parser.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation

enum ParseError: Error {
    case error(Error)
}

protocol Parser {
    func parse(command: String) -> AnyPublisher<[Token], ParseError>
}

enum Token: Decodable {
    case chunk(Chunk)
    case relativeDate(RelativeDate)
    case tag(Tag)

    enum TokenError: Error {
        case unknownType(String)
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "chunk":
            self = .chunk(try decoder.singleValueContainer().decode(Chunk.self))
        case "relative-date":
            self = .relativeDate(try decoder.singleValueContainer().decode(RelativeDate.self))
        case "tag":
            self = .tag(try decoder.singleValueContainer().decode(Tag.self))
        default:
            throw TokenError.unknownType(type)
        }
    }
}

struct Chunk: Decodable {
    let text: String
    let span: Span
}

struct RelativeDate: Decodable {
    let text: String
    let span: Span
    let delta: Int
    let modifier: String
}

struct Tag: Decodable {
    let text: String
    let span: Span
    let tag: String
}

struct Span: Decodable {
    let lo: Position
    let hi: Position

    init(from decoder: Decoder) throws  {
        var container = try decoder.unkeyedContainer()
        lo = try container.decode(Position.self)
        hi = try container.decode(Position.self)
    }
}

struct Position: Decodable {
    let line: UInt64
    let column: UInt64
    let offset: UInt64

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        line = try container.decode(UInt64.self)
        column = try container.decode(UInt64.self)
        offset = try container.decode(UInt64.self)
    }
}
