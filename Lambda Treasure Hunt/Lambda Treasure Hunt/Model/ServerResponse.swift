//
//  ServerResponse.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

struct ServerResponse: Codable {
    var room_id: Int? = nil
    var title: String? = nil
    var description: String? = nil
    var coordinates: String? = nil
//    var player: [Any]? = nil
    var items: [String]? = nil
    var exits: [Direction]? = nil
    var cooldown: Double? = nil
    var errors: [String]? = nil
    var messages: [String]? = nil
}
