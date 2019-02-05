//
//  Map.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import Foundation

class Map {
    var rooms: [Int : Room] = [:]
    var currentRoom: Room?
    
    init() {
        // Loading the map file
        let fileURL = self.saveFileURL
        NSLog("Loading file from \(fileURL)")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedRooms = try JSONDecoder().decode([Int : Room].self, from: data)
            self.rooms = loadedRooms
            NSLog("Available rooms (\(self.rooms.count)):")
            for room in self.rooms.values.sorted(by: { $0.roomID < $1.roomID }) {
                NSLog("    - \(room)")
            }
        } catch {
            NSLog("Error loading map file: \(error)")
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
    
    func status(completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/init/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token b1a0e8086d92bc85dda1a47d390b2e1bf32f74d4", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
                
                if let error = error {
                    NSLog("Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError())
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("Cooldown is missing!")
                    completion(nil, nil, NSError())
                    return
                }
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("Errors: \(errors)")
                    completion(nil, cooldown, NSError())
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("Room ID is missing!")
                    completion(nil, nil, NSError())
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("Exits are missing!")
                    completion(nil, nil, NSError())
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
                }
                
                self.currentRoom = room     // curernt room is now new room
                
                self.save()
                
                NSLog("Currently in room \(room!)") // room will internally call description() to log the room info
                
                completion(room, cooldown, nil)
            }
        }.resume()
    }
    
    func move(direction: Direction, completion: @escaping (_ room: Room?, _ coolDown: TimeInterval?, _ error: Error?) -> Void) {
        if currentRoom == nil {
            NSLog("No current room yet. We may move in an unexpected direction!")
        }
        
        let url = URL(string: "https://lambda-treasure-hunt.herokuapp.com/api/adv/move/")!
        
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
            NSLog("Unable to encode direction: \(error)")
            completion(nil, nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            DispatchQueue.main.async {
        
                if let error = error {
                    NSLog("Error saving todo on server: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, NSError())
                    return
                }
                
                let serverResponse: ServerResponse
                
                do {
                    serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                } catch {
                    NSLog("Error decoding received data: \(error)")
                    completion(nil, nil, error)
                    return
                }
                
                // Check for the three things we're interested in: room, cooldown, error
                // Doing this here because those things will changed and every time they're different so it's easier to deal with them here as we decode
                
                guard let cooldown = serverResponse.cooldown else {
                    NSLog("Cooldown is missing!")
                    completion(nil, nil, NSError())
                    return
                }
                
                if let errors = serverResponse.errors, !errors.isEmpty {
                    NSLog("Errors: \(errors)")
                    completion(nil, cooldown, NSError())
                    return
                }
                
                guard let roomID = serverResponse.room_id else {
                    NSLog("Room ID is missing!")
                    completion(nil, nil, NSError())
                    return
                }
                
                guard let availableExits = serverResponse.exits else {
                    NSLog("Exits are missing!")
                    completion(nil, nil, NSError())
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
                }
                
                let oldRoom = self.currentRoom
                self.currentRoom = room     // curernt room is now new room
                
                // If there is no errors, go ahead and save the movement into the map
                // First, assign the new room as an exit of the old room
                oldRoom?.exits[direction] = roomID
                // Then, assign the old room as the entrance to the new room
                self.currentRoom?.exits[direction.opposite] = oldRoom?.roomID as Int?
                
                self.save()
                
                NSLog("Moved \(direction) to \(room!)") // room will internally call description() to log the room info
                
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
            NSLog("Error saving map: \(error)")
        }
    }
}
