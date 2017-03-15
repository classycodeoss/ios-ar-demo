//
//  ViewController.swift
//  AR Demo App
//
//  Created by Alex Suzuki on 14.03.17.
//  Copyright © 2017 Classy Code. All rights reserved.
//

import UIKit
import CoreLocation
import Mapbox
import SceneKit

class ViewController: UIViewController, CLLocationManagerDelegate, MGLMapViewDelegate, SCNSceneRendererDelegate {

    @IBOutlet var mapView: MGLMapView!
    @IBOutlet var sceneView: SCNView!
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    // the pitch to use for the map view
    static let kMapPitchDegrees: Float = 45.0
    
    // player and map location
    var centerCoordinate: CLLocationCoordinate2D?
    var locationManager: CLLocationManager!
    var lastLocation: CLLocation?
    var lastHeading: CLHeading?
    
    // SceneKit scene
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var camera: SCNCamera!
    var playerNode: SCNNode!
    var officeNode: SCNNode!
    var ambientLightNode: SCNNode!
    var ambientLight: SCNLight!
    var omniLightNode: SCNNode!
    var omniLight: SCNLight!
    var sceneRect: CGRect!
    
    // Rendering state
    var renderStartTime: TimeInterval?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        setupMapView()
        setupSceneView()
    }
    
    func setupMapView() {
        let camera = MGLMapCamera()
        mapView.setCamera(camera, animated: false)
        
        // MapBox configuration
        mapView.styleURL = URL(string: "YOUR STYLE URL HERE")
        
        // restrict the zoom level
        mapView.maximumZoomLevel = 19.0
        mapView.zoomLevel = 18.0
        mapView.minimumZoomLevel = 17.0
        
        // restrict user interaction on the map
        mapView.allowsScrolling = false
        mapView.allowsRotating = true
        mapView.allowsTilting = false
        mapView.allowsZooming = true
        
        // disable built-in controls and user location
        mapView.displayHeadingCalibration = false
        mapView.showsUserLocation = false
        mapView.compassView.isHidden = true
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        mapView.delegate = self
        centerCoordinate = mapView.centerCoordinate
        
        // detect tap gestures on map
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onMapViewTapped(recognizer:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        mapView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func setupSceneView() {
        // transparent background for use as overlay
        sceneView.backgroundColor = UIColor.clear
        scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.loops = true
        sceneView.isPlaying = true
        sceneRect = sceneView.bounds
        
        // camera
        cameraNode = SCNNode()
        camera = SCNCamera()
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        
        // lighting
        ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(colorLiteralRed: 0.8, green: 0.8, blue: 0.8, alpha: 1.0).cgColor
        ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // lighting
        omniLight = SCNLight()
        omniLight.type = .omni
        omniLightNode = SCNNode()
        omniLightNode.light = omniLight
        
        scene.rootNode.addChildNode(omniLightNode)
        
        // player node
        playerNode = SCNNode()
        let playerScene = SCNScene(named: "classy_crab.stl")!
        let playerModelNode = playerScene.rootNode.childNodes.first!
        playerModelNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.118, green: 0.196, blue: 0.471, alpha: 1.0)
        playerModelNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        playerNode.addChildNode(playerModelNode)
        scene.rootNode.addChildNode(playerNode)
        
        // office node
        officeNode = SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0))
        officeNode.setValue(CLLocationCoordinate2DMake(47.363688, 8.513255), forKey: "coordinate")
        officeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        officeNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        officeNode.setValue(false, forKey: "tapped")
        scene.rootNode.addChildNode(officeNode)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // ask for permission / enable location updates
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if !(authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        else {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        // disable location updates
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        
        super.viewWillDisappear(animated)
    }



    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let (shouldUpdate, immediately) = shouldUpdateLocation(newLocation: locations[0])
        if shouldUpdate {
            let heading = lastHeading?.magneticHeading ?? 0
            let previousAltitude = mapView.camera.altitude
            
            let camera = MGLMapCamera(lookingAtCenter: self.lastLocation!.coordinate, fromDistance: previousAltitude,
                                      pitch: CGFloat(ViewController.kMapPitchDegrees), heading: heading)
            mapView.setCamera(camera, withDuration: (immediately ? 0 : 0.5), animationTimingFunction: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading
        
        if let lastLocation = self.lastLocation {
            let previousAltitude = mapView.camera.altitude
            let camera = MGLMapCamera(lookingAtCenter: lastLocation.coordinate, fromDistance: previousAltitude,
                                      pitch: CGFloat(ViewController.kMapPitchDegrees), heading: newHeading.magneticHeading)
            mapView.setCamera(camera, animated: true)
        }
        
    }
    
    func shouldUpdateLocation(newLocation: CLLocation) -> (Bool, Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if let lastLocation = self.lastLocation {
            
            // accept an inaccurate location only if the last one received is older than 10 seconds
            if newLocation.horizontalAccuracy > 65.0 && abs(lastLocation.timestamp.timeIntervalSinceNow) <= 10.0 {
                return (false, false)
            }
            
            let newTimestamp = newLocation.timestamp.timeIntervalSince1970
            let oldTimestamp = lastLocation.timestamp.timeIntervalSince1970
            if newTimestamp > oldTimestamp + 5.0 {
                if newLocation.distance(from: lastLocation) > 18.0 {
                    self.lastLocation = newLocation
                    
                    if newTimestamp - oldTimestamp > 60 {
                        return (true, true) // significant distance, long time since last update
                    }
                    else {
                        return (true, false) // significant distance
                    }
                }
                else {
                    return (false, false) // insignificant change
                }
            }
            else {
                return (false, false) // too soon
            }
        }
        else {
            self.lastLocation = newLocation // first location
            return (true, true)
        }
    }
    
    // MARK: MGLMapViewDelegate
    
    func mapViewRegionIsChanging(_ mapView: MGLMapView) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // update coordinate of map
        centerCoordinate = mapView.centerCoordinate
    }
    
    // MARK: SCNSceneRendererDelegate

    // convert geographic coordinates to screen coordinates in the map view
    func coordinateToOverlayPosition(coordinate: CLLocationCoordinate2D) -> SCNVector3 {
        let p: CGPoint = mapView.convert(coordinate, toPointTo: mapView)
        return SCNVector3Make(Float(p.x), Float(sceneRect.size.height - p.y), 0)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // if we don't have a map yet, we have no idea what to do
        if centerCoordinate == nil || lastLocation == nil {
            return
        }
        
        // calculate elapsed time since rendering started
        if renderStartTime == nil {
            renderStartTime = time - (1.0/60.0)
        }
        
        // parameters for rotation (objects rotate every 2 seconds)
        let dt = Float(time - renderStartTime!)
        let rotationSpeed = Float.pi
        
        // get pitch of map
        let mapPitchRads = Float(mapView.camera.pitch) * (Float.pi / 180.0)
        
        // update player
        let playerPoint = coordinateToOverlayPosition(coordinate: lastLocation!.coordinate)
        let scaleMat = SCNMatrix4MakeScale(4.0, 4.0, 4.0)
        playerNode.transform = SCNMatrix4Mult(scaleMat,
                                              SCNMatrix4Mult(SCNMatrix4MakeRotation(-mapPitchRads, 1, 0, 0),
                                                             SCNMatrix4MakeTranslation(playerPoint.x, playerPoint.y, 0)))
        
        // update office
        let officePoint = coordinateToOverlayPosition(coordinate: officeNode.value(forKey: "coordinate") as! CLLocationCoordinate2D)
        officeNode.transform =
            SCNMatrix4Mult(SCNMatrix4MakeRotation(dt*rotationSpeed, 0, 1, 0),
                           SCNMatrix4Mult(SCNMatrix4MakeRotation(mapPitchRads, 1, 0, 0),
                                          SCNMatrix4MakeTranslation(officePoint.x, officePoint.y, 0)))
        let nodeTapped = officeNode.value(forKey: "tapped") as! Bool
        officeNode.geometry?.firstMaterial?.diffuse.contents = nodeTapped ? UIColor.red : UIColor.white
        
        // update light position
        omniLightNode.position = SCNVector3Make(playerPoint.x, playerPoint.y + 30, 20) // magic number alert!
        
        // update camera
        let metersPerPoint = mapView.metersPerPoint(atLatitude: centerCoordinate!.latitude)
        let altitudePoints = mapView.camera.altitude / metersPerPoint
        let projMat = GLKMatrix4MakeOrtho(0, Float(sceneRect.size.width),  // left, right
            0, Float(sceneRect.size.height), // bottom, top
            1, Float(altitudePoints+100))               // zNear, zFar
        cameraNode.position = SCNVector3Make(0, 0, Float(altitudePoints))
        cameraNode.camera!.projectionTransform = SCNMatrix4FromGLKMatrix4(projMat)
    }
    
    // MARK: User input handling
    
    func onMapViewTapped(recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(point, options: [SCNHitTestOption.firstFoundOnly : true])
        if hitTestResults.count > 0 {
            let node = hitTestResults.first!.node
            if node == officeNode {
                officeNode.setValue(true, forKey: "tapped")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    self.officeNode.setValue(false, forKey: "tapped")
                })
            }
        }
    }
}

