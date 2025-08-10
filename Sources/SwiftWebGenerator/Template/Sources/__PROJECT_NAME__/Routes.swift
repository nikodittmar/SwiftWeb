import SwiftWeb

/// This function is called on startup to register all of your application's routes.
func routes() -> Router {
    let router = RouterBuilder()
    
    // -------------------------------------------------------
    //  Add your routes here.
    //
    //  Examples:
    //  router.get("/", to: UsersController().index)
    //  router.resources("/posts", for: PostsController.self)
    // -------------------------------------------------------
    
    router.get("/", to: HelloController().hello)
    
    return router.build()
}
