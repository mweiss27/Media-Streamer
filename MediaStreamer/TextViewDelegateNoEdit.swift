//
//  TextViewDelegateNoEdit.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 3/22/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class TextViewDelegateNoEdit: UIViewController, UITextViewDelegate {
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return false
    }
    
}
