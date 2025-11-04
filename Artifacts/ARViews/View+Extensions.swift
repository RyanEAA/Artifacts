//
//  View+Extensions.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/13/25.
//

import SwiftUI

extension View {
    
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View{
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }
}
