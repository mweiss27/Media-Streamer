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
        self.queue = MediaQueue()
    }
    
    func requestConnectedUsers(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
    }
    
    func requestCurrentMediaQueue(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
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
        
        print("Player is logged in? " + SpotifyApp.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.player.initialized.description)
        
        if self.queue.currentMedia == nil && self.queue.count > 0 {
            self.playNextSong()
        }
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
    
    func playNextSong() -> Bool {
        
        if !SpotifyApp.player.loggedIn {
            print("[ERROR] Player is not logged in")
            return false
        }
        
        if !SpotifyApp.player.initialized {
            print("[ERROR] Player is not initialized")
            return false
        }
        
        if !self.queue.isEmpty {
            print("Queue is not empty, getting the next item and playing")
            self.queue.currentMedia = self.queue.dequeue()
            
            print("Next Media: \(self.queue.currentMedia!)")
            self.queue.currentMedia?.play()
            return true
        }
        else {
            print("Queue is empty!")
            self.queue.currentMedia?.pause()
            self.queue.currentMedia = nil
            return false
        }
    }
    
    func pauseCurrentSong() {
        if let currentMedia = self.queue.currentMedia {
            currentMedia.pause()
        }
    }
    
    func resumeCurrentSong() {
        if let currentMedia = self.queue.currentMedia {
            currentMedia.resume()
        }
    }
    
    func seek(to: Double!) {
        if let currentMedia = self.queue.currentMedia {
            currentMedia.setPlaybackTime(time: to)
        }
    }
    
}
