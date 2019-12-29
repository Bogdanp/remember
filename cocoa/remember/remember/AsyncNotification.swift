//
//  AsyncNotification.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

protocol AsyncNotifier {
    func addListener(withHandler: @escaping (AsyncNotification) -> Void)
}

struct EntriesDidChangeNotification: Decodable {

}

struct EntriesDueNotification: Decodable {
    let entries: [Entry]
}

enum AsyncNotification: Decodable {
    case entriesDidChange
    case entriesDue(EntriesDueNotification)

    enum AsyncNotificationError: Error {
        case unknownType(String)
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let svc = try decoder.singleValueContainer()
        switch type {
        case "entries-did-change": self = .entriesDidChange
        case "entries-due": self = .entriesDue(try svc.decode(EntriesDueNotification.self))
        default:
            throw AsyncNotificationError.unknownType(type)
        }
    }
}
