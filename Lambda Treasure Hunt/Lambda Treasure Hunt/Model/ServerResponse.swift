//
//  ServerResponse.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

struct ServerResponse: Codable {
    var room_id: Int?
    var title: String?
    var description: String?
    var coordinates: String?
    var player: [String]?
    var items: [String]?
    var exits: [Direction]?
    var cooldown: Double?
    var errors: [String]?
    var messages: [String]?
    
    var name: String?
    var encumbrance: Int?
    var strength: Int?
    var speed: Int?
    var gold: Int?
    var inventory: [String]?
}
