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
    //static var socket: SocketIOClient = SocketIOClient(socketURL: URL(string: "http://192.168.1.16:80")!)

    // ngrok
    static var socket: SocketIOClient = SocketIOClient(socketURL: NSURL(string:
        "http://6ca7bfe4.ngrok.io"
        )! as URL)
    
    
    static func createRoom(view: UIViewController!, id: Int!, displayName: String!, callback: @escaping (String?) -> Void) {
        socket.emit("create room", displayName, id)
        
        var gotResponse = false
        
        socket.once("create reply") { data, ack in
            print("create reply: \(data)")
            gotResponse = true
            if let response = data[0] as? String {
                if response == "1" {
                    print("create reply = 1")
                    callback(nil)
                }
                else {
                    print("create reply ~= 1")
                    callback("Invalid create response: \(response)")
                    Helper.alert(view: view, title: "Create Room Failed", message: "Invalid response from the server")
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            if !gotResponse {
                print("Unsubscribing from 'create reply'")
                socket.off("create reply")
                
                callback("Connection timed out.")
                
                Helper.alert(view: view, title: "Create Room Failed", message: "Connection to server timed out")
                
            }
        })
        
    }
    
    
}
