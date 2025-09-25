//
//  Extensions.swift
//  Artifacts
//
//  Created by Swapnil Puri on 9/24/25.
//

import SwiftUI

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
