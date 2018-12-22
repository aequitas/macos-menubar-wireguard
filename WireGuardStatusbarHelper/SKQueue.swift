// TODO: figure out how to get this using package manager (Cocoapods/SwiftPM)
// or switch to DispatchSource https://github.com/daniel-pedersen/SKQueue/issues/11

// https://github.com/daniel-pedersen/SKQueue
// The MIT License (MIT)

// Copyright (c) 2018 Daniel Pedersen

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

func ev_create(ident: UInt, filter: Int16, flags: UInt16, fflags: UInt32, data: Int, udata: UnsafeMutableRawPointer) -> kevent {
  var ev = kevent()
  ev.ident = ident
  ev.filter = filter
  ev.flags = flags
  ev.fflags = fflags
  ev.data = data
  ev.udata = udata
  return ev
}

public protocol SKQueueDelegate {
  func receivedNotification(_ notification: SKQueueNotification, path: String, queue: SKQueue)
}

public enum SKQueueNotificationString: String {
  case Rename
  case Write
  case Delete
  case AttributeChange
  case SizeIncrease
  case LinkCountChange
  case AccessRevocation
}

public struct SKQueueNotification: OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let None             = SKQueueNotification(rawValue: 0)
  public static let Rename           = SKQueueNotification(rawValue: 1 << 0)
  public static let Write            = SKQueueNotification(rawValue: 1 << 1)
  public static let Delete           = SKQueueNotification(rawValue: 1 << 2)
  public static let AttributeChange  = SKQueueNotification(rawValue: 1 << 3)
  public static let SizeIncrease     = SKQueueNotification(rawValue: 1 << 4)
  public static let LinkCountChange  = SKQueueNotification(rawValue: 1 << 5)
  public static let AccessRevocation = SKQueueNotification(rawValue: 1 << 6)
  public static let Default          = SKQueueNotification(rawValue: 0x7F)

  public func toStrings() -> [SKQueueNotificationString] {
    var s = [SKQueueNotificationString]()
    if contains(.Rename) { s.append(.Rename) }
    if contains(.Write) { s.append(.Write) }
    if contains(.Delete) { s.append(.Delete) }
    if contains(.AttributeChange) { s.append(.AttributeChange) }
    if contains(.SizeIncrease) { s.append(.SizeIncrease) }
    if contains(.LinkCountChange) { s.append(.LinkCountChange) }
    if contains(.AccessRevocation) { s.append(.AccessRevocation) }
    return s
  }
}

class SKQueuePath {
  var path: String
  var fileDescriptor: Int32
  var notification: SKQueueNotification

  init?(_ path: String, notification: SKQueueNotification) {
    self.path = path
    self.fileDescriptor = open((path as NSString).fileSystemRepresentation, O_EVTONLY, 0)
    self.notification = notification
    if self.fileDescriptor < 0 {
      return nil
    }
  }

  deinit {
    if self.fileDescriptor >= 0 {
      close(self.fileDescriptor)
    }
  }
}

public class SKQueue {
  private var kqueueId: Int32
  private var watchedPaths = [String: SKQueuePath]()
  private var keepWatcherThreadRunning = false
  public var delegate: SKQueueDelegate?

  public init?(delegate: SKQueueDelegate? = nil) {
    kqueueId = kqueue()
    if (kqueueId == -1) {
      return nil
    }
    self.delegate = delegate
  }

  deinit {
    keepWatcherThreadRunning = false
    removeAllPaths()
  }

  private func addPathToQueue(_ path: String, notifyingAbout notification: SKQueueNotification) -> SKQueuePath? {
    var pathEntry = watchedPaths[path]

    if pathEntry != nil {
      if pathEntry!.notification.contains(notification) {
        return pathEntry
      }
      pathEntry!.notification.insert(notification)
    } else {
      pathEntry = SKQueuePath(path, notification: notification)
      if pathEntry == nil {
        return nil
      }
      watchedPaths[path] = pathEntry!
    }

    var nullts = timespec(tv_sec: 0, tv_nsec: 0)
    var ev = ev_create(
      ident: UInt(pathEntry!.fileDescriptor),
      filter: Int16(EVFILT_VNODE),
      flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
      fflags: notification.rawValue,
      data: 0,
      udata: UnsafeMutableRawPointer(Unmanaged<SKQueuePath>.passRetained(watchedPaths[path]!).toOpaque())
    )

    kevent(kqueueId, &ev, 1, nil, 0, &nullts)

    if !keepWatcherThreadRunning {
      keepWatcherThreadRunning = true
      DispatchQueue.global().async(execute: watcherThread)
    }

    return pathEntry
  }

  private func watcherThread() {
    var ev = kevent(), timeout = timespec(tv_sec: 1, tv_nsec: 0), fd = kqueueId

    while (keepWatcherThreadRunning) {
      let n = kevent(fd, nil, 0, &ev, 1, &timeout)
      if n > 0 && ev.filter == Int16(EVFILT_VNODE) && ev.fflags != 0 {
        let pathEntry = Unmanaged<SKQueuePath>.fromOpaque(ev.udata).takeUnretainedValue()
        let notification = SKQueueNotification(rawValue: ev.fflags)
        DispatchQueue.global().async {
          self.delegate?.receivedNotification(notification, path: pathEntry.path, queue: self)
        }
      }
    }

    if close(fd) == -1 {
      NSLog("SKQueue watcherThread: Couldn't close main kqueue (%d)", errno)
    }
  }

  public func addPath(_ path: String, notifyingAbout notification: SKQueueNotification = SKQueueNotification.Default) {
    if addPathToQueue(path, notifyingAbout: notification) == nil {
      NSLog("SKQueue tried to add the path \(path) to watchedPaths, but the SKQueuePath was nil. \nIt's possible that the host process has hit its max open file descriptors limit.")
    }
  }

  public func isPathWatched(_ path: String) -> Bool {
    return watchedPaths[path] != nil
  }

  public func removePath(_ path: String) {
    if let pathEntry = watchedPaths.removeValue(forKey: path) {
      Unmanaged<SKQueuePath>.passUnretained(pathEntry).release()
    }
  }

  public func removeAllPaths() {
    watchedPaths.keys.forEach(removePath)
  }

  public func numberOfWatchedPaths() -> Int {
    return watchedPaths.count
  }

  public func fileDescriptorForPath(_ path: String) -> Int32 {
    guard watchedPaths[path] != nil else {
      return -1
    }

    return fcntl(watchedPaths[path]!.fileDescriptor, F_DUPFD)
  }
}
