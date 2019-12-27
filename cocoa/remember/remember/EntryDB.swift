//
//  EntryDB.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct Entry: Identifiable & Decodable {
    let id: Int
    let title: String
}

enum CommitResult {
    case ok(Entry)
    case error(Error)
}

protocol EntryDB {
    func commit(command: String, action: @escaping (CommitResult) -> Void)
}
