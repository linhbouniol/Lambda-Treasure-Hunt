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
        }
    }
    
    var backgroundImageView: UIImageView
    var roomIDLabel: UILabel
    var titleLabel: UILabel

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
