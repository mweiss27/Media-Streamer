//
//  Room.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation
import Toaster
import AVFoundation

class Room {
    
    var mySid: String? = nil
    
    private let roomController: RoomController
    let id: Int
    var users: [Int: (String, String)]
    let queue: MediaQueue
    
    static var currentRoom: Room?
    
    init(roomController: RoomController, id: Int!) {
        self.roomController = roomController
        self.id = id
        self.users = [:]
        self.queue = MediaQueue()
        Room.currentRoom = self
    }
    
    func canInvokePlay() -> Bool {
        var firstSid: String? = nil
        var lowestInt: Int = Int.max
        for i in 0..<self.users.count {
            let cur = self.users[i]?.0
            let cur_i = (cur?.hashValue)!
            if firstSid == nil || cur_i < lowestInt {
                firstSid = cur
                lowestInt = cur_i
            }
        }
        return firstSid == self.mySid
    }
    
    func requestConnectedUsers(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
    }
    
    func requestCurrentMediaQueue(callback: (_ error: Error, _ data: Any) -> Void) {
        
        //TODO: Request asynchronously, invoke callback with result, or error
        //Assuming error == nil --> data == nil
        
    }
    
    func addToMediaQueue(song: SpotifySong) {
        let id = song.id
        let timestamp = Helper.currentTimeMillis() //Use time to synchronize order
        
        self.queue.enqueue(song)
        
        Toast(text: "Song Added", delay: 0, duration: 0.5).show()
        
        print("Queue:")
        self.queue.printContents()
        
        print("Player is logged in? " + SpotifyApp.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.player.initialized.description)
        
        if self.queue.currentMedia == nil && self.queue.count > 0 {
            
            if self.canInvokePlay() {
                print("I'm the first SID. Invoking play")
                self.playNextSong(startTime: 0.0, true)
            }
            else {
                print("I'm not the first SID. Not invoking play")
            }
        }
    }
    
    func removeFromMediaQueue(song: SpotifySong) {
        let id = song.id
        
        if self.queue.remove(song) {
            Toast(text: "Song Removed", delay: 0, duration: 0.5).show()
        }
        
        print("Queue:")
        self.queue.printContents()
    }
    
    func playNextSong(startTime: Double, _ broadcast: Bool!) -> Bool {
        
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
            
            print("Next Media: \(self.queue.currentMedia!.id)")
            self.queue.currentMedia?.play(startTime, callback: { (error) in
                if let error = error {
                    Helper.alert(view: self.roomController, title: "Error on Playback", message: "An error occurred while trying to play your song.")
                    return
                }
                
                if broadcast {
                    print("Broadcasting 'play'")
                    let now = Helper.currentTimeMillis()
                    SocketIOManager.emit("play", [self.id, Int(now)], { (error) in
                        if let error = error {
                            print("Error on emit: \(error)")
                            return
                        }
                        
                        //We don't have to do anything
                        //RoomController will be listening for client_play.
                        //It will include sid, and we can filter out our own requests
                        
                    })
                }
                else {
                    print("Not broadcasting 'play'")
                }
                
            })
            return true
        }
        else {
            print("Queue is empty!")
            self.pause(false)
            
            self.queue.currentMedia = nil
            self.roomController.currentSongName.text = ""
            self.roomController.currentArtistName.text = ""
            self.roomController.currentPlaybackTime.progress = 0.0
            
            return false
        }
    }
    
    func pause(_ broadcast: Bool) {
        if self.queue.currentMedia != nil {
            SpotifyApp.player.setIsPlaying(false) { (error) in
                if let error = error {
                    print("Error on setIsPlaying false: \(error.localizedDescription)")
                    Helper.alert(view: self.roomController, title: "Failed to Pause", message: "An error occurred while trying to pause the song")
                    return
                }
                if broadcast {
                    SocketIOManager.emit("pause", [], { (error) in
                    })
                }
            }
        }
    }
    
    func resume(_ broadcast: Bool) {
        if self.queue.currentMedia != nil {
            SpotifyApp.player.setIsPlaying(true) { (error) in
                if let error = error {
                    print("Error on setIsPlaying false: \(error.localizedDescription)")
                    Helper.alert(view: self.roomController, title: "Failed to Pause", message: "An error occurred while trying to pause the song")
                    return
                }
                if broadcast {
                    let currentPlaybackTime = SpotifyApp.player.playbackState.position
                    let now = Helper.currentTimeMillis()
                    SocketIOManager.emit("resume", [ Double(currentPlaybackTime), Int(now) ], { (error) in
                    })
                }
            }
        }
    }
    
    func seek(to: Double!) {
        if let currentMedia = self.queue.currentMedia {
            currentMedia.setPlaybackTime(time: to)
        }
    }
    
}
