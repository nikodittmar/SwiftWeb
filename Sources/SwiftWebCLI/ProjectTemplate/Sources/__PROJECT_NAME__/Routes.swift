import SwiftWeb

/// This function is called on startup to register all of your application's routes.
func routes() -> Router {
    let router = RouterBuilder()
    
    // -------------------------------------------
    //  Add your routes here.
    //
    //  Examples:
    //  router.get("/", to: UserController().welcome)
    //  router.resources("/posts", for: PostController.self)
    // -------------------------------------------
    
    router.get("/", to: HelloController().welcome)
    
    return router.build()
}
