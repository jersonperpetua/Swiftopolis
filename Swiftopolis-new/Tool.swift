//
//  Tool.swift
//  Swiftopolis
//
//  Created by Christian Benincasa on 12/28/14.
//  Copyright (c) 2014 Christian Benincasa. All rights reserved.
//

import Cocoa

enum Tool: String {
    // Zones
    case Residential = "residential"
    case Commercial = "commercial"
    case Industrial = "industrial"
    // Misc
    case Bulldozer = "bulldozer"
    case Query = "query"
    // Road-like
    case Wire = "wire"
    case Road = "road"
    case Rail = "rail"
    // Power plants
    case Coal = "coal"
    case Nuclear = "nuclear"
    // Special
    case PoliceStation = "police_station"
    case FireStation = "fire_station"
    case Stadium = "stadium"
    case Park = "park"
    case Seaport = "seaport"
    case Airport = "airport"
    
    func cost() -> Int {
        switch self {
        case .Bulldozer: return 1
        case .Residential, .Commercial, .Industrial: return 100
        case .FireStation, .PoliceStation: return 500
        case .Park: return 10
        case .Seaport, .Coal: return 3000
        case .Nuclear, .Stadium: return 5000
        case .Airport: return 10000
        case .Query: return 0
        default: return -1
        }
    }
    
    func size() -> Int {
        switch self {
        case .Bulldozer, .Wire, .Road, .Rail, .Query, .Park: return 1
        case .Residential, .Commercial, .Industrial, .FireStation, .PoliceStation: return 3
        case .Stadium, .Seaport, .Coal, .Nuclear: return 4
        case .Airport: return 6
        default: return -1
        }
    }
    
    func beginStroke(city: City, x: Int, y: Int) -> ToolStroke {
        switch self {
        case .Bulldozer: return BulldozerTool(city: city, tool: self, x: x, y: y)
        case .Wire, .Road, .Rail: return RoadLikeTool(city: city, tool: self, x: x, y: y)
        case .FireStation, .PoliceStation, .Stadium, .Seaport, .Coal, .Nuclear, .Airport: return BuildingTool(city: city, tool: self, x: x, y: y)
        default: return ToolStroke(city: city, tool: self, x: x, y: y)
        }
    }
}
