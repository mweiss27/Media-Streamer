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
    
    static var socket: SocketIOClient = SocketIOClient(socketURL: NSURL(string: "http://173.88.84.254:25468")! as URL)

}
