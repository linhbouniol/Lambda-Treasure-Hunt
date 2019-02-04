//
//  Direction.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

enum Direction: String, Codable {
    case north = "n"
    case south = "s"
    case east = "e"
    case west = "w"
    
    var opposite: Direction {
        switch self {
        case .north:
            return .south
        case .south:
            return .north
        case .east:
            return .west
        case .west:
            return .east
        }
    }
}
