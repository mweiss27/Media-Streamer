//
//  ViewController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/20/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var loginButton: UIButton!
    
    var appDelegate: AppDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        
        print("ViewController is displayed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let storedSession: SPTSession = self.appDelegate?.restoreSession() {
            print("We have a session stored!")
            if storedSession.isValid() {
                print("[2] We have a valid session. We need to transition to the info view")
                self.performSegue(withIdentifier: "loginToInfo", sender: self)
            }
        }
        else {
            print("We didn't find a stored session")
        }
    }
    
    @IBAction func loginWithSpotify(_ sender: Any) {
        print("loginWithSpotify!")
        if SPTAuth.supportsApplicationAuthentication() {
            UIApplication.shared.open(SPTAuth.defaultInstance().spotifyAppAuthenticationURL(), options: [:], completionHandler: nil)
        }
        else {
            let loginURL = SPTAuth.loginURL(forClientId: self.appDelegate?.clientID,
                                            withRedirectURL: URL(string: (self.appDelegate?.redirectURL)!),
                                            scopes: self.appDelegate?.requestedScopes,
                                            responseType: "token")
            
            UIApplication.shared.open(loginURL!, options: [:], completionHandler: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

