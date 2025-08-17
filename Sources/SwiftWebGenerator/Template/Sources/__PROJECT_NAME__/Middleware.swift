import SwiftWeb

/// This function is called on startup to register your application's global middleware.
func middleware() -> [Middleware] {

    // -------------------------------------------------------------------------
    //  Default Middleware Stack
    //
    //  Middleware is executed in an "onion" pattern. The request travels
    //  through the stack in the order it's defined here (first-to-last),
    //  and the response travels back out in the reverse order. 
    //  
    //  You can remove, reorder, or add new middleware to fit your needs.
    // -------------------------------------------------------------------------
    return [
        // Serves files from the project's "Public" directory. Must run first
        // to ensure assets are served quickly without hitting other middleware.
        StaticFileMiddleware(),

        // Logs incoming requests and their corresponding responses.
        LoggingMiddleware(),

        // Manages user sessions via secure cookies. Required for CSRF protection.
        SessionsMiddleware(),

        // Protects against Cross-Site Request Forgery attacks by validating a
        // unique token on all non-GET requests.
        CSRFMiddleware(),
    ]
}