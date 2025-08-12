//
//  SwiftWebError.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/11/25.
//

import NIOHTTP1

public struct SwiftWebError: Error, Sendable {
    
    public let type: SwiftWebErrorType
    
    public let reason: String

    public let message: String?
        
    public init(type: SwiftWebErrorType, reason: String, message: String? = nil) {
        self.type = type
        self.reason = reason
        self.message = message
    }

    public var context: SwiftWebErrorContext {
        let status = self.type.status
        return SwiftWebErrorContext(code: status.code, title: status.reasonPhrase, message: self.message ?? self.type.defaultMessage)
    }
}

public struct SwiftWebErrorContext: Encodable {
    public let code: UInt
    public let title: String
    public let message: String
}

public enum SwiftWebErrorType: Sendable {
    // Client Errors
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case methodNotAllowed
    case conflict
    case unprocessableEntity
    case tooManyRequests
    case preconditionFailed

    // Server Errors
    case internalServerError
    case serviceUnavailable

    public var status: HTTPResponseStatus {
        switch self {
        case .badRequest:           return .badRequest
        case .unauthorized:         return .unauthorized
        case .forbidden:            return .forbidden
        case .notFound:             return .notFound
        case .methodNotAllowed:     return .methodNotAllowed
        case .conflict:             return .conflict
        case .unprocessableEntity:  return .unprocessableEntity
        case .tooManyRequests:      return .tooManyRequests
        case .preconditionFailed:   return .preconditionFailed
        case .internalServerError:  return .internalServerError
        case .serviceUnavailable:   return .serviceUnavailable
        }
    }

    public var defaultMessage: String {
        switch self {
        // Client Errors
        case .badRequest:
            return "The request could not be understood or was missing required parameters. Please check your input."
        case .unauthorized:
            return "Authentication is required to access this resource. Please log in."
        case .forbidden:
            return "You do not have the necessary permissions to perform this action or access this resource."
        case .notFound:
            return "The page or resource you were looking for could not be found."
        case .methodNotAllowed:
            return "This action is not supported for the requested resource."
        case .conflict:
            return "The request could not be completed due to a conflict with the current state of the resource, such as a duplicate entry."
        case .unprocessableEntity:
            return "The request was well-formed but contained invalid data. Please review your submission."
        case .tooManyRequests:
            return "You have made too many requests in a short period. Please wait a moment before trying again."
        case .preconditionFailed:
            return "A precondition for the request failed. This often indicates a programmer error where an object was in an unexpected state."

        // Server Errors
        case .internalServerError:
            return "An unexpected error occurred on our end. Our team has been notified. Please try again later."
        case .serviceUnavailable:
            return "The service is temporarily unavailable, likely due to maintenance or high load. Please try again in a few minutes."
        }
    }
}