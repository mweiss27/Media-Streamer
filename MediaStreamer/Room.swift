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
    
    //(sid, name)
    private var users: [(String, String)]
    
    //Only used for displaying, not using for managing playback anymore
    var currentQueue: [SpotifySong] = []
    var currentSong: SpotifySong? = nil
    
    static var currentRoom: Room?
    
    init(roomController: RoomController, id: Int!) {
        self.roomController = roomController
        self.id = id
        self.users = []
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
    
    func addSong(song: SpotifySong) {
        Toast(text: "Song Added", delay: 0, duration: 0.5).show()
        
        print("Player is logged in? " + SpotifyApp.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.player.initialized.description)
        
        self.currentQueue.append(song)
    }
    
    func removeFromMediaQueue(song: SpotifySong!) {
        let id = song.id
        
        self.removeFromMediaQueue(id: id)
    }
    
    func removeFromMediaQueue(id: String!) {
        for i in 0..<self.currentQueue.count {
            if self.currentQueue[i].id == id {
                self.currentQueue.remove(at: i)
                Toast(text: "Song Removed", delay: 0, duration: 0.5).show()
                break
            }
        }
    }
    
    func playSong(_ id: String, _ startTime: Double) -> Bool {
        
        if !SpotifyApp.player.loggedIn {
            print("[ERROR] Player is not logged in")
            return false
        }
        
        if !SpotifyApp.player.initialized {
            print("[ERROR] Player is not initialized")
            return false
        }
        
        for i in 0..<self.currentQueue.count {
            let item = self.currentQueue[i]
            if item.id == id {
                print("Found the song in the queue to play!")
                item.play(startTime, callback: { (error) in
                    if error != nil {
                        Helper.alert(view: self.roomController, title: "Error on Playback", message: "An error occurred while attempting to play a song.")
                    }
                    else {
                        self.currentSong = item
                    }
                })
            }
        }
        
        return false
    }
    
    func setPlaying(_ playing: Bool, callback: @escaping (String?) -> Void) {
        if self.currentSong != nil {
            if let playback = SpotifyApp.player.playbackState {
                if playback.isPlaying == playing {
                    print("Requesting setPlaying, but that state is already the current")
                    callback(nil)
                    return
                }
            }
            SpotifyApp.player.setIsPlaying(playing) { (error) in
                if let error = error {
                    print("Error on setIsPlaying false: \(error.localizedDescription)")
                    Helper.alert(view: self.roomController, title: "Failed to \(playing ? "resume" : "pause")", message: "An error occurred while trying to \(playing ? "resume" : "pause") the song")
                }
                else {
                    print("Room.setPlaying success")
                }
                callback(error?.localizedDescription)
            }
        }
    }
    
    func seek(to: Double!, callback: @escaping (String?) -> Void) {
        if self.currentSong != nil {
            self.currentSong?.seek(to: to, callback: { error in
                if error != nil {
                    print("Error on seek(to: \(to)): \(error)")
                    Helper.alert(view: self.roomController, title: "Error on scrub", message: "An error occurred while attempting to scrub the song playback.")
                }
                else {
                    print("Room.seek success")
                }
                callback(error)
            })
        }
    }
    
}
