//
//  ViewController.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    enum AutoPilotMode {
        case AutoDiscovery
        case GoToTarget(roomID: Int)
        case TreasureHunt
        case Disable    // Manual control
    }
    
    var currentAutoPilotMode: AutoPilotMode = .Disable
    
    var map = Map()
    var cooldownDate: Date?
    var cooldownTimer: Timer?
    
    // Given a cooldown time interval, we want to calculate the date in the future and have a timer show how many seconds are left before we could move again
    // cooldown = number of seconds
    // cooldownDate = the date in the future when the cooldown is done
    // cooldownTimer = the timer that repeated when the cooldown is active
    func updateCooldown(cooldown: TimeInterval) {
        cooldownDate = Date(timeIntervalSinceNow: cooldown)
        
        UserDefaults.standard.set(cooldownDate, forKey: "CooldownDate")
        
        cooldownTimer?.invalidate()
        
        // If there is no cooldown, remove the timer
        if cooldown <= 0 {
            cooldownTimer = nil
            self.cooldownLabel.text = "Cooldown: 00s"
            return
        }
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] (timer) in
            guard let self = self else { return }
            
            var remainingCooldown = self.cooldownDate?.timeIntervalSinceNow ?? 0
            if remainingCooldown <= 0 { // the now time caught up to the future cooldown date
                remainingCooldown = 0   // resetting the timer to be at least 0, because we don't want to show -time
                self.cooldownTimer?.invalidate()    // turning off the timer
                self.cooldownTimer = nil    // throwing away the timer
            }
            
            // ceil rounds up the time to the nearest second
            self.cooldownLabel.text = "Cooldown: \(Int(ceil(remainingCooldown)))s"
        })
    }
    
    func updatePlayerPosition(cooldown: TimeInterval = 0.0) {
        guard let coordinates = map.currentRoom?.coordinates else { return }
        
        // Add the x and y parts because  we're positioning the player's view  relative to the room, technically, it is not in the room, just floating on top
        let playerFrame = CGRect(x: CGFloat(coordinates.x) * 60.0 + (60.0 - 32.0)/2, y: CGFloat(120-coordinates.y) * 60.0 + (60.0 - 32.0)/2, width: 32.0, height: 32.0)
        
        if cooldown <= 0 {  // no cooldown was specified
            playerImageView.frame = playerFrame
            
            scrollView.scrollRectToVisible(playerFrame.insetBy(dx: -(scrollView.frame.width - 32)/2.0, dy: -(scrollView.frame.height - 32)/2.0), animated: true)
        } else {
            UIView.animate(withDuration: cooldown * 0.9, delay: 0.0, options: .curveEaseOut, animations: {
                self.playerImageView.frame = playerFrame
            }, completion: nil)
            
            scrollView.scrollRectToVisible(playerFrame.insetBy(dx: -(scrollView.frame.width - 400)/2.0, dy: -(scrollView.frame.height - 400)/2.0), animated: true)
        }
    }
    
    func updatePlayerStats() {
        let player = map.player
        
        statsLabel.text = "\(player.name ?? "")     🧺: \(player.encumbrance ?? 0)     💪🏻: \(player.strength ?? 0)     🏃🏻‍♀️: \(player.speed ?? 0)     💰: \(player.gold ?? 0)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Autopilot mode test
        currentAutoPilotMode = .TreasureHunt
        
        // Setting up room views
        roomViewContainer = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 120.0 * 60.0, height: 120.0 * 60.0))
//        roomViewContainer.backgroundColor = .orange
        scrollView.addSubview(roomViewContainer)
        scrollView.contentSize = roomViewContainer.bounds.size  // scroll is as big as the container, so the whole thing is scrollable
        
        // Start plotting rooms
        for (_, room) in map.rooms {
            guard let coordinates = room.coordinates else { continue }  // if there are no coordinates, skip to the next room
            
            let frame = CGRect(x: CGFloat(coordinates.x) * 60.0, y: CGFloat(120-coordinates.y) * 60.0, width: 60.0, height: 60.0)   // 60x60 is the image
            let roomView = RoomView(frame: frame)
            roomView.room = room
            
            switch room.title {
            case "Shop":
                roomView.tintColor = UIColor(hue: 0.33, saturation: 1.0, brightness: 0.8, alpha: 1.0)
            case "A brightly lit room":
                roomView.tintColor = UIColor(hue: 0.85, saturation: 1.0, brightness: 0.9, alpha: 1.0)
            case "Name Changer":
                roomView.tintColor = UIColor(hue: 0.0, saturation: 1.0, brightness: 0.9, alpha: 1.0)
            case "A misty room":
                roomView.tintColor = UIColor(hue: CGFloat.random(in: 0.0...1.0), saturation: 0.6, brightness: 0.1, alpha: 0.5)
            default:
                roomView.tintColor = UIColor(hue: CGFloat.random(in: 0.0...1.0), saturation: 0.6, brightness: 0.9, alpha: 1.0)
            }
            
            roomViewContainer.addSubview(roomView)
            
            roomViews[room.roomID] = roomView
        }
        
        // Animate player's image
        playerImageView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        playerImageView.image = UIImage(named: "PlayerAnimoji")
        scrollView.addSubview(playerImageView)
        updatePlayerPosition()
        
        if let cooldownDate = UserDefaults.standard.object(forKey: "CooldownDate") as? Date {
            updateCooldown(cooldown: cooldownDate.timeIntervalSinceNow)

            Timer.scheduledTimer(withTimeInterval: max(cooldownDate.timeIntervalSinceNow, 0.0), repeats: false) { (_) in
                self.map.status { (room, cooldown, error) in
                    guard let cooldown = cooldown else {
                        NSLog("%@", "The cooldown is not available!")
                        return
                    }
                    
                    self.updateCooldown(cooldown: cooldown)
                    Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                        self.map.playerStatus(completion: { (player, cooldown, error) in
                            guard let cooldown = cooldown else {
                                NSLog("%@", "The cooldown is not available!")
                                return
                            }
                            
                            self.updateCooldown(cooldown: cooldown)
                            self.updatePlayerPosition()
                            self.updatePlayerStats()
                            // Uncomment to find path to discover all rooms
                            self.perform(#selector(self.startAutoTraversal), with: nil, afterDelay: cooldown)
                        })
                    })
                }
            }
        }
        
        // Call breadth first search to get path to target room so we can change our name
//        NSLog("%@", "\(map.path(from: 386, to: 0))")
        
        
        // map, call move, it will save the moves in a file
        // slowly build up a graph of all rooms every time move() is called
        // autoTraversal - find the path to discover all rooms
        // as we traverse, the move() in there map will remember the moves
        // even after the traversal it only print the path, but since we had to traverse each each, it adds the room to map, consesquencely the map gets the entire graph
        // traversal isnt using the map at all, but since its moving its contributing to the map
        
        
    }
    
    @IBOutlet weak var cooldownLabel: UILabel!
    @IBOutlet weak var statsLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var roomViewContainer: UIView!
    var roomViews: [Int : UIView] = [:]
    var playerImageView: UIImageView!
    
    @IBAction func goNorth(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        map.move(direction: .north) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goSouth(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        map.move(direction: .south) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goEast(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        map.move(direction: .east) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goWest(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        map.move(direction: .west) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func getInfo(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        map.status { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition()
                
                Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                    self.map.playerStatus(completion: { (player, cooldown, error) in
                        if let cooldown = cooldown {
                            self.updateCooldown(cooldown: cooldown)
                            self.updatePlayerPosition(cooldown: cooldown)
                            
                            self.updatePlayerStats()
                        }
                    })
                })
            }
            
        }
    }
    
    @IBAction func take(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        guard let room = map.currentRoom, let items = room.items, !items.isEmpty else {
            let alert = UIAlertController(title: "No items in this room.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let actionSheet = UIAlertController(title: "Choose Treasure to Take…", message: nil, preferredStyle: .actionSheet)
        
        for item in items {
            actionSheet.addAction(UIAlertAction(title: item.capitalized, style: .default, handler: { (action) in
                self.map.takeTreasure(item: item, completion: { (room, cooldown, error) in
                    if let cooldown = cooldown {
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                    }
                })
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        guard let roomView = self.roomViews[room.roomID] else { return }
        
        actionSheet.popoverPresentationController?.sourceView = roomView
        actionSheet.popoverPresentationController?.sourceRect = roomView.bounds
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func drop(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("%@", "Too fast! Please wait!")
            return
        }
        
        guard let inventory = map.player.inventory, !inventory.isEmpty else {
            let alert = UIAlertController(title: "No items in inventory.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let actionSheet = UIAlertController(title: "Choose Treasure to Drop…", message: nil, preferredStyle: .actionSheet)
        
        for item in inventory {
            actionSheet.addAction(UIAlertAction(title: item.capitalized, style: .default, handler: { (action) in
                self.map.dropTreasure(item: item, completion: { (room, cooldown, error) in
                    if let cooldown = cooldown {
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                    }
                })
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        guard let room = map.currentRoom, let roomView = self.roomViews[room.roomID] else { return }
        
        actionSheet.popoverPresentationController?.sourceView = roomView
        actionSheet.popoverPresentationController?.sourceRect = roomView.bounds
        self.present(actionSheet, animated: true, completion: nil)
        
    }
    
    func showUserWait() -> Bool {
        if cooldownTimer == nil {
            return false // don't wait, we are good to go immediately
        }
        
        // show alert
        NSLog("%@", "Too fast! Please wait!")
        
        return true
    }
    
    @IBAction func sell(_ sender: Any) {
        if showUserWait() { return }
        
        guard let inventory = map.player.inventory, !inventory.isEmpty else {
            let alert = UIAlertController(title: "No items in inventory.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let actionSheet = UIAlertController(title: "Choose Treasure to Sell…", message: nil, preferredStyle: .actionSheet)
        
        for item in inventory {
            actionSheet.addAction(UIAlertAction(title: item.capitalized, style: .default, handler: { (action) in
                self.map.sell(item: item, completion: { (room, cooldown, error) in
                    if let cooldown = cooldown {
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                    }
                })
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        guard let room = map.currentRoom, let roomView = self.roomViews[room.roomID] else { return }
        
        actionSheet.popoverPresentationController?.sourceView = roomView
        actionSheet.popoverPresentationController?.sourceRect = roomView.bounds
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    // MARK: - Discover Shortest Path
    
    var traversalPath: [Direction] = []
    var traversalGraph: [Int : Room] = [:]
    var backtrackingStack: [Direction] = []
    var finishedBuildingTraversalPath: Bool = false
    
    @objc func startAutoTraversal() {
        traversalPath = []
        traversalGraph = [:]
        backtrackingStack = []
        
        // Note that for path traversal, we are mostly ignoring the graph that the map object has, since that is mostly used for determining the "wise" path and other functions. This algorithm is specifically for finding the path that links all rooms, so having a graph without known exits will be useful to determine which rooms have not yet been explored.
        
        // Build up the first room
        guard let startingRoom = map.currentRoom else {
            NSLog("%@", "Error getting starting room!")
            return
        }
        
        // Build up the first room
        let startingRoomID = startingRoom.roomID
        
        NSLog("%@", "Starting from room \(startingRoomID)")
        
        // Create an empty exits dictionary for the staring room to get us started
        var exits: [Direction : Int?] = [:]
        for direction in startingRoom.exits.keys {
            exits[direction] = nil as Int?
        }
        
        // Add the starting room to our graph
        traversalGraph[startingRoomID] = Room(roomID: startingRoomID, exits: exits)
        
        
//        let testPath = [.north, .south, .north, .east, .west, .south]
//        let transformation = "[\(testPath.map { "'\($0.rawValue)'" }.joined(separator: ", "))]"
//        print(transformation)
        
        autoTraversal()
    }
    
    @objc func autoTraversal() {    // Use for auto discovery and treasure hunt
        
        // Check if we're treasure hunting
//        if case currentAutoPilotMode = AutoPilotMode.TreasureHunt {
//            // if there is treasure in current room, take it and return
//            if map.currentRoom?.items > 0 {
//                // takeTreasure()
//            }
//
//            // call take method, wait for cooldown
//            // call autoTraversal, if there is still treasure it will take it again, if none, it will move on to next room
//        }
        
        
        
        if let currentRoom = map.currentRoom, let items = currentRoom.items, !items.isEmpty, let inventory = map.player.inventory, inventory.count < 10 {
            
            map.takeTreasure(item: items[0]) { (room, cooldown, error) in
                if let error = error {
                    NSLog("%@", "Error taking item! \(error)")
                    
                    let cooldown = cooldown ?? 30
                    
                    self.updateCooldown(cooldown: cooldown)
                    self.updatePlayerPosition(cooldown: cooldown)
                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown) // use self.perform when calling a recursive function so it doesn't fill the stack and cause an overflow
                    
                    return
                }
                
                guard let cooldown = cooldown else {
                    NSLog("%@", "The cooldown is missing! Something is wrong...")
                    return
                }
                
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
            }
            
            return
        }
        
        
        
        guard traversalGraph.count < 500 && !finishedBuildingTraversalPath else {
            // We traversed the whole graph at this point, so we are done!
            
            // Print the traversal path
            let pythonFriendlyTraversalPath = "[\(traversalPath.map { "'\($0.rawValue)'" }.joined(separator: ", "))]"
            NSLog("%@", "The traversal path is:\n\(pythonFriendlyTraversalPath)")
            
            return
        }
        
        guard let currentRoomID = map.currentRoom?.roomID else {
            NSLog("%@", "Current room is missing from the map. This shouldn't happen!")
            return
        }
        
        guard let currentRoom = traversalGraph[currentRoomID] else {
            NSLog("%@", "The current room was missing from our graph! This shouldn't happen!")
            return
        }
        
        var areExitsAvailableToExplore = false
        
        for (direction, exitRoomID) in currentRoom.exits.shuffled() {
            guard exitRoomID == nil else { // We are only interested in rooms that have not yet been explored
                continue
            }
            
            // This direction has not been explored yet, so let's check it out
            
            map.move(direction: direction) { (newRoomFromMap, cooldown, error) in
                if let error = error {
//                    NSLog("%@", "Error moving to new room! \(error)")
                    
                    let cooldown = cooldown ?? 30
                    
                    self.updateCooldown(cooldown: cooldown)
                    self.updatePlayerPosition(cooldown: cooldown)
                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown) // use self.perform when calling a recursive function so it doesn't fill the stack and cause an overflow
                    
                    return
                }
                
                guard let cooldown = cooldown else {
                    NSLog("%@", "The cooldown is missing! Something is wrong...")
                    return
                }
                
                guard let nextRoomFromMap = newRoomFromMap else {
                    NSLog("%@", "New room should not be missing!!")
                    return
                }
                
                let nextRoomID = nextRoomFromMap.roomID
                
                NSLog("%@", "Moved \(direction) to room \(nextRoomID)")
                currentRoom.exits[direction] = nextRoomID
                
                let returningDirection = direction.opposite
                
                // Create the next room if we need to, or just access it if it's already in our graph
                var nextRoom: Room! = self.traversalGraph[nextRoomID]
                if nextRoom == nil {
                    // Build up an empty next room
                    var exits: [Direction : Int?] = [:]
                    for direction in nextRoomFromMap.exits.keys {
                        exits[direction] = nil as Int?
                    }
                    
                    // Assign the new room so we can access it outside of this if statement
                    nextRoom = Room(roomID: nextRoomID, exits: exits)
                    
                    // Add the next room to our graph
                    self.traversalGraph[nextRoomID] = nextRoom
                }
                
                // set the entrance accordingly
                nextRoom.exits[returningDirection] = currentRoomID as Int?
                
                // Since we were successfull, go ahead and add the direction to the path, and the returning direction to the backtracking path
                self.traversalPath.append(direction)
                self.backtrackingStack.append(returningDirection)
                
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
            }
            
            areExitsAvailableToExplore = true
            break
        }
        
        if !areExitsAvailableToExplore {
            guard let backtrackDirection = backtrackingStack.popLast() else {
                // There wasn't anything to backtrack, so we ended up at the beginning without exploring everything?
                
                finishedBuildingTraversalPath = true
                autoTraversal()
                return
            }
            
            map.move(direction: backtrackDirection) { (newRoom, cooldown, error) in
                if let error = error {
                    NSLog("%@", "Error backtracking! \(error)")
                    
                    let cooldown = cooldown ?? 30
                    
                    self.updateCooldown(cooldown: cooldown)
                    self.updatePlayerPosition(cooldown: cooldown)
                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown) // use self.perform when calling a recursive function so it doesn't fill the stack and cause an overflow
                    
                    return
                }
                
                guard let cooldown = cooldown else {
                    NSLog("%@", "The cooldown is missing! Something is wrong...")
                    return
                }
                
                NSLog("%@", "Backtracked \(backtrackDirection) to room \(newRoom!.roomID)")
                
                // If successfull, log the backtrack and continue looping until after the cooldown
                self.traversalPath.append(backtrackDirection)
                
                self.updateCooldown(cooldown: cooldown)
                self.updatePlayerPosition(cooldown: cooldown)
                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
            }
        }
    }
}

