//
//  extensions.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/23.
//

import Foundation
import SwiftUI

/// disable SwiftUI TextField focus border
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

/// disable TextEditor's smart quote
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
        }
    }
}


