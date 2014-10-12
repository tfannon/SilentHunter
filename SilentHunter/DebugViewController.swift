//
//  ViewController.swift
//  SilentHunter
//
//  Created by Tommy Fannon on 10/11/14.
//  Copyright (c) 2014 Crazy8Dev. All rights reserved.
//

import UIKit

class DebugViewController: UIViewController, UITextFieldDelegate
{
    
    @IBOutlet var lblSession: UITextField!
    @IBOutlet var serverOverride: UISwitch!
    
    @IBOutlet var locationOverride: UISwitch!
    @IBOutlet var txtLatitude: UITextField!
    @IBOutlet var txtLongitude: UITextField!
    
    @IBAction func handleServerOverride(sender: UISwitch) {
        gSettings.serverOverride = sender.on
        gSettings.persist()
    }
    
    @IBAction func handleSessionNameChanged(sender: UITextField) {
        gSettings.sessionName = sender.text
        gSettings.persist()
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        lblSession.resignFirstResponder()
        return true
    }
    
    @IBAction func handleLatitudeChange(sender: UITextField) {
        gSettings.latitude = txtLatitude.text.toDouble()!
        gSettings.persist()
    }
    
    @IBAction func handleLongitudeChange(sender: UITextField) {
        gSettings.longitude = txtLongitude.text.toDouble()!
        gSettings.persist()
    }
    
    //MARK:  controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        edgeSwipe.edges = UIRectEdge.Left
        self.view.addGestureRecognizer(edgeSwipe)
        
        var swipe = UISwipeGestureRecognizer(target: self, action: "respondToSwipeGesture:")
        swipe.direction = .Down
        view.addGestureRecognizer(swipe)
        
        lblSession.delegate = self
        txtLatitude.delegate = self
        txtLongitude.delegate = self

        serverOverride.on = gSettings.serverOverride
        lblSession.text = gSettings.sessionName
        locationOverride.on = gSettings.locationOverride
        txtLatitude.text = "\(gSettings.latitude)"
        txtLongitude.text = "\(gSettings.longitude)"
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

