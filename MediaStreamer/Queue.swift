//
//  Queue.swift
//  MediaStreamer
//
//  https://www.raywenderlich.com/148141/swift-algorithm-club-swift-queue-data-structure
//  Modified to use Swift 3 syntax
//

import Foundation

class Queue<T> {
    
    fileprivate var array = [T]()
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public var count: Int {
        return array.count
    }
    
    public func enqueue(_ element: T) {
        array.append(element)
    }
    
    public func dequeue() -> T? {
        if isEmpty {
            return nil
        } else {
            return array.removeFirst()
        }
    }
    
    public var front: T? {
        return array.first
    }
}
