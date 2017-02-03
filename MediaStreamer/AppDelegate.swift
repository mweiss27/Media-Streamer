//
//  AppDelegate.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/20/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import SafariServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    let audioController: SPTCoreAudioController = SPTCoreAudioController.init()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        print("Application init")
        
        SPTAuth.defaultInstance().redirectURL = URL(string: Constants.redirectURL)
        SPTAuth.defaultInstance().clientID = Constants.clientID
        SPTAuth.defaultInstance().requestedScopes = Constants.requestedScopes
        SPTAuth.defaultInstance().tokenSwapURL = URL(string: Constants.tokenSwapURL)
        SPTAuth.defaultInstance().tokenRefreshURL = URL(string: Constants.tokenRefreshServiceURL)
        
        print("init finished")
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        let b = SPTAuth.defaultInstance().canHandle(url)
        print("application received url: \(url.absoluteString)")
        print("canHandle? " + String(b))
        if SPTAuth.defaultInstance().canHandle(url) {
            SPTAuth.defaultInstance().handleAuthCallback(withTriggeredAuthURL: url, callback: { (error,  session) in
                print("handleAuthCallBack has returned. Callback running")
                if error != nil {
                    print("Error on handleAuthCallback: " + error!.localizedDescription)
                    print("Session is probably nil? \(session)")
                }
                else {
                    print("No error, we were able to handle!")
                    if session != nil {
                        self.saveSession(session: session!)
                        if (session?.isValid())! {
                            print("[1] We have a valid session. We need to transition to the info view")
                            let loginView = (self.window?.rootViewController as! ViewController)
                            loginView.performSegue(withIdentifier: Constants.LogintoPlaylists, sender: nil)
                        }
                        else {
                            print("We attempted to login, but the session isn't valid!")
                        }
                    }
                }
            })
        }
        else {
            print("We can't handle URL: \(url.absoluteString)")
        }
        return false
    }
    
    func restoreSession() -> SPTSession? {
        let userDefaults = UserDefaults.standard
        if let sessionData = userDefaults.object(forKey: "SpotifySession") {
            if let session = NSKeyedUnarchiver.unarchiveObject(with: sessionData as! Data) as? SPTSession {
                print("We found an SPTSession")
                SPTAuth.defaultInstance().session = session
            }
        }
        return SPTAuth.defaultInstance().session
    }
    
    func saveSession(session: SPTSession?) {
        var sess = session
        print("Saving an SPTSession")
        if sess == nil {
            sess = SPTSession()
        }
        
        let userDefaults = UserDefaults.standard
        let sessionData = NSKeyedArchiver.archivedData(withRootObject: sess!)
        
        userDefaults.set(sessionData, forKey: "SpotifySession")
        userDefaults.synchronize()
        
        SPTAuth.defaultInstance().session = sess
        print("Save success")
    }
    
    
}

