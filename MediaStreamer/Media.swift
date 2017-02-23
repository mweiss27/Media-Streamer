//
//  Media.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class Media: Equatable {
    
    var id: String?
    
    init(id: String!) {
        self.id = id
    }
    
    func play() {
        fatalError("You cannot use a Media object. Create this as a subclass!")
    }
    
    func setPlaybackTime(time: Double!) {
        fatalError("You cannot use a Media object. Create this as a subclass!")
    }
 
    
    static func ==(lhs: Media, rhs: Media) -> Bool {
        return lhs.id == rhs.id
    }
}
