//
//  Map.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

class Map {
    var rooms: [Int : Room] = [:]   // roomID: room, which has the exits, title, messages, etc
    var currentRoom: Room?
    var player = Player()
    
    var shopRoom: Room?
    
    var currentMessages: [String]?
    var currentErrors: [String]?
    
    init() {
        // Loading the map file
        let fileURL = self.saveFileURL
        NSLog("%@", "Loading file from \(fileURL)")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedRooms = try JSONDecoder().decode([Int : Room].self, from: data)
            self.rooms = loadedRooms
            NSLog("%@", "Available rooms (\(self.rooms.count)):")
            
            var availableTreasures = Set<String>() // Set will only add items that are different, if the items are the same, it won't add it again
            for room in self.rooms.values.sorted(by: { $0.roomID < $1.roomID }) {
                NSLog("%@", "    - \(room)")
                
                for treasure in room.items ?? [] {
                    availableTreasures.insert(treasure)
                }
                
                if room.title == "Shop" { // Save the shop room in a variable so we can access it easily
                    shopRoom = room
                }
            }
            NSLog("%@", "Available treasures: \(availableTreasures)")
        } catch {
            NSLog("%@", "Error loading map file: \(error)")
        }
    }
    
    var saveFileURL: URL {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Error creating document directory!")
        }
        
        do {
            try fileManager.createDirectory(at: documentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Error creating document directory: \(error)!")
        }
        
        let fileURL = documentDirectory.appendingPathComponent("map.json", isDirectory: false)
        return fileURL
    }
    
    func playerStatus(completion: @escaping (_ player: Player?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/status/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
            
                self.player.name = serverResponse.name
                self.player.encumbrance = serverResponse.encumbrance
                self.player.strength = serverResponse.strength
                self.player.speed = serverResponse.speed
                self.player.gold = serverResponse.gold
                self.player.inventory = serverResponse.inventory
                
                NSLog("%@", "Player: \(self.player)")
                
                completion(self.player, cooldown, nil)
            }
        }.resume()
    }
    
    func status(completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/init/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("%@", "Room ID is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("%@", "Exits are missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Construct the room
                // Check if there is already a room with this ID; if yes, we're updating it; if no, we're adding it
                var room: Room! = self.rooms[roomID]
                if room == nil {
                    var exits: [Direction : Int?] = [:]
                    for direction in availableExits {
                        // Set up the dictionary, but we don't know which rooms each exit leads to yet
                        exits[direction] = nil as Int?  // putting a nil Int, otherwise it's removing the entry https://stackoverflow.com/questions/26544573/how-to-add-nil-value-to-swift-dictionary
                    }
                    
                    room = Room(roomID: roomID, exits: exits)
                    self.rooms[roomID] = room
                } else {    // If the room in the cache exists...
                    var updatedExits: [Direction : Int?] = [:]  // new exits dictionary
                    for direction in availableExits {
                        // While we're adding each available exit, check if we already know which room comes next
                        if let existingExit = room.exits[direction] {
                            // If we do, we use that room
                            updatedExits[direction] = existingExit as Int?
                        } else {
                            // Otherwise, we set it to nil
                            updatedExits[direction] = nil as Int?
                        }
                    }
                    // Update the room with the available exits
                    room.exits = updatedExits
                }
                
                // Mark the room as having been visited just now
                room.lastVisitedDate = Date()
                
                // Get values from serverResponse and save them to our properties
                room.title = serverResponse.title
                if let coordinates = serverResponse.coordinates {
                    room.coordinates = Coordinates(string: coordinates)
                }
                room.players = serverResponse.player
                room.items = serverResponse.items
                room.messages = serverResponse.messages
                
                self.currentRoom = room     // curernt room is now new room
                
                self.save()
                
                NSLog("%@", "Currently in room \(room!)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
    
    func move(direction: Direction, completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        if currentRoom == nil {
            NSLog("%@", "No current room yet. We may move in an unexpected direction!")
        }
        
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/fly/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Looking up the next room for the given direction
        let nextRoomID = currentRoom?.exits[direction] ?? nil
        
        do {
            // Make a temporary struct to represent the move request. This will have two properties; one is a String and one is an Int.
            // If both were the same type, we could've used a dictionary.
            struct MoveRequest: Codable {
                var direction: Direction
                var next_room_id: String?
            }
            
            // Make our temporary request
            let requestStruct = MoveRequest(direction: direction, next_room_id: nextRoomID == nil ? nil : String(nextRoomID!))
            // Encode the request
            request.httpBody = try JSONEncoder().encode(requestStruct)
        } catch {
            NSLog("%@", "Unable to encode direction: \(error)")
            completion(nil, nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
        
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Put this in a local property so the view controller can reference it directly
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("%@", "Room ID is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("%@", "Exits are missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Construct the room
                // Check if there is already a room with this ID; if yes, we're updating it; if no, we're adding it
                var room: Room! = self.rooms[roomID]
                // ...When we found a new room/exit...
                if room == nil {
                    var exits: [Direction : Int?] = [:]
                    for direction in availableExits {
                        // Set up the dictionary, but we don't know which rooms each exit leads to yet
                        exits[direction] = nil as Int?
                    }
                    // Create the room object with room ID and exits dictionary, but we are just remembering which exit directions there are, the room IDs for each exit is nil
                    room = Room(roomID: roomID, exits: exits)
                    self.rooms[roomID] = room
                } else {    // If the room in the cache exists...when we go through the room/exit again and want to update chagnes...
                    var updatedExits: [Direction : Int?] = [:]  // new exits dictionary
                    for direction in availableExits {
                        // While we're adding each available exit, check if we already know which room comes next
                        if let existingExit = room.exits[direction] {
                            // If we do, we use that room
                            updatedExits[direction] = existingExit as Int?
                        } else {
                            // Otherwise, we set it to nil
                            updatedExits[direction] = nil as Int?
                        }
                    }
                    // Update the room with the available exits
                    room.exits = updatedExits
                }
                
                // Mark the room as having been visited just now
                room.lastVisitedDate = Date()
                
                // Get values from serverResponse and save them to our properties
                room.title = serverResponse.title
                if let coordinates = serverResponse.coordinates {
                    room.coordinates = Coordinates(string: coordinates)
                }
                room.players = serverResponse.player
                room.items = serverResponse.items
                room.messages = serverResponse.messages
                
                if room.title == "Shop" { // Save the shop room in a variable so we can access it easily
                    self.shopRoom = room
                }
                
                let oldRoom = self.currentRoom
                self.currentRoom = room     // curernt room is now new room
                
                // If there is no errors, go ahead and save the movement into the map
                // First, assign the new room as an exit of the old room
                oldRoom?.exits[direction] = roomID
                // Then, assign the old room as the entrance to the new room
                self.currentRoom?.exits[direction.opposite] = oldRoom?.roomID as Int?
                
                self.save()
                
                NSLog("%@", "Moved \(direction) to \(room!)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
    
    func save() {
        let fileURL = self.saveFileURL
        do {
            let data = try JSONEncoder().encode(rooms)
            try data.write(to: fileURL)
        } catch {
            NSLog("%@", "Error saving map: \(error)")
        }
    }
    
    // Breadth-First Search - get shortest path to target room
    func path(from originRoomID: Int, to targetRoomID: Int) -> [Int]? {
        var queue = [[Int]]()
        var visited = Set<Int>()
        
        queue.append([originRoomID])
        
        while queue.count > 0 {
            let path = queue.removeFirst()  // the [Int] is saved in path
            let roomID = path.last!    // Get last room in the [Int] path, it is to forcibly unwrap becase we are never adding an empty array to the queue
            
            if !visited.contains(roomID) {    // visited doesn't contain node
                visited.insert(roomID)
                
                if roomID == targetRoomID {
                    return path
                }
                
                guard let room = self.rooms[roomID] else {
                    continue    // for the while loop, we don't know what this room is, so continue to the next path in the queue
                }
                
                for nextRoomID in room.exits.values {
                    guard let nextRoomID = nextRoomID else {
                        continue    // skip over any explored exits
                    }
                    
                    var newPath = path
                    newPath.append(nextRoomID)
                    queue.append(newPath)
                }
            }
        }
        return nil
    }
    
    func takeTreasure(item: String, completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        
        if currentRoom == nil {
            NSLog("%@", "No current room yet. We may move in an unexpected direction!")
        }
        
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/take/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Make a temporary struct to represent the move request. This will have two properties; one is a String and one is an Int.
            // If both were the same type, we could've used a dictionary.
            struct TakeRequest: Codable {
                var name: String
            }
            
            // Make our temporary request
            let requestStruct = TakeRequest(name: item)
            // Encode the request
            request.httpBody = try JSONEncoder().encode(requestStruct)
        } catch {
            NSLog("%@", "Unable to encode item: \(error)")
            completion(nil, nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Put this in a local property so the view controller can reference it directly
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("%@", "Room ID is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("%@", "Exits are missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Construct the room
                // Check if there is already a room with this ID; if yes, we're updating it; if no, we're adding it
                var room: Room! = self.rooms[roomID]
                if room == nil {
                    var exits: [Direction : Int?] = [:]
                    for direction in availableExits {
                        // Set up the dictionary, but we don't know which rooms each exit leads to yet
                        exits[direction] = nil as Int?
                    }
                    
                    room = Room(roomID: roomID, exits: exits)
                    self.rooms[roomID] = room
                } else {    // If the room in the cache exists...
                    var updatedExits: [Direction : Int?] = [:]  // new exits dictionary
                    for direction in availableExits {
                        // While we're adding each available exit, check if we already know which room comes next
                        if let existingExit = room.exits[direction] {
                            // If we do, we use that room
                            updatedExits[direction] = existingExit as Int?
                        } else {
                            // Otherwise, we set it to nil
                            updatedExits[direction] = nil as Int?
                        }
                    }
                    // Update the room with the available exits
                    room.exits = updatedExits
                }
                
                // Get values from serverResponse and save them to our properties
                room.items = serverResponse.items
                
                self.currentRoom = room     // curernt room is now new room
                self.player.inventory?.append(item)
                
                self.save()
                
                NSLog("%@", "Just picked up a \(item)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
    
    func dropTreasure(item: String, completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        
        if currentRoom == nil {
            NSLog("%@", "No current room yet. We may move in an unexpected direction!")
        }
        
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/drop/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Make a temporary struct to represent the move request. This will have two properties; one is a String and one is an Int.
            // If both were the same type, we could've used a dictionary.
            struct DropRequest: Codable {
                var name: String
            }
            
            // Make our temporary request
            let requestStruct = DropRequest(name: item)
            // Encode the request
            request.httpBody = try JSONEncoder().encode(requestStruct)
        } catch {
            NSLog("%@", "Unable to encode item: \(error)")
            completion(nil, nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Put this in a local property so the view controller can reference it directly
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("%@", "Room ID is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("%@", "Exits are missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Construct the room
                // Check if there is already a room with this ID; if yes, we're updating it; if no, we're adding it
                var room: Room! = self.rooms[roomID]
                if room == nil {
                    var exits: [Direction : Int?] = [:]
                    for direction in availableExits {
                        // Set up the dictionary, but we don't know which rooms each exit leads to yet
                        exits[direction] = nil as Int?
                    }
                    
                    room = Room(roomID: roomID, exits: exits)
                    self.rooms[roomID] = room
                } else {    // If the room in the cache exists...
                    var updatedExits: [Direction : Int?] = [:]  // new exits dictionary
                    for direction in availableExits {
                        // While we're adding each available exit, check if we already know which room comes next
                        if let existingExit = room.exits[direction] {
                            // If we do, we use that room
                            updatedExits[direction] = existingExit as Int?
                        } else {
                            // Otherwise, we set it to nil
                            updatedExits[direction] = nil as Int?
                        }
                    }
                    // Update the room with the available exits
                    room.exits = updatedExits
                }
                
                // Get values from serverResponse and save them to our properties
                room.items = serverResponse.items
                
                self.currentRoom = room     // current room is now new room
                
                if let index = self.player.inventory?.firstIndex(of: item) {
                    self.player.inventory?.remove(at: index)
                }
                
                self.save()
                
                NSLog("%@", "Just dropped a \(item)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
    
    func sell(item: String, completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        
        if currentRoom == nil {
            NSLog("%@", "No current room yet. We may move in an unexpected direction!")
        }
        
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/sell/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Make a temporary struct to represent the move request. This will have two properties; one is a String and one is an Int.
            // If both were the same type, we could've used a dictionary.
            struct SellRequest: Codable {
                var name: String
                var confirm = "yes"
            }
            
            // Make our temporary request
            let requestStruct = SellRequest(name: item, confirm: "yes")
            // Encode the request
            request.httpBody = try JSONEncoder().encode(requestStruct)
        } catch {
            NSLog("%@", "Unable to encode item: \(error)")
            completion(nil, nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("%@", "Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("%@", "Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("%@", "Cooldown is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Put this in a local property so the view controller can reference it directly
                self.currentErrors = serverResponse.errors
                self.currentMessages = serverResponse.messages
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("%@", "Errors: \(errors)")
                    completion(nil, cooldown, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("%@", "Room ID is missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("%@", "Exits are missing!")
                    completion(nil, nil, NSError(domain: "TreasureHuntErrorDomain", code: 0, userInfo: nil))
                    return
                }
                
                // Construct the room
                // Check if there is already a room with this ID; if yes, we're updating it; if no, we're adding it
                var room: Room! = self.rooms[roomID]
                if room == nil {
                    var exits: [Direction : Int?] = [:]
                    for direction in availableExits {
                        // Set up the dictionary, but we don't know which rooms each exit leads to yet
                        exits[direction] = nil as Int?
                    }
                    
                    room = Room(roomID: roomID, exits: exits)
                    self.rooms[roomID] = room
                } else {    // If the room in the cache exists...
                    var updatedExits: [Direction : Int?] = [:]  // new exits dictionary
                    for direction in availableExits {
                        // While we're adding each available exit, check if we already know which room comes next
                        if let existingExit = room.exits[direction] {
                            // If we do, we use that room
                            updatedExits[direction] = existingExit as Int?
                        } else {
                            // Otherwise, we set it to nil
                            updatedExits[direction] = nil as Int?
                        }
                    }
                    // Update the room with the available exits
                    room.exits = updatedExits
                }
                
                // Get values from serverResponse and save them to our properties
                room.items = serverResponse.items
                
                self.currentRoom = room     // current room is now new room
                
                if let index = self.player.inventory?.firstIndex(of: item) {
                    self.player.inventory?.remove(at: index)
                }
                
                self.save()
                
                NSLog("%@", "Just sold a \(item)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
}
