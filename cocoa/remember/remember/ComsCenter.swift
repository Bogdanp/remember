//
//  ComsCenter.swift
//  remember
//
//  Created by Bogdan Popa on 25/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import os

enum RPCResult<R> {
    case ok(R)
    case error(RPCError)
}

enum RPCError: Error {
    case encoding(Error)
    case decoding(Error)
    case runtime(String)
}

struct RPCUnit: Decodable {

}

class ComsCenter {
    private let process = Process()
    private let decoder = JSONDecoder()

    private let rEnd = Pipe()
    private let wEnd = Pipe()

    private let queue = DispatchQueue(label: "io.defn.remember.ComsCenter")
    private var seq: UInt32 = 0
    private var pending: [UInt32: Handler] = [:]
    private var asyncNotificationListeners = [(AsyncNotification) -> Void]()

    init(withCoreURL coreURL: URL) throws {
        process.executableURL = coreURL
        process.standardInput = wEnd
        process.standardOutput = rEnd

        let chunker = JSONChunker {
            self.onDataReceived($0)
        }

        rEnd.fileHandleForReading.readabilityHandler = {
            chunker.write($0.availableData)
        }

        try process.run()
    }

    func shutdown() {
        process.interrupt()
        process.waitUntilExit()
    }

    /// Calls the RPC `name` with `args`.  If an asynchronous response is ever returned, then `action` is called.
    func call<R: Decodable>(_ name: String, _ args: [Any], action: @escaping (RPCResult<R>) -> Void) {
        let id = nextId()
        let request: [String: Any] = [
            "id": id,
            "name": name,
            "args": args
        ]
        self.queue.sync {
            self.pending[id] = Handler(resolve: {
                do {
                    let response = try self.decoder.decode(Response<R>.self, from: $0)
                    action(.ok(response.result))
                } catch {
                    action(.error(.decoding(error)))
                }
            }, reject: {
                action(.error($0))
            })
        }

        do {
            wEnd.fileHandleForWriting.write(try JSONSerialization.data(withJSONObject: request, options: .sortedKeys))
        } catch {
            if let handler = popHandler(forId: id) {
                handler.reject(.encoding(error))
            }
        }
    }

    func addListener(withHandler handler: @escaping (AsyncNotification) -> Void) {
        queue.sync {
            self.asyncNotificationListeners.append(handler)
        }
    }

    private func onDataReceived(_ data: Data) {
        do {
            let result = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]

            if let id = result?["id"] as? UInt32,
                let handler = popHandler(forId: id) {

                if result?["result"] != nil {
                    handler.resolve(data)
                } else if let error = result?["error"] as? String {
                    handler.reject(.runtime(error))
                } else {
                    handler.reject(.runtime("invalid JSON: \(String(decoding: data, as: UTF8.self))"))
                }
            } else if result?["notification"] != nil {
                do {
                    let data = try self.decoder.decode(AsyncNotificationData.self, from: data)
                    for listener in self.asyncNotificationListeners {
                        listener(data.notification)
                    }
                } catch {
                    os_log("failed to decode notification: %s", type: .error, "\(error)")
                }
            }
        } catch {
            os_log("failed to deserialize JSON: %s", type: .error, "\(error)")
        }
    }

    private func nextId() -> UInt32 {
        queue.sync {
            let id = seq
            seq += 1
            return id
        }
    }

    private func popHandler(forId id: UInt32) -> Handler? {
        queue.sync {
            pending.removeValue(forKey: id)
        }
    }
}

fileprivate struct Handler {
    let resolve: (Data) -> Void
    let reject: (RPCError) -> Void
}

/// Represents an async RPC response containing a result of type `R`.
fileprivate struct Response<R: Decodable>: Decodable {
    let result: R
}

/// Represents an async notification received from the core.
fileprivate struct AsyncNotificationData: Decodable {
    let notification: AsyncNotification
}
