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
    
    
    static func mediaId(_ media: Media) -> Int {
        if media is SpotifySong {
            return 1
        }
        else if media is YoutubeVideo {
            return 2
        }
        return -1
    }
    
}
