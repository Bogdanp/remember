//
//  AsyncNotification.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct EntriesDueNotification: Decodable {
    let entries: [Entry]
}

enum AsyncNotification: Decodable {
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
        switch type {
        case "entries-due":
            self = .entriesDue(try decoder.singleValueContainer().decode(EntriesDueNotification.self))
        default:
            throw AsyncNotificationError.unknownType(type)
        }
    }
}
