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
    
    static var socket: SocketIOClient = SocketIOClient(socketURL: NSURL(string: "http://192.168.1.117:80")! as URL)

}
