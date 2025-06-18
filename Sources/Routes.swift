//
//  Routes.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

func configureRoutes(_ router: RouterBuilder) {
    router.resources("/posts", for: PostsController.self)
}
