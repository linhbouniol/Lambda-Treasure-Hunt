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
        case autoDiscovery
        case goToTarget(roomID: Int)
        case treasureHunt
        case disabled    // Manual control
    }
    
    var currentAutoPilotMode: AutoPilotMode = .disabled {
        didSet {
            // Unless the old value was in manual mode (aka diabled), don't bother calling start auto traversal, since it is already auto-traversing via one of the auto-pilot modes
            // If we were in disabled mode, and we change to a auto mode, call start traversal. If we were in an auto mode, and change it to another auto-mode, autoTraversal() will pick up the new mode. If we change to disable mode, autoTraverssal() will stop when the cooldown is reached.
            
            // Setting up the x mark to show or hide
            if case let .goToTarget(roomID) = currentAutoPilotMode { // show (.isHidden = false) and position x view
                if let room = map.rooms[roomID], let coordinates = room.coordinates {
                    xImageView.frame = CGRect(x: CGFloat(coordinates.x) * 60.0 + (60.0 - 32.0)/2, y: CGFloat(120-coordinates.y) * 60.0 + (60.0 - 32.0)/2, width: 32.0, height: 32.0)
                    xImageView.isHidden = false
                }
            } else { // hide (.isHidden = true) the x view
                // No target room if we're doing any other autopilot mode
                xImageView.isHidden = true
            }
            
            guard case .disabled = oldValue else { return }
            
            switch currentAutoPilotMode {
            case .autoDiscovery, .treasureHunt, .goToTarget:
                if let cooldown = cooldownDate?.timeIntervalSinceNow {
                    self.perform(#selector(self.startAutoTraversal), with: nil, afterDelay: max(cooldown, 0.0))
                } else {
                    self.startAutoTraversal()
                }
            default:
                // Don't do anything in particular in other cases
                break
            }
        }
    }
    
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
        guard let currentRoom = map.currentRoom, let coordinates = currentRoom.coordinates else { return }
        
        // Create any missing rooms we run across, and update the view of the ones we visit. It makes the code messy by putting this code here, but since this method gets called every time we mode the player, it's a good location to create any rooms that don't exist yet.
        
        // Check if we have a room view for the specified room already... If yes, set the room property of it so it goes ahead and updates it's image, etc.
        if let roomView = roomViews[currentRoom.roomID] {
            roomView.room = currentRoom
        } else { // If no, recalculate the frame of the new view
            let frame = CGRect(x: CGFloat(coordinates.x) * 60.0, y: CGFloat(120-coordinates.y) * 60.0, width: 60.0, height: 60.0)   // 60x60 is the image
            // Create the room view
            let roomView = RoomView(frame: frame)
            // Add goToRoom() to it
            roomView.addTarget(self, action: #selector(goToRoom(_:)), for: .touchUpInside)
            // Assign the current room to the view
            roomView.room = currentRoom
            // Add room to container view
            roomViewContainer.addSubview(roomView)
            // Assign the room view to the roomViews cache so we can access it easily
            roomViews[currentRoom.roomID] = roomView
        }
        
        // Add the x and y parts because  we're positioning the player's view  relative to the room, technically, it is not in the room, just floating on top
        let playerFrame = CGRect(x: CGFloat(coordinates.x) * 60.0 + (60.0 - 32.0)/2, y: CGFloat(120-coordinates.y) * 60.0 + (60.0 - 32.0)/2, width: 32.0, height: 32.0)
        
        if cooldown <= 0 {  // no cooldown was specified
            playerImageView.frame = playerFrame
            
            scrollView.scrollRectToVisible(playerFrame.insetBy(dx: -(scrollView.frame.width - 32)/2.0, dy: -(scrollView.frame.height - 32)/2.0), animated: true)
        } else {
            UIView.animate(withDuration: cooldown, delay: 0.0, options: .curveEaseOut, animations: {
                self.playerImageView.frame = playerFrame
            }, completion: nil)
            
            scrollView.scrollRectToVisible(playerFrame.insetBy(dx: -(scrollView.frame.width - 400)/2.0, dy: -(scrollView.frame.height - 400)/2.0), animated: true)
        }
        
        itemsTextView.text = "Items in Room:\n\((currentRoom.items ?? []).map({ "• \($0.capitalized)" }).joined(separator: "\n"))"
        
        self.updatePlayerStats()
        self.updateMessage()
    }
    
    func updatePlayerStats() {
        let player = map.player
        
        statsLabel.text = "\(player.name ?? "")     🧺: \(player.encumbrance ?? 0)     💪🏼: \(player.strength ?? 0)     🏃🏻‍♀️: \(player.speed ?? 0)     💰: \(player.gold ?? 0)"
        
        inventoryTextView.text = "Inventory:\n\((player.inventory ?? []).map({ "• \($0.capitalized)" }).joined(separator: "\n"))"
    }
    
    func updateMessage() {
        guard let message = map.currentMessages, let error = map.currentErrors else { return }
        
        messagesTextView.text = "\((message + error).joined(separator: "\n"))"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Setting up room views
        roomViewContainer = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 120.0 * 60.0, height: 120.0 * 60.0))
//        roomViewContainer.backgroundColor = .orange
        scrollView.addSubview(roomViewContainer)
        scrollView.contentSize = roomViewContainer.bounds.size  // scroll is as big as the container, so the whole thing is scrollable
        
        // Start plotting rooms we already know about, that are in the map property
        for (_, room) in map.rooms {
            guard let coordinates = room.coordinates else { continue }  // if there are no coordinates, skip to the next room
            
            let frame = CGRect(x: CGFloat(coordinates.x) * 60.0, y: CGFloat(120-coordinates.y) * 60.0, width: 60.0, height: 60.0)   // 60x60 is the image
            let roomView = RoomView(frame: frame)
            roomView.addTarget(self, action: #selector(goToRoom(_:)), for: .touchUpInside)
            roomView.room = room
            
            roomViewContainer.addSubview(roomView)
            
            roomViews[room.roomID] = roomView
        }
        
        // Create x mark view
        xImageView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        xImageView.image = UIImage(named: "XMark")
        scrollView.addSubview(xImageView)
        
        // Animate player's image
        playerImageView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        playerImageView.image = UIImage(named: "PlayerAnimojiBlack")
        scrollView.addSubview(playerImageView)
        updatePlayerPosition()
        
        // If there was cooldown left over, go ahead and wait for it to finish
        if let cooldownDate = UserDefaults.standard.object(forKey: "CooldownDate") as? Date {
            updateCooldown(cooldown: cooldownDate.timeIntervalSinceNow)

            Timer.scheduledTimer(withTimeInterval: max(cooldownDate.timeIntervalSinceNow, 0.0), repeats: false) { (_) in
                // Then, load the map status, aka which room we are in
                self.map.status { (room, cooldown, error) in
                    guard let cooldown = cooldown else {
                        NSLog("%@", "The cooldown is not available!")
                        return
                    }
                    
                    self.updateCooldown(cooldown: cooldown)
                    Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                        // Wait for the cooldown, then load the player stats
                        self.map.playerStatus(completion: { (player, cooldown, error) in
                            guard let cooldown = cooldown else {
                                NSLog("%@", "The cooldown is not available!")
                                return
                            }
                            
                            self.updateCooldown(cooldown: cooldown)
                            self.updatePlayerPosition()
                            
                            // Autopilot mode test. This will start the treasure hunt process
                            self.currentAutoPilotMode = .treasureHunt
                        })
                    })
                }
            }
        }
        
        // Call breadth first search to get path to target room so we can change our name
//        NSLog("%@", "\(map.path(from: 23, to: 22))")
        
        
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
    @IBOutlet weak var messagesTextView: UITextView!
    @IBOutlet weak var inventoryTextView: UITextView!
    @IBOutlet weak var itemsTextView: UITextView!
    
    var roomViewContainer: UIView!
    var roomViews: [Int : RoomView] = [:]
    var playerImageView: UIImageView!
    var xImageView: UIImageView!
    
    @IBAction func goNorth(_ sender: Any) {
        currentAutoPilotMode = .disabled
        
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
        currentAutoPilotMode = .disabled
        
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
        currentAutoPilotMode = .disabled
        
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
        currentAutoPilotMode = .disabled
        
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
        currentAutoPilotMode = .disabled
        
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
                        }
                    })
                })
            }
            
        }
    }
    
    @IBAction func goToRoom(_ sender: RoomView) {
        guard let room = sender.room else { return }
        
        currentAutoPilotMode = .goToTarget(roomID: room.roomID)
    }
    
    @IBAction func goToSpecifiedRoom(_ sender: Any) {
        let alert = UIAlertController(title: "Enter a room number…", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Room Number"
        }
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler: { (action) in
            guard let text = alert.textFields?.first?.text else { return }
            guard let roomID = Int(text) else { return }
            self.currentAutoPilotMode = .goToTarget(roomID: roomID)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func discoverAllRooms(_ sender: Any) {
        
        currentAutoPilotMode = .autoDiscovery
    }
    
    @IBAction func findTreasure(_ sender: Any) {
        
        currentAutoPilotMode = .treasureHunt
    }
    
    @IBAction func take(_ sender: Any) {
        currentAutoPilotMode = .disabled
        
        if userShouldWait() { return }
        
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
        currentAutoPilotMode = .disabled
        
        if userShouldWait() { return }
        
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
    
    func userShouldWait() -> Bool {
        if cooldownTimer == nil {
            return false // don't wait, we are good to go immediately
        }
        
        // show alert
        NSLog("%@", "Too fast! Please wait!")
        
        return true
    }
    
    @IBAction func sell(_ sender: Any) {
        currentAutoPilotMode = .disabled
        
        if userShouldWait() { return }
        
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
    var failedToCollectTreasure = false
    var baselineCooldown: TimeInterval?
    
    @objc func startAutoTraversal() {
        traversalPath = []
        traversalGraph = [:]
        backtrackingStack = []
        
        // Note that for path traversal, we are mostly ignoring the graph that the map object has, since that is mostly used for determining the "wise" path and other functions. This algorithm is specifically for finding the path that links all rooms, so having a graph without known exits will be useful to determine which rooms have not yet been explored.
        
        // Reset any treasure hunting state
        failedToCollectTreasure = false
        baselineCooldown = nil
        
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
        if case .disabled = currentAutoPilotMode { return }
        
        if case let .goToTarget(roomID) = currentAutoPilotMode {
            guard var currentRoom = map.currentRoom else { return }
            
            // Check if there are at least two rooms in the path, because there is only one room, that means we're already there, we're interested in the next room
            guard var path = map.path(from: currentRoom.roomID, to: roomID), path.count > 1 else {
                // If the path doesn't have more than 1 room, that means the current room and the next room are the same, and we're at the destination, so we need to set the mode to be disable, which was call the didSet and remove the x mark.
                currentAutoPilotMode = .disabled
                return
            }
            
            var directionToTake: Direction! // the primary direction we will go in
            var singleDirectionPath: [Int] = [] // the rooms that we will go through
            
            roomLoop: for nextRoomID in path[1...] { // loop through all the items in the path, starting with the next room
                directionLoop: for (direction, exitRoomID) in currentRoom.exits { // check to see direction the next room is in
                    if nextRoomID == exitRoomID {
                        if directionToTake == nil || directionToTake == direction { // if this is the first room we are checking (directionToTake is nil) or if the directions match, add the next room to the list of rooms in a single line
                            directionToTake = direction
                            singleDirectionPath.append(nextRoomID)
                        } else { // the direction is changing, so stop here and don't check any more rooms
                            break roomLoop
                        }
                        break directionLoop // We found the direction we were interested in, stop checking directions
                    }
                }
                currentRoom = map.rooms[nextRoomID]! // Set the current room to whichever one we just checked so we can check the following room
            }
            
            if singleDirectionPath.count > 1 { // we can dash, since there is more than one room in the direction
                map.dash(direction: directionToTake, path: singleDirectionPath) { (newRoom, cooldown, error) in
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
                    
                    NSLog("%@", "Walked \(directionToTake!) towards \(roomID) to room \(newRoom!.roomID)")
                    
                    // If successfull, log the backtrack and continue looping until after the cooldown
                    self.traversalPath.append(directionToTake)
                    
                    self.updateCooldown(cooldown: cooldown)
                    self.updatePlayerPosition(cooldown: cooldown)
                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                }
            } else { // better to walk/fly instead
                map.move(direction: directionToTake) { (newRoom, cooldown, error) in
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
                    
                    NSLog("%@", "Walked \(directionToTake!) towards \(roomID) to room \(newRoom!.roomID)")
                    
                    // If successfull, log the backtrack and continue looping until after the cooldown
                    self.traversalPath.append(directionToTake)
                    
                    self.updateCooldown(cooldown: cooldown)
                    self.updatePlayerPosition(cooldown: cooldown)
                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                }
            }
            
            
            
            return
        }
        
        // Check if we're treasure hunting
        if case .treasureHunt = currentAutoPilotMode, let shopRoom = map.shopRoom {
            guard let currentRoom = map.currentRoom, let encumbrance = map.player.encumbrance, let strength = map.player.strength else { return }
            
            if encumbrance < (strength*2 - 1) && !failedToCollectTreasure, let items = currentRoom.items, !items.isEmpty { // we want to collect any treasures we found so far, as long as we didn't fail to collect any yet
                
                map.takeTreasure(item: items[0]) { (room, cooldown, error) in
                    if let error = error {
                        NSLog("%@", "Error taking item! \(error)")
                        
                        // Make sure we don't collect treasure anymore
                        self.failedToCollectTreasure = true
                        
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
            
            if currentRoom.roomID == shopRoom.roomID, let inventory = map.player.inventory { // in the shop, so sell as much "treasure" as we can
                
                // Check if we have at least one treasure to sell
                if let itemToSell = inventory.first(where: { $0.contains("treasure") }) {
                    map.sell(item: itemToSell) { (_, cooldown, error) in
                        let cooldown = cooldown ?? 30
                        
                        if let _ = error {
                            // If there was an error selling (maybe the item we were trying to sell didn't exist!), then reload the inventory
                            Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                                self.map.playerStatus(completion: { (_, cooldown, error) in
                                    let cooldown = cooldown ?? 30
                                    
                                    self.updateCooldown(cooldown: cooldown)
                                    self.updatePlayerPosition(cooldown: cooldown)
                                    self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                                })
                            })
                        }
                        
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                        self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                        
                        // We don't want to update the status here because it would be wasted doing it for every sale. Instead, we only do it once at the very end
                    }
                    
                    return
                } else if encumbrance >= strength {
                    // If we didn't have any more treasure, check if our encumbrance wasn't updated yet. If it hasn't been, go ahead and reset the player stats back to what the server says they are, and restart the whole process. Since the encumbrance is only updated when the stats are loaded, which only happens twice (once when the cooldown suddenly doubles, and once right here after we detect everything has been sold), we know that it is still unchanged at this point.
                    // We know that the encumbrance at this step is still the status of before we sold anything, and we also know selling will lower the encumbrance, so after selling everything, we load the stats, which should reset the state for us.
                    map.playerStatus(completion: { (_, cooldown, error) in
                        let cooldown = cooldown ?? 30
                        
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                        self.perform(#selector(self.startAutoTraversal), with: nil, afterDelay: cooldown)
                    })
                }
            }
            
            if encumbrance >= strength { // we want to return to the shop
                
                guard var path = map.path(from: currentRoom.roomID, to: shopRoom.roomID), path.count > 1 else { return }
                
                var directionToTake: Direction! // the primary direction we will go in
                var singleDirectionPath: [Int] = [] // the rooms that we will go through
                
                var currentRoom = currentRoom
                
                roomLoop: for nextRoomID in path[1...] { // loop through all the items in the path, starting with the next room
                    directionLoop: for (direction, exitRoomID) in currentRoom.exits { // check to see direction the next room is in
                        if nextRoomID == exitRoomID {
                            if directionToTake == nil || directionToTake == direction { // if this is the first room we are checking (directionToTake is nil) or if the directions match, add the next room to the list of rooms in a single line
                                directionToTake = direction
                                singleDirectionPath.append(nextRoomID)
                            } else { // the direction is changing, so stop here and don't check any more rooms
                                break roomLoop
                            }
                            break directionLoop // We found the direction we were interested in, stop checking directions
                        }
                    }
                    currentRoom = map.rooms[nextRoomID]! // Set the current room to whichever one we just checked so we can check the following room
                }
                
                if singleDirectionPath.count > 1 { // we can dash, since there is more than one room in the direction
                    map.dash(direction: directionToTake, path: singleDirectionPath) { (newRoom, cooldown, error) in
                        if let error = error {
                            NSLog("%@", "Error backtracking!")
                            
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
                        
                        NSLog("%@", "Walked \(directionToTake!) towards shop to room \(newRoom!.roomID)")
                        
                        // If successfull, log the backtrack and continue looping until after the cooldown
                        self.traversalPath.append(directionToTake)
                        
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                        self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                    }
                } else {
                    map.move(direction: directionToTake) { (newRoom, cooldown, error) in
                        if let error = error {
                            NSLog("%@", "Error backtracking!")
                            
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
                        
                        NSLog("%@", "Walked \(directionToTake!) towards shop to room \(newRoom!.roomID)")
                        
                        // If successfull, log the backtrack and continue looping until after the cooldown
                        self.traversalPath.append(directionToTake)
                        
                        self.updateCooldown(cooldown: cooldown)
                        self.updatePlayerPosition(cooldown: cooldown)
                        self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                    }
                }
                
                return
            }

            // call take method, wait for cooldown
            // call autoTraversal, if there is still treasure it will take it again, if none, it will move on to next room
        }
       
        guard traversalGraph.count < 500 && !finishedBuildingTraversalPath else {
            // We traversed the whole graph at this point, so we are done!
            
            // Print the traversal path
            let pythonFriendlyTraversalPath = "[\(traversalPath.map { "'\($0.rawValue)'" }.joined(separator: ", "))]"
            NSLog("%@", "The traversal path is:\n\(pythonFriendlyTraversalPath)")
            
            if case .treasureHunt = currentAutoPilotMode { // If we somehow discovered every room, but didn't sell in  between, just go ands try again
                startAutoTraversal()
                return
            }
            
            // We discovered all rooms, and we are not treasure hunting, so stop!
            currentAutoPilotMode = .disabled
            
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
                
                if case .treasureHunt = self.currentAutoPilotMode {
                    if self.baselineCooldown == nil { // we haven't recorded the normal cooldown yet,. so save it
                        self.baselineCooldown = cooldown
                    } else if cooldown > self.baselineCooldown! + 0.01 { // if the cooldown is suddenly larger, reload the player stats so we can go ahead and change routes back to the shop (shop-searching code happens when the encumbrance is larger than half the strength, hense loading the stats)
                        
                        Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                            self.map.playerStatus(completion: { (_, cooldown, error) in
                                if let error = error {
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
                                self.updatePlayerPosition()
                                
                                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                            })
                        })
                        
                        return
                    }
                }
                
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
                    NSLog("Error backtracking! \(error)")
                    
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
                
                if case .treasureHunt = self.currentAutoPilotMode {
                    if self.baselineCooldown == nil { // we haven't recorded the normal cooldown yet,. so save it
                        self.baselineCooldown = cooldown
                    } else if cooldown > self.baselineCooldown! + 0.01 { // if the cooldown is suddenly larger, reload the player stats so we can go ahead and change routes back to the shop (shop-searching code happens when the encumbrance is larger than half the strength, hense loading the stats)
                        
                        Timer.scheduledTimer(withTimeInterval: cooldown, repeats: false, block: { (_) in
                            self.map.playerStatus(completion: { (_, cooldown, error) in
                                if let error = error {
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
                                self.updatePlayerPosition()
                                
                                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
                            })
                        })
                        
                        return
                    }
                }
                
                self.perform(#selector(self.autoTraversal), with: nil, afterDelay: cooldown)
            }
        }
    }
}

