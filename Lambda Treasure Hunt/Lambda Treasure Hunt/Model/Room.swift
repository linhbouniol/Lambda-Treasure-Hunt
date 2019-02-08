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
    var title: String?
    var coordinates: Coordinates? // Server returns a string and we need to part the string into coordinates to plot the rooms
    var players: [String]?
    var items: [String]?
    var messages: [String]?
    
    var lastVisitedDate: Date?
    
    init(roomID: Int, exits: [Direction : Int?]) {
        self.roomID = roomID
        self.exits = exits
    }
    
    var description: String {
        let mappedExits = exits.map { (arg0) -> String in
            
            let (key, value) = arg0
            
            if let value = value {
                return "\(key): \(value)"
            }
            
            return "\(key): ?"
        }
        
        return "Room \(roomID): \(mappedExits), Title: \(title ?? "N/A"), Messages: \(messages ?? ["N/A"]), Items: \(items ?? ["N/A"])"
    }
}
