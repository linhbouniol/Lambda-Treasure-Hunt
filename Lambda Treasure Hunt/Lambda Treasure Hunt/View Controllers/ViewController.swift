//
//  ViewController.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/4/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var map = Map()
    var cooldownDate: Date?
    var cooldownTimer: Timer?
    
    // Given a cooldown time interval, we want to calculate the date in the future and have a timer show how many seconds are left before we could move again
    // cooldown = number of seconds
    // cooldownDate = the date in the future when the cooldown is done
    // cooldownTimer = the timer that repeated when the cooldown is active
    func updateCooldown(cooldown: TimeInterval) {
        cooldownDate = Date(timeIntervalSinceNow: cooldown)
        
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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBOutlet weak var cooldownLabel: UILabel!
    
    @IBAction func goNorth(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("Too fast! Please wait!")
            return
        }
        
        map.move(direction: .north) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goSouth(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("Too fast! Please wait!")
            return
        }
        
        map.move(direction: .south) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goEast(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("Too fast! Please wait!")
            return
        }
        
        map.move(direction: .east) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func goWest(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("Too fast! Please wait!")
            return
        }
        
        map.move(direction: .west) { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
            }
        }
    }
    
    @IBAction func getInfo(_ sender: Any) {
        if cooldownTimer != nil {
            NSLog("Too fast! Please wait!")
            return
        }
        
        map.status { (room, cooldown, error) in
            if let cooldown = cooldown {
                self.updateCooldown(cooldown: cooldown)
            }
        }
    }
}

