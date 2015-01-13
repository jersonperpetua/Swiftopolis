//
//  City.swift
//  Swiftopolis
//
//  Created by Christian Benincasa on 12/31/14.
//  Copyright (c) 2014 Christian Benincasa. All rights reserved.
//

import Cocoa

class City {
    private(set) var map: Map = Map()
    let budget: Budget = Budget()
    let history: CityHistory = CityHistory()
    private lazy var disasters: DisasterEngine = {
        [unowned self] in return DisasterEngine(city: self)
    }()
    
    private var evaluator = CityEvaluation()
    private var subscribers: [Subscriber] = []
    private var tileBehaviors: [String : TileBehavior] = [:]
    private(set) var demand: Demand = Demand()
    private(set) var census: Census = Census()
    private(set) var specialSprites: [Sprite] = []
    
    private(set) var residentialZones: Int = 0
    private(set) var commercialZones: Int = 0
    private(set) var industrialZones: Int = 0
    
    private(set) var residentialPopulation: Int = 0
    private(set) var commercialPopulation: Int = 0
    private(set) var industrialPopulation: Int = 0
    
    private(set) var cityTime: Int = 0 // counts "weeks" (actually, 1/48'ths years)
    private var scycle = 0 // cityTime % 1024
    private var fcycle = 0 // simulation steps
    private var acycle = 0 // animation
    
    private(set) var disasterFree: Bool = false
    private(set) var floodTurnsRemaining: Int = 0
    
    private(set) var powerPlants: [CityLocation] = []
    private(set) var pollutionAverage: Int = 0
    
    private(set) var crimeAverage: Int = 0
    
    private(set) var difficultyLevel: DifficultyLevel = .Easy
    private(set) var speed: Speed = NormalSpeed()
    
    private var newPower = false
    
    // MARK: Map API
    
    func withinBounds(x xpos: Int, y ypos: Int) -> Bool {
        return map.withinBounds(x: xpos, y: ypos)
    }

    func getTile(x xpos: Int, y ypos: Int) -> UInt16 {
        return map.getTile(x: xpos, y: ypos)!
    }

    func setTile(x xpos: Int, y ypos: Int, tile newTile: UInt16) {
        if map.setTile(x: xpos, y: ypos, tile: newTile) {
            onTileChanged(x: xpos, y: ypos)
        }
    }
    
    func getWidth() -> Int {
        return map.width
    }
    
    func getHeight() -> Int {
        return map.height
    }
    
    func setCityMap(map: [[UInt16]]) {
        self.map.setMap(map)
    }
    
    // MARK: Populations
    
    func adjustResidentialPopulation(amount: Int = 1) {
        residentialPopulation += amount
    }
    
    func adjustCommercialPopulation(amount: Int = 1) {
        commercialPopulation += amount
    }
    
    func adjustIndustrialPopulation(amount: Int = 1) {
        industrialPopulation += amount
    }
    
    func adjustResidentialZones(amount: Int = 1) {
        residentialZones += amount
    }
    
    func adjustCommercialZones(amount: Int = 1) {
        commercialZones += amount
    }
    
    func adjustIndustrialZones(amount: Int = 1) {
        industrialZones += amount
    }
    
    // MARK: Budget APi
    
    func spend(amount: Int) {
        budget.totalFunds -= amount
        
    }
    
    func animate() {
        acycle = (acycle + 1) % 960
        if acycle % 2 == 0 {
            step()
        }
    }
    
    func step() {
        fcycle = (fcycle + 1) % 1024
        simulate(fcycle % 16)
    }
    
    // MARK: Simulation
    func simulate(phase: Int) {
        let start = NSDate()
        let band = map.width / 8
        
        switch phase {
        case 0:
            break
        case 1...7:
            mapScan((phase - 1) * band, x1: phase * band)
            break
        case 8:
            mapScan((phase - 1) * band, x1: map.width)
            break
        case 9:
            if cityTime % CensusConstants.CENSUS_RATE == 0 {
                // takeCensus()
                if cityTime % (CensusConstants.CENSUS_RATE * 12) == 0 {
                    // takeCenesus2? wat
                }
                
                onCensusChanged()
            }
            
            // collectTaxPartial()
            
            if cityTime % BudgetConstants.TAX_FREQUENCY == 0 {
                // collectTax()
//                evaluator.cityEvaluation()
            }
            
            break
        case 10:
            if scycle % 10 == 0 {
                // decROGMem()
            }
            
            break
        case 11:
            powerScan()
            // onMapChanged -> Power
            
            newPower = true
            break
        case 12:
            pollutionTerrainScan()
            break
        case 13:
            crimeScan()
            break
        case 14:
            populationDensityScan()
            break
        case 15:
            fireAnalysis()
            doDisasters()
            break
        default: fatalError("Unreachable")
        }
        
        let end = NSDate()
        let timeInterval: Double = end.timeIntervalSinceDate(start)
        if timeInterval > 1/60 {
            println("Long simulation step occurred \(phase): \(timeInterval) seconds");
        }
    }
    
    // TODO: factor out scanners
    private func mapScan(x0: Int, x1: Int) {
        
    }
    
    private func takeCensus() {
        var resMax = 0, comMax = 0, indMax = 0
        
        for var i = 118; i >= 0; i-- {
            if history.residential[i] > resMax {
                resMax = history.residential[i]
            }
            
            if history.commercial[i] > comMax {
                comMax = history.commercial[i]
            }
            
            if history.industrial[i] > indMax {
                indMax = history.industrial[i]
            }
        }
    }
    
    private func powerScan() {
        let movePowerLocation: (CityLocation, Int) -> Bool = { (loc: CityLocation, dir: Int) -> Bool in
            switch dir {
            case 0:
                if loc.y > 0 {
                    loc.setY(loc.y - 1)
                    return true
                } else {
                    return false
                }
            case 1:
                if loc.x + 1 < self.map.width {
                    loc.setX(loc.x + 1)
                    return true
                } else {
                    return false
                }
            case 2:
                if loc.y + 1 < self.map.height {
                    loc.setY(loc.y + 1)
                    return true
                } else {
                    return false
                }
            case 3:
                if loc.x > 0 {
                    loc.setX(loc.x - 1)
                    return true
                } else {
                    return false
                }
            case 4: return true
            default: return false
            }
        }
        
        let testForCond = { (loc: CityLocation, dir: Int) -> Bool in
            let xSave = loc.x, ySave = loc.y
            var retVal = false
            if movePowerLocation(loc, dir) {
                let tile = self.map.getTile(x: loc.x, y: loc.y)
                retVal = TileConstants.isConductive(tile!) &&
                    tile != TileConstants.NUCLEAR &&
                    tile != TileConstants.POWERPLANT &&
                    !self.map.isTilePowered(x: loc.x, y: loc.y)
            }
            
            loc.setCoordinates(x: xSave, y: ySave)
            
            return retVal
        }
        
        map.clearPowerMap()
        
        let maxPower = census.coalCount * 700 + census.nuclearCount * 2000
        var numPower = 0, i = 0
        
        for location in powerPlants {
            var aDir = 4, conNum = 0
            do {
                numPower++
                if numPower > maxPower {
                    // brownout
                }
                
                //move power location
                map.setPowerMap(x: location.x, y: location.y, value: true)
                var dir = 0
                while (dir < 4 && conNum < 2) {
                    if testForCond(location, dir) {
                        conNum++
                        aDir = dir
                    }
                    
                    dir++
                }
                
                // TODO: Look into this -- seems weird
                if conNum <= 1 {
                    powerPlants.removeAtIndex(i)
                }
            } while (conNum != 0)
            
            i++
        }
    }
    
    private func pollutionTerrainScan() {
        let qX = (map.width + 3) / 4,
            qY = (map.height + 3) / 4
        
        var qtem: [[Int]] = [],
            landValueTotal = 0,
            landValueCount = 0
        
        Utils.initializeMatrix(&qtem, width: qY, height: qX, value: 0)
        
        let HWLDX = (map.width + 1) / 2
        let HWLDY = (map.height + 1) / 2
        var tem: [[Int]] = []
        Utils.initializeMatrix(&tem, width: HWLDY, height: HWLDX, value: 0)
        
        var start = NSDate()
        
        var i = 0
        for var x = 0; x < HWLDX; x++ {
            for var y = 0; y < HWLDY; y++ {
                var pLevel = 0,
                    landValueFlag = 0,
                    zx = x << 1,
                    zy = y << 1
                
                for var mx = zx; mx <= zx + 1; mx++ {
                    for var my = zy; my <= zy + 1; my++ {
                        i++
                        let tile = map.getTile(x: mx, y: my)!
                        if tile != TileConstants.DIRT {
                            if tile < TileConstants.RUBBLE {
                                qtem[y / 2][x / 2] += 15
                                continue
                            }
                            
                            pLevel += TileConstants.getPollutionValue(tile)
                            if TileConstants.isConstructed(tile) {
                                landValueFlag++
                            }
                        }
                    }
                }
                
                if pLevel < 0 {
                    pLevel = 250
                }
                
                if pLevel > 255 {
                    pLevel = 255
                }
                
                tem[y][x] = pLevel
                
                if landValueFlag != 0 {
                    // Land value equation
                    var distance = 34 - map.distanceToCityCenter(x: x, y: y)
                    distance *= 4
                    distance += Int(map.getTerrainFeaturesAtLocation(x: x, y: y))
                    distance -= Int(map.getPollutionLevelAtLocation(x: x, y: y, factor: 1))
                    if map.getCrimeAtLocation(x: x, y: y, factor: 1) > 190 {
                        distance -= 20
                    }
                    
                    if distance > 250 {
                        distance = 250
                    }
                    
                    if distance < 1 {
                        distance = 1
                    }
                    
                    map.setLandValueAtLocation(x: x, y: y, amount: UInt16(distance), factor: 1)
                    landValueTotal += distance
                    landValueCount++
                } else {
                    map.setLandValueAtLocation(x: y, y: y, amount: 0, factor: 1)
                }
            }
        }
        
        var timeInterval: Double = NSDate().timeIntervalSinceDate(start)
        println("big for-loop (\(i) iterations) took \(timeInterval) seconds");
        
        // TODO: set land value average
        
        start = NSDate()
        
        Smoothers.smoothN(&tem, n: 2)
        
        timeInterval = NSDate().timeIntervalSinceDate(start)
        println("smootnN took \(timeInterval) seconds")
        
        start = NSDate()
        
        var pCount = 0, pTotal = 0, pMax = 0
        i = 0
        for var x = 0; x < HWLDX; x++ {
            for var y = 0; y < HWLDY; y++ {
                i++
                let z = tem[y][x]
                map.setPollutionLevelAtLocation(x: x, y: y, value: UInt16(z), factor: 1)
                
                if z != 0 {
                    pCount++
                    pTotal += z
                    if z > pMax || (z == pMax && arc4random_uniform(4) == 0) {
                        pMax = z
                        map.pollutionMaxLocation = CityLocation(x: 2 * x, y: 2 * y)
                    }
                }
            }
        }
        
        timeInterval = NSDate().timeIntervalSinceDate(start)
        println("second double-for (\(i) iterations) took \(timeInterval) seconds")
        
        // TODO: set pollution average
        
        start = NSDate()
        Smoothers.smoothTerrain(&tem)
        timeInterval = NSDate().timeIntervalSinceDate(start)
        println("smoothTerrain took \(timeInterval) seconds")
        
        map.setTerrainFeatures(tem)
        
        // TODO: send event for pollution map
        // TODO: send event for land value map
    }
    
    private func crimeScan() {
        var policeMap = self.map.policeMap
        for _ in 0...2 {
            Smoothers.smoothFirePoliceMap(&policeMap)
        }
        
        map.setPoliceMap(policeMap)
        
        map.setPoliceReachMap(policeMap)
        
        var count = 0, sum = 0, cmax = 0
        map.foreachLandValue { (value: UInt16, index: (Int, Int)) in
            let (x, y) = index
            if value != 0 {
                count++
                var z: Int = Int(128 - value + self.map.getPopulationDensityAtLocation(x: x, y: y, factor: 1))
                z = min(300, z)
                z -= self.map.getPoliceCoverageAtLocation(x: x, y: y, factor: 4)
                z = min(250, z)
                z = max(0, z)
                self.map.setCrimeAtLocation(x: x, y: y, value: UInt16(z), factor: 1)
                
                sum += z
                if z > cmax || (z == cmax && arc4random_uniform(4) == 0) {
                    cmax = z
                    self.map.crimeMaxLocation = CityLocation(x: x * 2, y: y * 2)
                }
            } else {
                self.map.setCrimeAtLocation(x: x, y: y, value: 0, factor: 1)
            }
        }

        crimeAverage = count != 0 ? sum / count : 0
        
        // TODO: send Police overlay map change event
    }
    
    private func populationDensityScan() {
        var xTotal = 0, yTotal = 0, zoneCount = 0
        var tem: [[Int]] = []
        Utils.initializeMatrix(&tem, width: (self.map.height + 1) / 2, height: (self.map.width + 1) / 2, value: 0)
        
        for var x = 0; x < self.map.width; x++ {
            for var y = 0; y < self.map.height; y++ {
                let tile = map.getTile(x: x, y: y)!
                if TileConstants.isZoneCenter(tile) {
                    var den = computePopulationDensity(x: x, y: y, tile: tile)
                    if den > 254 {
                        den = 254
                    }
                    
                    tem[y / 2][x / 2] = den
                    xTotal += x
                    yTotal += y
                    zoneCount++
                }
            }
        }
        
        Smoothers.smoothN(&tem, n: 3)
        
        for var x = 0; x < (self.map.width + 1) / 2; x++ {
            for var y = 0; y < (self.map.height + 1) / 2; y++ {
                map.setPopulationDensityAtLocation(x: x, y: y, value: UInt16(2 * tem[y][x]), factor: 1)
            }
        }
        
        // TODO: distIntMarket
        
        if zoneCount != 0 {
            map.setMapCenterOfMass(x: xTotal / zoneCount, y: yTotal / zoneCount)
        } else {
            map.setMapCenterOfMass(x: (self.map.width + 1) / 2, y: (self.map.height + 1) / 2)
        }
        
        // TODO: fire events
    }
    
    private func fireAnalysis() {
        var fireMap = map.fireMap
        for _ in 0..<3 {
            Smoothers.smoothFirePoliceMap(&fireMap)
        }
        map.setFireMap(fireMap)
        map.setFireReachMap(fireMap)
        
        // TODO: fire events
    }
    
    private func doDisasters() {
        if floodTurnsRemaining > 0 {
            floodTurnsRemaining--
        }
        
        if disasterFree {
            return
        }
        
        if arc4random_uniform(UInt32(DifficultyLevel.disasterProbForDifficulty(self.difficultyLevel))) != 0 {
            return
        }
        
        switch arc4random_uniform(9) {
        case 0...1:
            if let fireLocation = self.disasters.setFire() {
                onCityMessage(CityMessage(message: "FIRE!!!"), location: fireLocation)
            }
            break
        case 2...3:
            if let floodLocation = self.disasters.makeFlood() {
                onCityMessage(CityMessage(message: "Flood!"), location: floodLocation)
            }
            break
        case 4: break
        case 5:
            if let existingSprite = findSpriteOfKind(.Tornado) as? TornadoSprite {
                existingSprite.setRemainingTurns(200)
                return
            }
            let tornadoSprite = self.disasters.makeTornado()
            self.specialSprites.append(tornadoSprite)
            onCityMessage(CityMessage(message: "Tornado!!"), location: tornadoSprite.cityLocation)
            break
        case 6:
            let centerOfMass = CityLocation(x: self.map.centerOfMassX, y: self.map.centerOfMassY)
            onCitySound(EarthquakeSound(), location: centerOfMass)
            onEarthquakeStarted()
            onCityMessage(CityMessage(message: "EARTHquake!!"), location: centerOfMass)
            self.disasters.makeEarthquake()
            break
        case 7...8:
            if let existingMonster = findSpriteOfKind(.Monster) as? MonsterSprite {
                existingMonster.soundCount = 1
                existingMonster.setRemainingTurns(100)
                existingMonster.wantsToReturnHome = false
                existingMonster.setDestination(map.pollutionMaxLocation)
            } else if pollutionAverage > 60 && findSpriteOfKind(.God) == nil {
                let monster = self.disasters.makeMonster()
                self.specialSprites.append(monster)
            }
            break
        default: break
        }
    }
    
    private func computePopulationDensity(#x: Int, y: Int, tile: UInt16) -> Int {
        if tile == TileConstants.RESCLR {
            return doFreePop(x: x, y: y)
        } else if tile < TileConstants.COMBASE {
            return TileConstants.residentialZonePopulation(tile)
        } else if tile < TileConstants.INDBASE {
            return TileConstants.commercialZonePopulation(tile)
        } else if tile < TileConstants.PORTBASE {
            return TileConstants.industrialZonePopulation(tile)
        } else {
            return 0
        }
    }
    
    // MARK: Power API
    
    func isTilePowered(x xpos: Int, y ypos: Int) -> Bool {
        return map.isTilePowered(x: xpos, y: ypos)
    }
    
    func hasPower(x xpos: Int, y ypos: Int) -> Bool {
        return map.locationHasAccessToPower(x: xpos, y: ypos)
    }
    
    func setTilePower(x xpos: Int, y ypos: Int, power: Bool) {
        map.setTilePower(x: xpos, y: ypos, power: power)
    }
    
    func turnOnZonePower(x xpos: Int, y ypos: Int, width: Int, height: Int) {
        assert(width >= 3, "Too small!")
        assert(height >= 3, "Tool small")
        
        for dx in 0...width - 1 {
            for dy in 0...height - 1 {
                let x = xpos - 1 + dx
                let y = ypos - 1 + dy
                if let t = map.getRawTile(x: x, y: y) {
                    if let tile = Tiles.get(Int(t & TileConstants.LOMASK)) {
                        if (tile.onPower != nil) {
                            map.setTile(x: x, y: y, tile: UInt16(tile.onPower!) | (t & TileConstants.ALLBITS))
                        }
                    }
                }
            }
        }
    }
    
    func shutdownZonePower(x xpos: Int, y ypos: Int, width: Int, height: Int) {
        assert(width >= 3, "Too small!")
        assert(height >= 3, "Tool small")
        
        for dx in 0...width - 1 {
            for dy in 0...height - 1 {
                let x = xpos - 1 + dx
                let y = ypos - 1 + dy
                if let t = map.getRawTile(x: x, y: y) {
                    if let tile = Tiles.get(Int(t & TileConstants.LOMASK)) {
                        if (tile.onShutdown != nil) {
                            map.setTile(x: x, y: y, tile: UInt16(tile.onShutdown!) | (t & TileConstants.ALLBITS))
                        }
                    }
                }
            }
        }
    }
    
    func addPowerPlantAtLocation(x xpos: Int, y ypos: Int) {
        powerPlants.append(CityLocation(x: xpos, y: ypos))
    }
    
    func nuclearMeltdownProb() -> UInt32 {
        switch self.difficultyLevel {
        case .Easy: return 30000
        case .Medium: return 20000
        case .Hard: return 10000
        default: return 0
        }
    }

    func killZone(x xpos: Int, y ypos: Int) {
        
    }

    func makeExplosion(x xpos: Int, y ypos: Int) {

    }
    
    // MARK: Sprites
    private func findSpriteOfKind(kind: SpriteKind) -> Sprite? {
        for sprite in specialSprites {
            if sprite.kind == kind {
                return sprite
            }
        }
        
        return nil
    }
    
    // MARK: Traffic API
    
    func trafficDensityAtLocation(x xpos: Int, y ypos: Int) -> UInt16 {
        return map.trafficDensityAtLocation(x: xpos, y: ypos)
    }
    
    func addTraffic(x xpos: Int, y ypos: Int, amount: Int) {
        let newTraffic = map.increaseTrafficDensity(x: xpos, y: ypos, amount: amount)
        
        if newTraffic == MapConstants.MAX_TRAFFIC && arc4random_uniform(6) == 0 {
            // Spawn helicopter
        }
    }
    
    // MARK: Population API
    // TODO: rename this function
    func doFreePop(x xpos: Int, y ypos: Int) -> Int {
        var count = 0
        for x in (xpos - 1)...(xpos + 1) {
            for y in (ypos - 1)...(ypos + 1) {
                if withinBounds(x: x, y: y) {
                    let loc = getTile(x: x, y: y)
                    if loc >= TileConstants.LHTHR && loc <= TileConstants.HHTHR {
                        count++
                    }
                }
            }
        }
        
        return count
    }
    
    func getPopulationDensity(x xpos: Int, y ypos: Int) -> UInt16 {
        return map.getPopulationDensityAtLocation(x: xpos, y: ypos)
    }
    
    // MARK: Land Value API
    
    func getLandValue(x xpos: Int, y ypos: Int) -> UInt16 {
        return map.getLandValueAtLocation(x: xpos, y: ypos)
    }
    
    // MARK: Pollution API
    
    func getPollution(x xpos: Int, y ypos: Int) -> UInt16 {
        return map.getPollutionLevelAtLocation(x: xpos, y: ypos)
    }
    
    // MARK: Rate of Growth
    
    func adjustRateOfGrowth(x xpos: Int, y ypos: Int, amount: Int) {
        return map.increaseRateOfGrowth(x: xpos, y: ypos, amount: amount)
    }

    // MARK: Events
    
    func addSubscriber(sub: Subscriber) {
        self.subscribers.append(sub)
        self.onCitySound(EarthquakeSound(), location: nil)
    }

    private func onCityMessage(message: CityMessage, location: CityLocation?) {
        var data: [NSObject : AnyObject] = [NSString(string: "message") : message]
        if location != nil {
            data[NSString(string: "location")] = location!
        }
        
        for subscriber in self.subscribers {
            subscriber.cityMessage?(data)
        }
    }
    
    private func onCitySound(sound: CitySound, location: CityLocation?) {
        var data: [NSObject : AnyObject] = [NSString(string: "sound") : sound]
        if location != nil {
            data[NSString(string: "location")] = location!
        }
        
        for subscriber in self.subscribers {
            subscriber.citySoundFired?(data)
        }
    }
    
    private func onCensusChanged() {
        for subscriber in self.subscribers {
            subscriber.censusChanged?([:])
        }
    }
    
    private func onTileChanged(#x: Int, y: Int) {
        for subscriber in self.subscribers {
            subscriber.tileChanged?(x, y)
        }
    }
    
    private func onFundsChanged() {
        for subscriber in self.subscribers {
            subscriber.fundsChanged?([:])
        }
    }
    
    private func onEarthquakeStarted() {
        for subscriber in self.subscribers {
            subscriber.earthquakeStarted?([:])
        }
    }
    
    // MARK: Private Helpers
    
    private func initTileBehaviors() {
        let x = FireTerrainBehavior(city: self)
    }
}

enum DifficultyLevel: Int {
    case Easy = 0, Medium = 1, Hard = 2
    
    static func disasterProbForDifficulty(difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .Easy: return 480
        case .Medium: return 240
        case .Hard: return 60
        default: return 0
        }
    }
}
