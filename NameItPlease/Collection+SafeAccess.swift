//
//  Collection+SafeAccess.swift
//  NameItPlease
//
//  Created by Nick Gaens on 1/22/19.
//  Copyright © 2019 GPS nv. All rights reserved.
//

import Foundation

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
