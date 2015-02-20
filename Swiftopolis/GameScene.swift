//
//  GameScene.swift
//  Swiftopolis
//
//  Created by Christian Benincasa on 12/27/14.
//  Copyright (c) 2014 Christian Benincasa. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, Subscriber {
    private let TILE_SIZE: Int = 16
    
    private var toolCursor: ToolCursor!
    private var currentTool: Tool! {
        didSet {
            setToolCursor()
        }
    }
    private var currentStroke: ToolStroke?
    private var toolNode: SKShapeNode?
    
    private var engine: Engine!
    
    // Convenience accessor for city
    private var city: City {
        get {
            return engine.city
        }
    }
    private let barrier = dispatch_queue_create("com.chrisbenincasa.micropolis", DISPATCH_QUEUE_SERIAL)
    
    private var debugOverlay = DebugOverlay()
    private var world: CityWorld = CityWorld()
    private var camera: Camera = Camera()
    private var worldCircle = SKShapeNode(circleOfRadius: 10.0)
    private var cameraCircle = SKShapeNode(circleOfRadius: 10.0)
    
    private var pixelWidth = 0
    private var pixelHeight = 0
    
    private var lastPoint: CGPoint?
    private var dragInProgress = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    init(engine: Engine) {
        super.init()
        self.engine = engine
        commonInit()
    }
    
    init(engine: Engine, size: CGSize) {
        super.init(size: size)
        self.engine = engine
        commonInit()
    }
    
    private func commonInit() {
        // Make the background clear to the drawn map underneath shows
        self.backgroundColor = NSColor.clearColor()
        
        // Generate a new map and assign it to the city
        // TODO: This should be factored out of the scene
        let cityMap = MapGenerator(city: self.city, width: self.city.map.width, height: self.city.map.height).generateNewCity()
        city.setCityMap(cityMap)
        
        // Save the pixel dimensions of the map
        pixelWidth = city.map.width * TILE_SIZE
        pixelHeight = city.map.height * TILE_SIZE
        self.size = NSSize(width: pixelWidth, height: pixelHeight)
        
        // Listen for city events
        city.addSubscriber(self)
        
        // Start the simulation
        startSimulationTimer()
        
        // Turn off gravity
        self.physicsWorld.gravity = CGVectorMake(0, 0)
        
        // Set anchor point to the middle of the screen
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // DEBUG
        self.addChild(debugOverlay)
        debugOverlay.addChild(worldCircle)
        debugOverlay.addChild(cameraCircle)
//        drawGrid()
        
        // Create main nodes
        // World represents the city and camera is the viewpoint.
        world.name = "world"
        self.addChild(world)
        self.camera.name = "camera"
        world.addChild(camera)
    }
    
    // MARK: Overrides and Animation
    
    override func didMoveToView(view: SKView) {
//        if let mapView = view as? MainSceneView {
//            mapView.city = self.city
//        }
        
        view.needsDisplay = true
        view.needsToDrawRect(view.frame)
    }
    
    override func update(currentTime: CFTimeInterval) {
        self.debugOverlay.removeFromParent()
        self.debugOverlay.removeAllChildren()
    }
    
    override func didFinishUpdate() {
        centerOnCamera()
        
        self.addChild(debugOverlay)
        
        cameraCircle.fillColor = NSColor.redColor()
        cameraCircle.position = camera.position
        
        worldCircle.fillColor = NSColor.blueColor()
        worldCircle.position = world.position
    }
    
    // MARK: Mouse Events
    
    override func mouseMoved(theEvent: NSEvent) {
        // TODO toss events that are out of the bounds of the scene
        if var tool = toolNode {
            let location = theEvent.locationInNode(world)
            let newPoint = getToolPoint(location)
            
            if tool.position != newPoint {
                tool.position = newPoint
            }
        }
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        if currentTool == nil {
            return
        }
        
        dragInProgress = true
        
        let location = theEvent.locationInNode(world)
        let point = engine.currentMapPoint
        let mapPoint = getToolPoint(location)
        let x = Int(point.x) + (Int(mapPoint.x) / TILE_SIZE)
        let y = Int(point.y) - (Int(mapPoint.y) / TILE_SIZE) - 1
        let newLocation = CGPoint(x: x, y: y)
        
        if lastPoint.isDefined() && lastPoint! == newLocation {
            return
        }
        
        if let stroke = currentStroke {
            stroke.dragTo(x, y)
            previewTool()
            var strokeBounds = stroke.getBounds()
            let newPoint = getToolPoint(location)
            
            setToolCursor(bounds: stroke.getBounds())
            
            // Update toolNode position if we're moving west -> east or north -> south
            lastPoint.foreach { point in
                if newLocation.x < point.x {
                    self.toolNode!.position = newPoint
                } else if newLocation.y > point.y {
                    self.toolNode!.position = newPoint
                }
            }
            
            view?.needsDisplay = true
        } else if currentTool != nil && currentTool == .Query {
            // doQueryTool
        }
        
        lastPoint = newLocation
    }
    
    override func mouseDown(theEvent: NSEvent) {
        let location = theEvent.locationInNode(world)
        
        /* Uncomment for camera move animation
        let moveAction = SKAction.moveTo(point, duration: 1.0)
        moveAction.timingMode = .EaseIn
        let drawAction = SKAction.customActionWithDuration(1.0, actionBlock: { (node, elapsed) -> Void in
        if let v = self.view as? MapView {
        v.currentPoint = CGPoint(x: node.position.x / 16.0, y: node.position.y / 16.0)
        //                println(CGPoint(x: Int(point.x / 16), y: Int(point.y / 16)))
        v.needsDisplay = true
        v.needsToDrawRect(v.frame)
        }
        })
        let group = SKAction.group([moveAction, drawAction])
        self.camera.runAction(group)
        */
        
        // convert to map point
        // TODO: fix this up because this implementation is terrible.
        // There's no way we should have to do calculations like this in each method
        // Normalize coordinate systems and make them easily convertable between each other
        let point = engine.currentMapPoint
        let mapPoint = getToolPoint(location)
        let x = Int(point.x) + (Int(mapPoint.x) / TILE_SIZE)
        let y = Int(point.y) - (Int(mapPoint.y) / TILE_SIZE) - 1
        
//        println("location in world = \(location)")
//        println("computed point = \(x), \(y)")
        
        let pressedButtons = NSEvent.pressedMouseButtons()
        switch pressedButtons {
        case 1: // left mouse
            if currentTool == nil {
                return
            }
            
            if currentTool == .Query {
                //
            } else {
                // Start the current stroke
                // The point that was clicked represents the center of the current tool, but strokes begin in the top-left
                // of the tool. Because of this, we adjust the point passed in so it matches what the preview is showing
                currentStroke = currentTool.beginStroke(city, x: x - (currentTool.size() / 2), y: y - (currentTool.size() / 2))
                previewTool()
            }
            
            break
        case 2: break
        default: // any other button
            // This is still a little busted because we don't validate/normalize the point we set to the new camera
            // location, so you can keep clicking but the map won't move
            // The map validates/normalizes the requested point to draw around, but we set blindly
            // TODO: Factor out the validation methods so we can use them here before blindly setting the camera point
            self.camera.position = location
            
            if let v = self.view as? MainSceneView {
                engine.setCurrentMapPoint(CGPoint(x: x, y: y))
                v.needsDisplay = true
                v.needsToDrawRect(v.frame)
            }
            break
        }
    }
    
    override func mouseUp(theEvent: NSEvent) {
        dragInProgress = false
        
        if let stroke = currentStroke {
            let location = stroke.getLocation()
            let result = stroke.apply()
            showToolResult(location, result: result)
            currentStroke = nil
            setToolCursor()
            println(result.toString())
        }
     
        view?.needsDisplay = true
    }
    
    // MARK: Simulation Helpers
    
    private func startSimulationTimer() {
        let delay: Double = Double(self.city.speed.delay) / 1000.0
        var wait = SKAction.waitForDuration(delay)
        var run = SKAction.runBlock({
            let speed = self.city.speed
            for _ in 0...speed.steps - 1 {
                self.city.animate()
            }
        }, queue: barrier)
        self.runAction(SKAction.repeatActionForever(SKAction.sequence([wait, run])), withKey: "simulation")
    }
    
    private func stopSimulationTimer() {
        if let action = self.actionForKey("simulation") {
            self.removeActionForKey("simulation")
        }
    }
    
    // MARK: Position Helpers
    
    private func getPoint(point: CGPoint) -> CGPoint {
        return CGPoint(x: Int(point.x) / TILE_SIZE, y: Int(point.y) / TILE_SIZE)
    }
    
    private func centerOnCamera() {
        let cameraPosition = self.convertPoint(camera.position, fromNode: world)
        world.position = CGPoint(x: world.position.x - cameraPosition.x, y: world.position.y - cameraPosition.y)
    }
    
    // MARK: Drawing Helpers
    
    private func drawGrid() {
        for var x = -Int(frame.width/2), y = 0; x <= Int(frame.width/2); x += TILE_SIZE, y++ {
            var path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, CGFloat(x), frame.width)
            CGPathAddLineToPoint(path, nil, CGFloat(x), -frame.width)
            let node = SKShapeNode(path: path)
            if x == 0 {
                node.strokeColor = NSColor.greenColor()
            } else if x % 5 == 0 {
                node.strokeColor = NSColor.redColor()
            } else {
                node.strokeColor = NSColor.blackColor()
            }
            world.addChild(node)
        }
        
        for var y = -Int(frame.height/2), x = 0; y <= Int(frame.height/2); y += TILE_SIZE, x++ {
            var path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, -frame.height, CGFloat(y))
            CGPathAddLineToPoint(path, nil, frame.height, CGFloat(y))
            let node = SKShapeNode(path: path)
            
            if y == 0 {
                node.strokeColor = NSColor.greenColor()
            } else if y % 5 == 0 {
                node.strokeColor = NSColor.redColor()
            } else {
                node.strokeColor = NSColor.blackColor()
            }
            world.addChild(node)
        }
    }
    
    // MARK: Tool Cursor
    
    func setCurrentTool(tool: Tool) {
        self.currentTool = tool
    }
    
    private func getToolPoint(locationInWorld: CGPoint) -> CGPoint {
        var p = Int(floor(locationInWorld.x / CGFloat(TILE_SIZE))) // Adjust for tool center
        var q = Int(floor(locationInWorld.y / CGFloat(TILE_SIZE)))
        
        if currentTool != nil && currentTool.size() >= 3 {
            p--
            q--
        }
        
        return CGPoint(x: p * TILE_SIZE, y: q * TILE_SIZE)
    }
    
    private func setToolCursor(bounds: NSRect? = nil) {
        if currentTool != nil {
            let lastNode = toolNode
            
            let standardSize = NSSize(width: currentTool.size(), height: currentTool.size())
            let newRect = bounds.getOrElse(NSRect(origin: NSPoint.zeroPoint, size: standardSize))
            let lastPosition = lastNode != nil ? lastNode!.position : NSPoint.zeroPoint
            
            lastNode?.removeFromParent()
            
            toolCursor = ToolCursor(tool: currentTool, withRect: newRect)
            toolNode = makeToolCursor(newRect)
            toolNode!.position = lastPosition
            world.addChild(toolNode!)
        }
    }
    
    private func makeToolCursor(rect: NSRect) -> SKShapeNode {
        let shapeRect = NSRect(x: 0, y: 0, width: Int(rect.size.width) * TILE_SIZE, height: Int(rect.size.height) * TILE_SIZE)
        toolNode = SKShapeNode(rect: shapeRect)
        toolNode!.fillColor = toolCursor.fillColor
        toolNode!.lineWidth = 2.0
        toolNode!.glowWidth = 0.5
        toolNode!.strokeColor = toolCursor.borderColor

        return toolNode!
    }
    
    private func previewTool() {
        if let stroke = currentStroke {
            let preview = stroke.getPreview()
            let bounds = preview.getBounds()
            let dirtyRect = NSRect(x: Int(bounds.origin.x) * TILE_SIZE, y: Int(bounds.origin.y) * TILE_SIZE, width: Int(bounds.width) * TILE_SIZE, height: Int(bounds.height) * TILE_SIZE)
            
            engine.setToolPreview(preview)
            
            view?.needsToDrawRect(dirtyRect)
            view?.needsDisplay = true
        }
    }
    
    private func showToolResult(location: CityLocation, result: ToolResult) {
        switch result {
        case .Success:
            // TODO fire sound
            break
        case .None: break
        case .InvalidPosition:
            // TODO show message about bad position
            break
        case .InsufficientFunds:
            // TODO sound + message
            break
        default: break
        }
    }
    
    // MARK: Subscriber Protocol
    
    func citySoundFired(data: [NSObject : AnyObject]) {
        if let sound = data["sound"] as? Sound {
        }
    }
}
