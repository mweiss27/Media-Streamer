//
//  Helper.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/2/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class Helper {
    
    static func setBorder(_ view: UIView!, _ color: UIColor!, _ width: CGFloat!) {
        view.layer.borderColor = color.cgColor
        view.layer.borderWidth = width
    }
    
    static func getAllSongs(_ songs: [Any?]) -> [SPTPlaylistTrack] {
        var result = [SPTPlaylistTrack]()
        
        for obj in songs {
            if obj is SPTPlaylistTrack {
                result.append(obj as! SPTPlaylistTrack)
            }
        }
        
        return result
    }
    
    static func removeAllSubviews(view: UIView!) {
        for subview in view.subviews {
            subview.removeFromSuperview()
        }
    }
    
    static func currentTimeMillis() -> Int64 {
        let nowDouble = NSDate().timeIntervalSince1970
        return Int64(nowDouble*1000)
    }
    
    static func alert(view: UIViewController!, title: String!, message: String!) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        view.present(alert, animated: true, completion: nil)
    }
    
    // Returns the most recently presented UIViewController (visible)
    class func getCurrentViewController() -> UIViewController? {
        print("getCurrentViewController")
        // If the root view is a navigation controller, we can just return the visible ViewController
        if let navigationController = getNavigationController() {
            print("Returning navController.visible")
            return navigationController.visibleViewController
        }
        
        // Otherwise, we must get the root UIViewController and iterate through presented views
        if let rootController = UIApplication.shared.keyWindow?.rootViewController {
            print("Using rootViewController")
            var currentController: UIViewController! = rootController
            
            // Each ViewController keeps track of the view it has presented, so we
            // can move from the head to the tail, which will always be the current view
            while( currentController.presentedViewController != nil ) {
                print("Found a presented VC")
                currentController = currentController.presentedViewController
            }
            return currentController
        }
        return nil
    }
    
    // Returns the navigation controller if it exists
    class func getNavigationController() -> UINavigationController? {
        
        if let navigationController = UIApplication.shared.keyWindow?.rootViewController  {
            
            return navigationController as? UINavigationController
        }
        return nil
    }
    
    static func loading(_ view: UIView!, _ message: String?) -> UIView {
        let overlay = UIView.init(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        if let message = message {
            let msg = UILabel.init(frame: overlay.bounds)
            msg.center = CGPoint(x: overlay.center.x, y: overlay.center.y - 30)
            msg.textColor = UIColor.white
            msg.text = message
            msg.textAlignment = .center
            overlay.addSubview(msg)
        }
        
        let activity = UIActivityIndicatorView.init(frame: overlay.bounds)
        activity.center = overlay.center
        overlay.addSubview(activity)
        
        view.addSubview(overlay)
        
        activity.startAnimating()
        
        return overlay
    }
    
}
