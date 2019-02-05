//
//  Room.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

class Room: CustomStringConvertible, Codable {
    var roomID: Int
    var exits: [Direction : Int?] = [:]
    
    init(roomID: Int, exits: [Direction : Int?]) {
        self.roomID = roomID
        self.exits = exits
    }
    
    var description: String {
        return "Room \(roomID): \(exits)"
    }
}
