//
//  Room.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation
import Toaster

class Room {
    
    let id: Int
    var users: [String]
    let queue: MediaQueue
    
    init(id: Int!) {
        self.id = id
        self.users = []
        self.queue = MediaQueue(onMediaChange: { (media) in
            
        })
    }
    
    func requestConnectedUsers(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
    }
    
    func requestCurrentMediaQueue(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
    }
    
    func onMediaChange(_ media: Media) {
    
    }
    
    func addToMediaQueue(media: Media) {
        print("addToMediaQueue: Type=\(Helper.mediaId(media)), Id=\(media.id)")
        let id = media.id
        let contentProvider = Helper.mediaId(media)
        let timestamp = Helper.currentTimeMillis() //Use time to synchronize order
        
        /*
         TODO: Send a message to the server including:
            contentProvider -- a value to represent Spotify, Youtube, etc
            id -- the id of this content, specific to the provider. A Spotify URI, video id, etc
            timestamp -- The time the user is adding to the queue, used to handle multiple requests at once
         
            Note: It is easier for the server to handle checking for duplicates, since it is the central hub for what each user is seeing.
         
            Note: Only modify the local queue upon successful add
        */
        
        self.queue.enqueue(media)
        
        Toast(text: "Song Added", delay: 0, duration: 0.5).show()
        
        print("Queue:")
        self.queue.printContents()
        
    }
    
    func removeFromMediaQueue(media: Media) {
        let id = media.id
        let contentProvider = Helper.mediaId(media)
        
        /*
         TODO: Send a message to the server including:
            contentProvider -- a value to represent Spotify, Youtube, etc
            id -- the id of this content, specific to the provider. A Spotify URI, video id, etc

            Note: Only modify the local queue upon successful remove
         
         */
        
        if self.queue.remove(media) {
            Toast(text: "Song Removed", delay: 0, duration: 0.5).show()
        }
        
        print("Queue:")
        self.queue.printContents()
    }
    
}
