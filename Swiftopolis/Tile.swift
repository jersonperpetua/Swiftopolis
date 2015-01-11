//
//  Tile.swift
//  Swiftopolis
//
//  Created by Christian Benincasa on 12/29/14.
//  Copyright (c) 2014 Christian Benincasa. All rights reserved.
//

import Cocoa

class Tile {
    var tileNumber: UInt16 = 0
    var name: String = ""
    var nextAnimationTile: Int?
    var onPower: Int?    // Tile to use when this becomes powered
    var onShutdown: Int? // Tile to use if this gets shutdown
    var canBulldoze: Bool = true
    var canBurn: Bool = true
    var canConduct: Bool = true
    var overWater: Bool = true
    var isZone: Bool = false
    var owner: Tile?
    var ownerOffsetX: Int?
    var ownerOffsetY: Int?
    var buildingInfo: BuildingInfo?
    var attributes: [String:String] = [:]
    var images: [String] = []
    
    init(tileNumber: UInt16, tileName: String) {
        self.tileNumber = tileNumber
        self.name = tileName
    }
    
    func getAttribute(key: String) -> String? {
        return self.attributes[key]
    }
    
// MARK: getters
    
    func population() -> Int {
        if let pop = self.getAttribute("population")?.toInt() {
            return pop
        } else {
            return 0
        }
    }
    
    func pollution() -> Int {
        if let poll = self.getAttribute("pollution")?.toInt() {
            return poll
        } else if let o = self.owner {
            return o.pollution()
        } else {
            return 0
        }
    }
    
    func getBuildingSize() -> (Int, Int)? {
        if let bi = buildingInfo {
            return (bi.width, bi.height)
        } else {
            return nil
        }
    }
    
    private func resolveBuildingInfo(tileMap: [String:Tile]) {
        if let info = self.getAttribute("building") {
            let dimensions = info.componentsSeparatedByString("x")
            var bi = BuildingInfo(width: dimensions[0].toInt()!, height: dimensions[1].toInt()!, members: [])
            var startTile = self.name.toInt()!
            
            if bi.width >= 3 {
                startTile -= 1
            }
            
            if bi.height >= 3 {
                startTile -= bi.width
            }
            
            for row in 0...bi.height {
                for col in 0...bi.width {
                    let tile = tileMap[String(startTile)]!
                    bi.members.append(tile)
                    startTile += 1
                }
            }
            
            self.buildingInfo = bi
        }
    }
}

struct BuildingInfo {
    var width: Int
    var height: Int
    var members: [Tile] = []
}
