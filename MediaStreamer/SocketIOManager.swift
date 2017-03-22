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
    
    //static let host = "http://75.188.54.41:45555"
    static let host = "http://172.28.15.153:45555"
    
    
    //Add accessor methods to interface with the socket.
    private static var socket: SocketIOClient = SocketIOClient(socketURL: URL(string: host)!)
    
    static func on(_ event: String!, callback: @escaping NormalCallback) {
        socket.on(event, callback: callback)
    }
    
    static func off(_ event: String!) {
        socket.off(event)
    }
    
    static func once(_ event: String!, callback: @escaping NormalCallback) {
        socket.once(event, callback: callback)
    }
    
    static func emit(_ event: String!, _ items: [SocketData], _ load: Bool, _ completion: ((String?) -> Void)?) {
        
        var overlay: UIView? = nil
        if load {
            print("Showing loading indiciator for socket emit")
            overlay = Helper.loading(Helper.getCurrentViewController()?.view, "Contacting server...")
        }
        
        //Not connected? Let's connect and then emit
        if socket.status != .connected {
            print("We aren't connected yet!")
            
            //If we're not already trying to connect, connect
            if socket.status != .connecting {
                
                //Register a listener for socket status changes
                print("Registering socket status listener")
                socket.onAny( { evt in
                    if evt.event == "connect" {
                        socket.onAny({evt in})
                        print("We connected. Emitting our message")
                        socket.emitWithAck(event, items).timingOut(after: 1, callback: { data in
                            overlay?.removeFromSuperview()
                            if let info = data as? [Any] {
                                if info.count > 0 {
                                    if let msg = info[0] as? Any {
                                        if let str = msg as? String {
                                            if str == "NO ACK" {
                                                Helper.alert(view: Helper.getCurrentViewController(), title: "Network Error", message: "An error occurred while attempting to contact the server.")
                                                return
                                            }
                                        }
                                        else if let val = msg as? Int {
                                            if val == 0 {
                                                Helper.alert(view: Helper.getCurrentViewController(), title: "Internal Error", message: "An internal error occurred in the server.")
                                                return
                                            }
                                        }
                                    }
                                }
                            }
                        })
                        print("Calling completion: \(completion)")
                        completion?(nil)
                        
                    }
                })
                
                print("We aren't connecting. Calling connect!")
                socket.connect()
            }
            
            //Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                if socket.status != .connected {
                    print("5 seconds passed and we didn't connect. Returning completion with error")
                    completion?(Constants.ERROR_TIMEOUT)
                }
            })
        }
        else {
            print("We're connected. Emitting our message")
            socket.emitWithAck(event, items).timingOut(after: 1, callback: { data in
                overlay?.removeFromSuperview()
                if let info = data as? [Any] {
                    if info.count > 0 {
                        if let msg = info[0] as? Any {
                            if let str = msg as? String {
                                if str == "NO ACK" {
                                    Helper.alert(view: Helper.getCurrentViewController(), title: "Network Error", message: "An error occurred while attempting to contact the server.")
                                    return
                                }
                            }
                            else if let val = msg as? Int {
                                if val == 0 {
                                    Helper.alert(view: UIApplication.shared
                                        .keyWindow?.rootViewController, title: "Internal Error", message: "An internal error occurred in the server.")
                                    return
                                }
                            }
                        }
                    }
                }
            })
            completion?(nil)
        }
    }
    
    static func joinRoom(view: UIViewController!, roomNum: String!, callback: @escaping (String, String, String?) -> Void) {
        
        var gotResponse = false
        
        emit("join room", [roomNum], false, { error in
            if error == nil {
                once("join reply") { data, ack in
                    print("join reply: \(data)")
                    gotResponse = true
                    
                    var error = false
                    var roomName: String? = nil
                    if let name = data[0] as? String {
                        if name == "nil" {
                            error = true
                        }
                        else {
                            roomName = name
                        }
                    }
                    else {
                        error = true
                    }
                    
                    if error {
                        callback("", "", "Error on join reply: \(data)")
                    }
                    else {
                        callback(roomNum, roomName!, nil)
                    }
                    
                }
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            if !gotResponse {
                print("Unsubscribing from 'join reply'")
                off("join reply")
                
                callback("", "", Constants.ERROR_TIMEOUT)
                
                Helper.alert(view: view, title: "Join Room Failed", message: "Connection to server timed out")
                
            }
        })
    }
    
    static func createRoom(view: UIViewController!, id: Int!, displayName: String!, callback: @escaping (String?) -> Void) {
        
        var gotResponse = false
        
        emit("create room", [displayName, id], false, { error in
            if error == nil {
                once("create reply") { data, ack in
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
                        }
                    }
                }
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            if !gotResponse {
                print("Unsubscribing from 'create reply'")
                off("create reply")
                
                callback(Constants.ERROR_TIMEOUT)
                
                Helper.alert(view: view, title: "Create Room Failed", message: "Connection to server timed out")
                
            }
        })
        
    }
    
    
}
