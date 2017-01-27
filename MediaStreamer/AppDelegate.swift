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
class AppDelegate: UIResponder, UIApplicationDelegate, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    static let clientID = "2da635f7c6224a24b10cd8c2566b4e8b"
    static let redirectURL = "mediastreamer-spotify-auth://callback"
    static let requestedScopes = [ SPTAuthStreamingScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistReadCollaborativeScope ]
    
    static let tokenSwapURL = "http://localhost:1234/swap"
    static let tokenRefreshServiceURL = "http://localhost:1234/refresh"
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        print("Application init")
        
        SPTAuth.defaultInstance().redirectURL = URL(string: AppDelegate.redirectURL)
        SPTAuth.defaultInstance().clientID = AppDelegate.clientID
        SPTAuth.defaultInstance().requestedScopes = AppDelegate.requestedScopes
        SPTAuth.defaultInstance().tokenSwapURL = URL(string: AppDelegate.tokenSwapURL)
        SPTAuth.defaultInstance().tokenRefreshURL = URL(string: AppDelegate.tokenRefreshServiceURL)
        
        print("init finished")
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        let b = SPTAuth.defaultInstance().canHandle(url)
        print("application received url: \(url.absoluteString)")
        print("canHandle? " + String(b))
        SPTAuth.defaultInstance().handleAuthCallback(withTriggeredAuthURL: url, callback: { (error,  session) in
            print("handleAuthCallBack has returned. Callback running")
            if error != nil {
                print("Error: " + error!.localizedDescription)
            }
            else {
                print("No error, we were able to handle!")
                if session != nil {
                    self.saveSession(session: session!)
                    if (session?.isValid())! {
                        print("[1] We have a valid session. We need to transition to the info view")
                        let loginView = (self.window?.rootViewController as! ViewController)
                        loginView.performSegue(withIdentifier: "loginToInfo", sender: nil)
                    }
                    else {
                        print("We attempted to login, but the session isn't valid!")
                    }
                }
            }
        })
        
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
    
    func saveSession(session: SPTSession) {
        print("Saving an SPTSession")
        
        let userDefaults = UserDefaults.standard
        let sessionData = NSKeyedArchiver.archivedData(withRootObject: session)
        
        userDefaults.set(sessionData, forKey: "SpotifySession")
        userDefaults.synchronize()
        
        SPTAuth.defaultInstance().session = session
        print("Save success")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        print("applicationWillResignActive")
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        print("applicationDidEnterBackground")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        print("applicationWillEnterForeground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        print("applicationDidBecomeActive")
        
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        print("applicationWillTerminate")
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("SPOTIFY LOGGED IN")
    }
    
    func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController!) {
        print("SPOTIFY LOGGED OUT")
    }
    
}

