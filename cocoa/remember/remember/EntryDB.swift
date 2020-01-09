//
//  EntryDB.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct Entry: Equatable &  Identifiable & Decodable {
    typealias Id = UInt32

    let id: Id
    let title: String
    let dueIn: String?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case dueIn = "due-in"
        case isRecurring = "recurs?"
    }
}

enum CommitResult {
    case ok(Entry)
    case error(Error)
}

protocol EntryDB {
    func commit(command: String, withCompletionHandler: @escaping (CommitResult) -> Void)
    func archiveEntry(byId: Entry.Id)
    func archiveEntry(byId: Entry.Id, withCompletionHandler: @escaping () -> Void)
    func snoozeEntry(byId: Entry.Id)
    func snoozeEntry(byId: Entry.Id, withCompletionHandler: @escaping () -> Void)
    func deleteEntry(byId: Entry.Id)
    func deleteEntry(byId: Entry.Id, withCompletionHandler: @escaping () -> Void)
    func findPendingEntries(withCompletionHandler: @escaping ([Entry]) -> Void)
    func undo(withCompletionHandler: @escaping () -> Void)
}
