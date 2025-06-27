//
//  RequestDecoder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/26/25.
//
import Foundation

public protocol RequestDecoderProtocol {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: RequestDecoderProtocol {}
extension URLQueryDecoder: RequestDecoderProtocol {}

public enum RequestDecoder {
    public static func decoder(for contentType: String) -> RequestDecoderProtocol? {
        switch contentType {
        case let type where type.contains("application/json"):
            return JSONDecoder()
        case let type where type.contains("application/x-www-form-urlencoded"):
            return URLQueryDecoder()
        default:
            return nil
        }
    }
}
