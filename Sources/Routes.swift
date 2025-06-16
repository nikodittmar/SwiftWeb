//
//  Routes.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

struct HelloController: Controller {
    
}

func configureRoutes(_ router: Router) {
    router.resources("/users", for: HelloController.self) { router in
        router.resources("/posts", for: HelloController.self, parameter: ":post_id")
    }
}
