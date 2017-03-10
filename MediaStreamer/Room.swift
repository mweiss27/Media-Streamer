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
    private var users: [(String, String)]
    let queue: MediaQueue
    
    static var currentRoom: Room?
    
    init(roomController: RoomController, id: Int!) {
        self.roomController = roomController
        self.id = id
        self.users = []
        self.queue = MediaQueue()
        Room.currentRoom = self
    }
    
    func addUser(sid: String!, name: String!) -> Bool! {
        var found = false
        if self.users.count > 0 {
            for i in 0..<self.users.count {
                let tuple = self.users[i]
                if sid == tuple.0 {
                    found = true
                    break
                }
            }
        }
        if !found {
            print("addUser success -- \(sid)")
            self.users.append((sid, name))
            return true
        }
        print("addUser fail -- \(sid)")
        return false
    }
    
    func removeUser(sid: String!) -> Bool! {
        var current: Int = -1
        if self.users.count > 0 {
            for i in 0..<self.users.count {
                if self.users[i].0 == sid {
                    current = i
                }
            }
        }
        if current >= 0 {
            print("removeUser success -- \(sid)")
            self.users.remove(at: current)
            return true
        }
        print("removeUser fail -- \(sid)")
        return false
    }
    
    func getUser(index: Int) -> (String, String)? {
        if index >= 0 && index < self.numUsers() {
            return self.users[index]
        }
        return nil
    }
    
    func numUsers() -> Int! {
        return self.users.count
    }
    
    func clearUsers() {
        self.users.removeAll()
    }
    
    func canInvokePlay() -> Bool {
        var firstSid: String? = nil
        var lowestInt: Int = Int.max
        for i in 0..<self.users.count {
            let cur = (self.users[i]).0
            let cur_i = cur.hashValue
            if firstSid == nil || cur_i < lowestInt {
                firstSid = cur
                lowestInt = cur_i
            }
        }
        return firstSid == self.mySid
    }
    
    func addToMediaQueue(song: SpotifySong, allowPlay: Bool) {
        let id = song.id
        let timestamp = Helper.currentTimeMillis() //Use time to synchronize order
        
        self.queue.enqueue(song)
        
        Toast(text: "Song Added", delay: 0, duration: 0.5).show()
        
        print("Queue:")
        self.queue.printContents()
        
        print("Player is logged in? " + SpotifyApp.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.player.initialized.description)
        
        if allowPlay && self.queue.currentMedia == nil && self.queue.count > 0 {
            
            if self.canInvokePlay() {
                print("I'm the first SID. Invoking play")
                self.playNextSong(startTime: 0.0, true)
            }
            else {
                print("I'm not the first SID. Not invoking play. Someone should signal us")
            }
        }
        else {
            print("Either !allowPlay, current is nil, or count is 0: \(allowPlay), \(self.queue.currentMedia), \(self.queue.count)")
        }
    }
    
    func removeFromMediaQueue(song: SpotifySong!) {
        let id = song.id
        
        self.removeFromMediaQueue(id: id)
    }
    
    func removeFromMediaQueue(id: String!) {
        for item in self.queue.array {
            if item.id == id {
                if self.queue.remove(item) {
                    Toast(text: "Song Removed", delay: 0, duration: 0.5).show()
                    
                    print("Queue:")
                    self.queue.printContents()
                }
            }
        }
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
        
        let previousSong = self.queue.currentMedia
        
        if !self.queue.isEmpty {
            print("Queue is not empty, getting the next item and playing")
            self.queue.currentMedia = self.queue.dequeue()
            
            print("Next Media: \(self.queue.currentMedia!.id)")
            print("Invoking play(\(startTime))")
            self.queue.currentMedia?.play(startTime, callback: { (error) in
                if error != nil {
                    Helper.alert(view: self.roomController, title: "Error on Playback", message: "An error occurred while trying to play your song.")
                    return
                }
                
                if broadcast {
                    print("Broadcasting 'play'")
                    let now = Helper.currentTimeMillis()
                    SocketIOManager.emit("play", [(self.queue.currentMedia?.id)!, Int(now)], { (error) in
                        if let error = error {
                            print("Error on emit: \(error)")
                            return
                        }
                        
                        //We don't have to do anything
                        //RoomController will be listening for client_play.
                        //It will include sid, and we can filter out our own requests
                        
                        if previousSong != nil {
                            SocketIOManager.emit("remove_queue", [previousSong!.id], { error in })
                        }
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
            
            if broadcast {
                if previousSong != nil {
                    //Others will get a 'client_remove' for the current song
                    SocketIOManager.emit("remove_queue", [previousSong!.id], { error in })
                }
            }
            
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
