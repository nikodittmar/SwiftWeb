//
//  PostsController.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/18/25.
//

struct PostsController: Controller {
    func index(req: Request) -> Response {
        return .json("{ 'Hello': 'World' }")
    }
}
