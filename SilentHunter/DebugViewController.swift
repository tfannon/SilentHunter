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
    @IBOutlet weak var lblMsgs: UILabel!
    
    @IBOutlet var locationOverride: UISwitch!
    @IBOutlet var txtLatitude: UITextField!
    @IBOutlet var txtLongitude: UITextField!
    
    @IBOutlet weak var stepLogMsgs: UIStepper!
    @IBAction func stepLogMsgs(sender: UIStepper) {
        gSettings.maxLogMsgs = Int(sender.value)
        lblMsgs.text = String(gSettings.maxLogMsgs)
        gSettings.persist()
    }
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
        serverOverride.on = gSettings.serverOverride
        lblMsgs.text = String(gSettings.maxLogMsgs)
        stepLogMsgs.value = Double(gSettings.maxLogMsgs)
    }
    
    func respondToSwipeGesture(gesture: UIScreenEdgePanGestureRecognizer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

