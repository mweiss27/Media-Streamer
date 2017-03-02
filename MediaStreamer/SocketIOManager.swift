//
//  SocketIOManager.swift
//  MediaStreamer
//
//  Created by Adam Tyler on 2/11/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import SocketIO

class SocketIOManager: NSObject {
    //static let sharedSocket = SocketIOManager()
    
    // Remote
    //static var socket: SocketIOClient = SocketIOClient(socketURL: NSURL(string: "http://173.88.84.254:25468")! as URL)
    
    // Local
    static var socket: SocketIOClient = SocketIOClient(socketURL: URL(string: "http://192.168.1.16:80")!)

    // ngrok
    //static var socket: SocketIOClient = SocketIOClient(socketURL: NSURL(string: "http://go.osu.edu/MediaStreamer")! as URL)
    
    
}
