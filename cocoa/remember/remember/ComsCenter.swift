//
//  ComsCenter.swift
//  remember
//
//  Created by Bogdan Popa on 25/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation
import os

enum RPCError: Error {
    case encoding(Error)
    case decoding(Error)
    case runtime(String)
}

class ComsCenter {
    private let process = Process()
    private let decoder = JSONDecoder()

    private let rEnd = Pipe()
    private let wEnd = Pipe()

    private let queue = DispatchQueue(label: "io.defn.remember.ComsCenter")
    private var seq: UInt32 = 0
    private var pending: [UInt32: Handler] = [:]

    init() throws {
        process.executableURL = URL(fileURLWithPath: "/Users/bogdan/work/remember/bin/remember")
        process.standardInput = wEnd
        process.standardOutput = rEnd

        let chunker = JSONChunker {
            self.handleResult($0)
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

    /// Calls the RPC `name` with `args`, returning a future representing its async result.
    func call<R: Decodable>(_ name: String, _ args: [Any]) -> Future<R, RPCError> {
        let id = nextId()
        let request: [String: Any] = [
            "id": id,
            "name": name,
            "args": args
        ]
        let future = Future<R, RPCError> { promise in
            self.queue.sync {
                self.pending[id] = Handler(resolve: {
                    do {
                        let response = try self.decoder.decode(Response<R>.self, from: $0)
                        promise(.success(response.result))
                    } catch {
                        promise(.failure(.decoding(error)))
                    }
                }, reject: {
                    promise(.failure($0))
                })
            }
        }

        do {
            wEnd.fileHandleForWriting.write(try JSONSerialization.data(withJSONObject: request, options: .sortedKeys))
        } catch {
            if let handler = popHandler(forId: id) {
                handler.reject(.encoding(error))
            }
        }

        return future
    }

    private func handleResult(_ data: Data) {
        do {
            let result = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            guard let id = result?["id"] as? UInt32,
                let handler = popHandler(forId: id) else {
                return
            }

            if result?["result"] != nil {
                handler.resolve(data)
            } else if let error = result?["error"] as? String {
                handler.reject(.runtime(error))
            } else {
                handler.reject(.runtime("invalid response JSON: \(String(decoding: data, as: UTF8.self))"))
            }
        } catch  {
            os_log("failed to deserialize JSON", type: .error)
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

fileprivate struct Response<R: Decodable>: Decodable {
    let result: R
}
