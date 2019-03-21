//
//  ViewController.swift
//  LettuceExamples
//
//  Created by Aly Yakan on 3/20/19.
//  Copyright © 2019 Instabug. All rights reserved.
//

import UIKit
import Lettuce

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        NetworkCapturer.shared.baseURL = "lol"
    }


}

