//
//  Media.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

protocol Media {
    
    var id: Any {
        set
        get
    }
    
    func play()
    func setPlaybackTime(time: Double!)
    
}
