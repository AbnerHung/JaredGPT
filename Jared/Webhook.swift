//
//  File.swift
//  Jared
//
//  Created by Zeke Snider on 8/16/20.
//  Copyright © 2020 Zeke Snider. All rights reserved.
//

import Foundation
import JaredFramework

struct Webhook: Decodable {
    var url: String
    var routes: [Route]?
}
