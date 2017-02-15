//
//  YoutubeVideo.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class YoutubeVideo {
    
    internal var id: Any
    
    init(id: String) {
        self.id = id
    }
    
    func play() {
        print("Playing YoutubeVideo: \(self.id)")
        
    }
    
    func setPlaybackTime(time: Double!) {
            print("Adjusting playback time of YoutubeVideo")
    }
    
}
