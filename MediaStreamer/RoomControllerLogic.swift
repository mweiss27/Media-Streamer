//
//  RoomControllerLogic.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 3/14/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation
import Toaster

class RoomControllerLogic {
    
    private let roomController: RoomController
    
    init(_ roomController: RoomController) {
        self.roomController = roomController
    }
    
    func cleanupSocket() {
        SocketIOManager.off("add user")
        SocketIOManager.off("remove user")
        SocketIOManager.off("connect")
        SocketIOManager.off("client_add")
        SocketIOManager.off("client_play")
        SocketIOManager.off("client_remove")
        SocketIOManager.off("client_pause")
        SocketIOManager.off("client_resume")
        SocketIOManager.off("client_stop")
        SocketIOManager.off("client_scrub")
        SocketIOManager.off("client_change_display")
    }
    
    func setupSocket() {
        
        print("Registering add user")
        SocketIOManager.on("add user", callback: { (data, ack) in
            print("add user response: \(data)")
            if let values = data[0] as? [String] {
                let sid = values[0], name = values[1]
                if sid != self.roomController.room?.mySid {
                    print("add user received, it's not me -- \(name) -- \(sid)")
                    self.roomController.addUserToTable(sid, name)
                }
                else {
                    print("add user, but it's me. Ignoring")
                }
            }
            else {
                print("Invalid data line: \(data[0]) -- (\(data.count))")
            }
        })
        
        print("Registering remove user")
        SocketIOManager.on("remove user", callback: {[weak self] data, ack in
            print("remove user -- \(data)")
            if let sidRemoving = data[0] as? String {
                if (self?.roomController.room?.removeUser(sid: sidRemoving))! {
                    self?.roomController.currentUsersTable.reloadData()
                }
            }
            else {
                print("invalid data param")
            }
        })
        
        print("Registering connect")
        SocketIOManager.on("connect", callback: {[weak self] data, ack in
            print("connect")
            self?.roomController.room?.clearUsers()
            let defaults = UserDefaults()
            let currRoom = defaults.string(forKey: "currRoom")
            if currRoom != nil{
                let nickname = defaults.string(forKey: "displayName")
                if nickname != nil{
                    SocketIOManager.emit("enter room", [currRoom!, nickname!], false, nil)
                }else{
                    SocketIOManager.emit("enter room", [currRoom!, "Anonymous"], false, nil)
                }
            }
        })
        
        print("Registering client_add")
        SocketIOManager.on("client_add", callback: {[weak self] data, ack in
            print("client_add received: \(data)")
            if let info = data[0] as? [String] {
                if info.count >= 2 {
                    let id = info[0]
                    let name = info[1]
                    self?.roomController.room?.addSong(song: SpotifySong(id, name))
                }
                else {
                    print("[ERROR] client_add has invalid params: \(info)")
                }
            }
            else {
                print("Invalid data. Expected a [String]")
            }
        })
        
        print("Registering client_play")
        SocketIOManager.on("client_play", callback: {[weak self] data, ack in
            print("client_play")
            if let info = data[0] as? [String] {
                if info.count >= 2 {
                    let songId = info[0]
                    let startTime = info[1]
                    let now = Helper.currentTimeMillis()
                    print("client_play received: \(songId) -- \(startTime)")
                    print("Now: \(now)")
                    
                    var dt = Double(now - Int64(startTime)!) / 1000.0
                    if dt < 0 {
                        print("[ERROR] dt is subzero! \(dt)")
                        dt = 0.0
                    }
                    print("Valid client_play: \(songId) -- \(startTime)")
                    print("startTime: dt=\(dt)")
                    
                    self?.roomController.room?.playSong(songId, dt)
                }
                else {
                    print("[ERROR] info.count is not >= 2")
                }
            }
            else {
                print("[ERROR] data is not a [String]")
            }
        })
        
        SocketIOManager.on("client_remove", callback: { [weak self] data, ack in
            print("client_remove: \(data)")
            if let info = data[0] as? [String] {
                let songId = info[0]
                let removeFirst = info[1]
                print("Removing \(songId) from queue")
                let startIndex = (removeFirst == "True") ? 0 : 1
                self?.roomController.room?.removeFromMediaQueue(id: songId, startIndex: startIndex)
            }
            else {
                print("info is not a [String] -- \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_pause")
        SocketIOManager.on("client_pause", callback: { [weak self] data, ack in
            print("client_pause received")
            self?.roomController.room?.setPlaying(false, callback: { error in
                if error == nil {
                    print("client_pause success")
                }
            })
        })
        
        print("Registering client_resume")
        SocketIOManager.on("client_resume", callback: { [weak self] data, ack in
            print("client_resume received")
            if let info = data[0] as? [String] {
                if info.count > 0 {
                    let songId = info[0]
                    let resume_time = info[1]
                    let responseTime = info[2]
                    var dt = Double(Helper.currentTimeMillis() - Int64(responseTime)!)
                    if dt < 0 {
                        dt = 0
                    }
                    dt = dt / 1000.0
                    if self?.roomController.room?.currentSong != nil {
                        self?.roomController.room?.setPlaying(true, callback: { error in
                            if error == nil {
                                self?.roomController.room?.seek(to: Double(resume_time)! + dt - 1, callback: { error in
                                    print("client_resume success")
                                })
                            }
                            else {
                                print("error on SetPlaying: \(error)")
                            }
                        })
                    }
                    else {
                        self?.roomController.room?.playSong(songId, Double(resume_time)! + dt)
                    }
                }
                
            }
            else {
                print("Invalid info. Expected [String]. Got: \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_stop")
        SocketIOManager.on("client_stop", callback: { [weak self] data, ack in
            print("client_stop")
            
            if self?.roomController.room?.currentSong != nil {
                SpotifyApp.player.setIsPlaying(false, callback: { error in
                    if error != nil {
                        Helper.alert(view: self?.roomController, title: "Error while stopping", message: "An error occurred while attempting to stop the player.")
                    }
                })
            }
            
            self?.roomController.room?.currentSong = nil
            self?.roomController.room?.currentQueue = []
            
            self?.roomController.currentSongName.text = ""
            self?.roomController.currentArtistName.text = ""
            self?.roomController.currentPlaybackTime.progress = 0.0
            
            if let player = self?.roomController.spotifyPlayer {
                player.performSegue(withIdentifier: Constants.UnwindToRoom, sender: player)
            }
        })
        
        print("Registering client_scrub")
        SocketIOManager.on("client_scrub", callback: { [weak self] data, ack in
            print("client_scrub")
            if let info = data[0] as? [String] {
                let scrub_time = Double(info[0])!
                let response_time = Double(info[1])!
                let now = Double(Helper.currentTimeMillis())
                
                
                var dt = (now - response_time)
                if dt < 0 {
                    dt = 0
                }
                dt = dt / 1000.0
                print("Received playback: \(time) -- dt: \(dt)")
                self?.roomController.room?.seek(to: scrub_time + dt, callback: { error in
                    if error != nil {
                        print("error on client_playback seek")
                    }
                })
            }
            else {
                print("Invalid info. Expected [String]. Got: \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_change_display. HomeController: \(self.roomController.homeController)")
        SocketIOManager.on("client_change_display", callback: { data, ack in
            if let info = data[0] as? [String] {
                let newName = info[0]
                self.roomController.navigationItem.title = newName
                
                
                let result = self.roomController.homeController?.db.execute(sql: "UPDATE Room SET DisplayName=? WHERE RoomNum=?", parameters: [newName, (self.roomController.room?.id)!])
                
                if result != 0 {
                    print("Result: \(result)")
                    Toast.init(text: "Room name changed", delay: 0, duration: 1.5).show()
                }
                else {
                    print("nil result")
                    Toast.init(text: "Failed to change room name", delay: 0, duration: 1.5).show()
                }
            }
            else {
                print("info is not a [String]")
            }
        })
        
    }
    
}
