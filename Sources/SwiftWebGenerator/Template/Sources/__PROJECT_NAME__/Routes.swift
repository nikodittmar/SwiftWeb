import SwiftWeb

/// This function is called on startup to register all of your application's routes.
func routes(_ routes: RouterBuilder) -> Router {
    
    // -------------------------------------------------------
    //  Add your routes here.
    //
    //  Examples:
    //  routes.get("/", to: UsersController().index)
    //  routes.resources("/posts", for: PostsController.self)
    // -------------------------------------------------------
    
    routes.get("/", to: HelloController().hello)
    
    return routes.build()
}
