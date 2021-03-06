//
//  Smoothers.swift
//  Swiftopolis
//
//  Created by Christian Benincasa on 1/10/15.
//  Copyright (c) 2015 Christian Benincasa. All rights reserved.
//

import Cocoa

class Smoothers {

    class func smooth(inout tem: [[Int]]) {
        let h = tem.count, w = tem[0].count
        var i = 0
        _ = NSDate()
        for y in 0 ..< h {
            for x in 0 ..< w {
                var z = tem[y][x]
                if x > 0 {
                    z += tem[y][x - 1]
                }
                
                if x + 1 < w {
                    z += tem[y][x + 1]
                }
                
                if y > 0 {
                    z += tem[y - 1][x]
                }
                
                if y + 1 < h {
                    z += tem[y + 1][x]
                }
                
                z /= 4
                
                if z > 255 {
                    z = 255
                }
                
                i += 1
                tem[y][x] = z
            }
        }
        
//        let timeInterval: Double = NSDate().timeIntervalSinceDate(start)
//        println("smooth (\(i) iterations) took \(timeInterval) seconds");
    }
    
    class func smoothN(inout tem: [[Int]], n: Int = 2) {
        for _ in 0 ..< n {
            smooth(&tem)
        }
    }
    
    class func smoothTerrain(inout tem: [[Int]]) {
        let h = tem.count, w = tem[0].count
        
        for y in 0 ..< h {
            for x in 0 ..< w {
                var z = tem[y][x]
                if x > 0 {
                    z += tem[y][x - 1]
                }
                
                if x + 1 < w {
                    z += tem[y][x + 1]
                }
                
                if y > 0 {
                    z += tem[y - 1][x]
                }
                
                if y + 1 < h {
                    z += tem[y + 1][x]
                }
            }
        }
    }
    
    class func smoothFirePoliceMap(inout tem: [[Int]]) {
        let h = tem.count, w = tem[0].count
        
        for y in 0 ..< h {
            for x in 0 ..< w {
                var z = 0
                if x > 0 {
                    z += tem[y][x - 1]
                }
                
                if x + 1 < w {
                    z += tem[y][x + 1]
                }
                
                if y > 0 {
                    z += tem[y - 1][x]
                }
                
                if y + 1 < h {
                    z += tem[y + 1][x]
                }
                
                z = (z / 4) + tem[y][x]
                tem[y][x] = z / 2
            }
        }
    }
}
