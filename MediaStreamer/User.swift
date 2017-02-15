//
//  User.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class User {
    
    private var displayName: String!
    
    init(displayName: String!) {
        self.displayName = displayName
    }
    
    public func setDisplayName(displayName: String!) -> Bool {

        if displayName.characters.count == 0 || displayName.characters.count > 16 {
            return false
        }
        
        return true
    }
    
}
