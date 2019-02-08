//
//  RoomView.swift
//  Lambda Treasure Hunt
//
//  Created by Linh Bouniol on 2/5/19.
//  Copyright © 2019 Linh Bouniol. All rights reserved.
//

import UIKit

class RoomView: UIControl {
    
    var room: Room? {
        didSet {
            guard let room = room else { return }
            roomIDLabel.text = "\(room.roomID)"
            titleLabel.text = room.title
            
            // Build up image name
            var imageName = "Exits"
            
            if room.exits[.north] != nil {
                imageName.append("N")
            } else {
                imageName.append("_")
            }
            
            if room.exits[.south] != nil {
                imageName.append("S")
            } else {
                imageName.append("_")
            }
            
            if room.exits[.east] != nil {
                imageName.append("E")
            } else {
                imageName.append("_")
            }
            
            if room.exits[.west] != nil {
                imageName.append("W")
            } else {
                imageName.append("_")
            }
            
            backgroundImageView.image = UIImage(named: imageName)
            
            switch room.title {
            case "Shop":
                self.tintColor = UIColor(hue: 0.33, saturation: 1.0, brightness: 0.8, alpha: 1.0)
            case "A brightly lit room":
                self.tintColor = UIColor(hue: 0.85, saturation: 1.0, brightness: 0.9, alpha: 1.0)
            case "Name Changer":
                self.tintColor = UIColor(hue: 0.0, saturation: 1.0, brightness: 0.9, alpha: 1.0)
            case "A misty room":
                self.tintColor = UIColor(hue: CGFloat.random(in: 0.0...1.0), saturation: 0.6, brightness: 0.35, alpha: 1.0)
            case "Mt. Holloway":
                self.tintColor = UIColor(hue: 0.1, saturation: 1.0, brightness: 0.9, alpha: 1.0)
            case "A Dark Cave":
                self.tintColor = UIColor(hue: 0.1, saturation: 1.0, brightness: 0.3, alpha: 1.0)
            case "The Peak of Mt. Holloway", "An Ancient Shrine":
                self.tintColor = UIColor(hue: 0.55, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            default:
                self.tintColor = UIColor(hue: CGFloat.random(in: 0.0...1.0), saturation: 0.6, brightness: 0.9, alpha: 1.0)
            }
            
            updateRoomVibrancy()
        }
    }
    
    var backgroundImageView: UIImageView
    var roomIDLabel: UILabel
    var titleLabel: UILabel
    var roomVisitTimer: Timer?

    override init(frame: CGRect) {
        backgroundImageView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height))
        roomIDLabel = UILabel(frame: CGRect(x: 10.0, y: 10.0, width: frame.width - 9.0 * 2, height: 10.0))
        titleLabel = UILabel(frame: CGRect(x: 9.0, y: frame.height - 9.0 - 20.0, width: frame.width - 9.0 * 2, height: 20.0))
        
        super.init(frame: frame)
        
        roomIDLabel.text = "??"
        roomIDLabel.font = UIFont.systemFont(ofSize: 8.0, weight: .semibold)
        
        titleLabel.font = UIFont.systemFont(ofSize: 8.0, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        
        addSubview(backgroundImageView)
        addSubview(roomIDLabel)
        addSubview(titleLabel)
        
        roomVisitTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] (timer) in
            guard let self = self else { return }
            
            self.updateRoomVibrancy()
        })
        
        roomVisitTimer?.tolerance = 10
    }
    
    deinit {
        roomVisitTimer?.invalidate()
    }
    
    func updateRoomVibrancy() {
        let timeSinceVisited = -(room?.lastVisitedDate?.timeIntervalSinceNow ?? -100000)/300.0
        
        if room?.title == "A misty room" {
            self.alpha = CGFloat(1.0/(timeSinceVisited+1.0/(9.0*0.1))+0.1)
        } else {
            self.alpha = CGFloat(1.0/(timeSinceVisited+1.0/(0.5))+0.5)
        }
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        
        roomIDLabel.textColor = tintColor
        titleLabel.textColor = tintColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
