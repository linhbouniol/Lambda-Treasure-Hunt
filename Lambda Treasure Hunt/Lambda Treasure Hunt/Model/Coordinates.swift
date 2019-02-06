//
//  Coordinates.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/5/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

struct Coordinates: Codable {
    var x: Int
    var y: Int
    
    // Server returns coordinates with "(67,93)", so we want to parse out the two values and assign them to x and y
    
    init?(string: String) {
        
        // Split based on “,”: “(67,93)” => [“(67”, “93)”]
        // Remove the parentheses => “(67” => “67”, “97)” => “97”
        // Parse the Int => “67” => 67
        
        let components = string.split(separator: ",")
        guard components.count == 2 else { return nil }
        
        guard let firstNumberString = components[0].split(separator: "(").first, let secondNumberString = components[1].split(separator: ")").first else { return nil }
        
        guard let firstNumber = Int(firstNumberString), let secondNumber = Int(secondNumberString) else { return nil }
        
        self.x = firstNumber
        self.y = secondNumber
        
    }
}
