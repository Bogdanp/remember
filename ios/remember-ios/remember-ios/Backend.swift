// This file was automatically generated by noise-serde-lib.
import Foundation
import NoiseBackend
import NoiseSerde

public enum TokenData: Readable, Writable {
  case relativeTime(UVarint, Symbol)
  case namedDate(String)
  case namedDatetime(String)
  case recurrence(UVarint, Symbol)
  case tag(String)

  public static func read(from inp: InputPort, using buf: inout Data) -> TokenData {
    let tag = UVarint.read(from: inp, using: &buf)
    switch tag {
    case 0x0000:
      return .relativeTime(
        UVarint.read(from: inp, using: &buf),
        Symbol.read(from: inp, using: &buf)
      )
    case 0x0001:
      return .namedDate(
        String.read(from: inp, using: &buf)
      )
    case 0x0002:
      return .namedDatetime(
        String.read(from: inp, using: &buf)
      )
    case 0x0003:
      return .recurrence(
        UVarint.read(from: inp, using: &buf),
        Symbol.read(from: inp, using: &buf)
      )
    case 0x0004:
      return .tag(
        String.read(from: inp, using: &buf)
      )
    default:
      preconditionFailure("TokenData: unexpected tag \(tag)")
    }
  }

  public func write(to out: OutputPort) {
    switch self {
    case .relativeTime(let delta, let modifier):
      UVarint(0x0000).write(to: out)
      delta.write(to: out)
      modifier.write(to: out)
    case .namedDate(let date):
      UVarint(0x0001).write(to: out)
      date.write(to: out)
    case .namedDatetime(let datetime):
      UVarint(0x0002).write(to: out)
      datetime.write(to: out)
    case .recurrence(let delta, let modifier):
      UVarint(0x0003).write(to: out)
      delta.write(to: out)
      modifier.write(to: out)
    case .tag(let name):
      UVarint(0x0004).write(to: out)
      name.write(to: out)
    }
  }
}

public struct Entry: Readable, Writable {
  public let id: UVarint
  public let title: String
  public let dueIn: String?
  public let recurs: Bool

  public init(
    id: UVarint,
    title: String,
    dueIn: String?,
    recurs: Bool
  ) {
    self.id = id
    self.title = title
    self.dueIn = dueIn
    self.recurs = recurs
  }

  public static func read(from inp: InputPort, using buf: inout Data) -> Entry {
    return Entry(
      id: UVarint.read(from: inp, using: &buf),
      title: String.read(from: inp, using: &buf),
      dueIn: String?.read(from: inp, using: &buf),
      recurs: Bool.read(from: inp, using: &buf)
    )
  }

  public func write(to out: OutputPort) {
    id.write(to: out)
    title.write(to: out)
    dueIn.write(to: out)
    recurs.write(to: out)
  }
}

public struct Location: Readable, Writable {
  public let line: UVarint
  public let column: UVarint
  public let offset: UVarint

  public init(
    line: UVarint,
    column: UVarint,
    offset: UVarint
  ) {
    self.line = line
    self.column = column
    self.offset = offset
  }

  public static func read(from inp: InputPort, using buf: inout Data) -> Location {
    return Location(
      line: UVarint.read(from: inp, using: &buf),
      column: UVarint.read(from: inp, using: &buf),
      offset: UVarint.read(from: inp, using: &buf)
    )
  }

  public func write(to out: OutputPort) {
    line.write(to: out)
    column.write(to: out)
    offset.write(to: out)
  }
}

public struct Span: Readable, Writable {
  public let lo: Location
  public let hi: Location

  public init(
    lo: Location,
    hi: Location
  ) {
    self.lo = lo
    self.hi = hi
  }

  public static func read(from inp: InputPort, using buf: inout Data) -> Span {
    return Span(
      lo: Location.read(from: inp, using: &buf),
      hi: Location.read(from: inp, using: &buf)
    )
  }

  public func write(to out: OutputPort) {
    lo.write(to: out)
    hi.write(to: out)
  }
}

public struct Token: Readable, Writable {
  public let text: String
  public let span: Span
  public let data: TokenData?

  public init(
    text: String,
    span: Span,
    data: TokenData?
  ) {
    self.text = text
    self.span = span
    self.data = data
  }

  public static func read(from inp: InputPort, using buf: inout Data) -> Token {
    return Token(
      text: String.read(from: inp, using: &buf),
      span: Span.read(from: inp, using: &buf),
      data: TokenData?.read(from: inp, using: &buf)
    )
  }

  public func write(to out: OutputPort) {
    text.write(to: out)
    span.write(to: out)
    data.write(to: out)
  }
}

public class Backend {
  let impl: NoiseBackend.Backend!

  init(withZo zo: URL, andMod mod: String, andProc proc: String) {
    impl = NoiseBackend.Backend(withZo: zo, andMod: mod, andProc: proc)
  }

  public func archive(entryWithId id: UVarint) -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0000).write(to: out)
        id.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func commit(command s: String) -> Future<String, Entry> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0001).write(to: out)
        s.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Entry in
        return Entry.read(from: inp, using: &buf)
      }
    )
  }

  public func createDatabaseCopy() -> Future<String, String> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0002).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> String in
        return String.read(from: inp, using: &buf)
      }
    )
  }

  public func delete(entryWithId id: UVarint) -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0003).write(to: out)
        id.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func getDueEntries() -> Future<String, [Entry]> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0004).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> [Entry] in
        return [Entry].read(from: inp, using: &buf)
      }
    )
  }

  public func getPendingEntries() -> Future<String, [Entry]> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0005).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> [Entry] in
        return [Entry].read(from: inp, using: &buf)
      }
    )
  }

  public func installCallback(internalWithId id: UVarint, andAddr addr: Varint) -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0006).write(to: out)
        id.write(to: out)
        addr.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func markReadyForChanges() -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0007).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func mergeDatabaseCopy(atPath path: String) -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0008).write(to: out)
        path.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func parse(command s: String) -> Future<String, [Token]> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x0009).write(to: out)
        s.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> [Token] in
        return [Token].read(from: inp, using: &buf)
      }
    )
  }

  public func ping() -> Future<String, String> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x000a).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> String in
        return String.read(from: inp, using: &buf)
      }
    )
  }

  public func snooze(entryWithId id: UVarint, forMinutes minutes: UVarint) -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x000b).write(to: out)
        id.write(to: out)
        minutes.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func startScheduler() -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x000c).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func undo() -> Future<String, Void> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x000d).write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Void in }
    )
  }

  public func update(entryWithId id: UVarint, andCommand s: String) -> Future<String, Entry?> {
    return impl.send(
      writeProc: { (out: OutputPort) in
        UVarint(0x000e).write(to: out)
        id.write(to: out)
        s.write(to: out)
      },
      readProc: { (inp: InputPort, buf: inout Data) -> Entry? in
        return Entry?.read(from: inp, using: &buf)
      }
    )
  }

  public func installCallback(entriesDidChangeCb proc: @escaping (Bool) -> Void) -> Future<String, Void> {
    return NoiseBackend.installCallback(id: 0, rpc: self.installCallback(internalWithId:andAddr:)) { inp in
      var buf = Data(count: 8*1024)
      proc(
        Bool.read(from: inp, using: &buf)
      )
    }
  }

  public func installCallback(entriesDueCb proc: @escaping ([Entry]) -> Void) -> Future<String, Void> {
    return NoiseBackend.installCallback(id: 1, rpc: self.installCallback(internalWithId:andAddr:)) { inp in
      var buf = Data(count: 8*1024)
      proc(
        [Entry].read(from: inp, using: &buf)
      )
    }
  }
}
