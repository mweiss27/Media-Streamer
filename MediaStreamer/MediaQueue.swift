//
//  MediaQueue.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class MediaQueue: Queue<Media> {
    
    private let waitForCurrentToFinishSemaphore = DispatchSemaphore(value: 1)
    
    private(set) public var currentMedia: Media?
    private var onMediaChange: (_ media: Media?) -> Void
    
    init(onMediaChange: @escaping (_ media: Media?) -> Void) {
        self.onMediaChange = onMediaChange
    }
    
    public func start() {
        DispatchQueue.init(label: "manageMediaQueue").async {
            while true {
                print("Waiting for the current playing position to be available")
                self.waitForCurrentToFinishSemaphore.wait()
                print("Current is available. Fetching an item from the queue")
                self.currentMedia = self.dequeue()
                
                
            }
        }
    }
    
    
}
