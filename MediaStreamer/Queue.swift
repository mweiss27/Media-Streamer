//
//  Queue.swift
//  MediaStreamer
//
//  https://www.raywenderlich.com/148141/swift-algorithm-club-swift-queue-data-structure
//  Modified to use Swift 3 syntax
//

import Foundation

class Queue<T: Equatable> {
    
    fileprivate var array = [T]()
    
    private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public var count: Int {
        return array.count
    }
    
    public func enqueue(_ element: T) {
        let before = self.count
        array.append(element)
        if self.count > before {
            print("Signalling our semaphore")
            self.semaphore.signal()
        }
    }
    
    public func dequeue() -> T? {
        
        let before = self.count
        defer {
            if self.count < before {
                print("Waiting our semaphore")
                self.semaphore.wait()
            }
        }
        
        if isEmpty {
            print("Queue is empty. Blocking until we get an element!")
            self.semaphore.wait()
        }
        return array.removeFirst()
    }
    
    public func remove(_ element: T) -> Bool {
        let before = self.count
        defer {
            if self.count < before {
                print("Waiting our semaphore")
                self.semaphore.wait()
            }
        }
        var index = -1
        for i in 0..<self.array.count {
            if self.array[i] == element {
                index = i
                break
            }
        }
        if index >= 0 {
            for i in index..<self.array.count-1 {
                self.array[i] = self.array[i+1]
            }
            self.array.removeLast()
            return true
        }
        return false
    }
    
    public func printContents() {
        for i in 0..<self.array.count {
            print("\(i): \(self.array[i])")
        }
    }
    
    public var front: T? {
        return array.first
    }
}
