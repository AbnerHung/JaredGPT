//
//  main.swift
//  EmoteModule
//
//  Created by Zeke Snider on 4/16/16.
//  Copyright © 2016 Zeke Snider. All rights reserved.
//

import Foundation
import JaredFramework

public class EmoteModule: RoutingModule {
    public var routes: [Route] = []
    public var description = "A Description"

    required public init() {
        let aRoute = Route(name: "test function", comparisons: [.startsWith: ["/moduletest"]], call: self.test, description: "TEST")
        routes = [aRoute]
    }
    
    public func test(message: Message) -> Void {
        Jared.Send("This command was loaded from a modularized bundle.", to: message.RespondTo())
    }
}


