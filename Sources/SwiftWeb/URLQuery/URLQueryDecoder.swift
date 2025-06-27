//
//  URLQueryDecoder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/22/25.
//
import Foundation

public struct URLQueryDecoder {
    public static func decode<T : Decodable>(_ type: T.Type, from query: String) throws -> T {
        let queryItems = try URLQueryParser.parse(query, mode: .encodedForm)
        let unflattenedQueryItems = try URLQueryUnflattener.unflatten(queryItems)
        
        return try T(from: _URLQueryDecoder(query: unflattenedQueryItems))
    }
    
    public func decode<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let query = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "The given data was not a valid UTF-8 string."
                )
            )
        }
        return try URLQueryDecoder.decode(type, from: query)
    }
}

private enum URLQueryData {
    case singleValue(String)
    case keyed([String:URLQueryNode])
    case unkeyed([URLQueryNode])
}

private class _URLQueryDecoder: Decoder {
    var codingPath: [any CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let queryData: URLQueryData
    
    init(query: [String:URLQueryNode], codingPath: [any CodingKey] = []) {
        self.queryData = .keyed(query)
        self.codingPath = codingPath
    }
    
    init(query: [URLQueryNode], codingPath: [any CodingKey] = []) {
        self.queryData = .unkeyed(query)
        self.codingPath = codingPath
    }
    
    init(query: String, codingPath: [any CodingKey] = []) {
        self.queryData = .singleValue(query)
        self.codingPath = codingPath
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard case let .keyed(dict) = self.queryData else {
            throw DecodingError.typeMismatch([String: URLQueryNode].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode a dictionary but found \(self.queryData) instead."))
        }
        let container = URLQueryKeyedDecodingContainer<Key>(values: dict, codingPath: self.codingPath)
        return KeyedDecodingContainer(container)
    }
    
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard case let .unkeyed(array) = self.queryData else {
            throw DecodingError.typeMismatch([URLQueryNode].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode an array but found \(self.queryData) instead."))
        }
        return URLQueryUnkeyedDecodingContainer(values: array, codingPath: self.codingPath)
    }
        
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        guard case let .singleValue(string) = self.queryData else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode a single value but found \(self.queryData) instead."))
        }
        return URLQuerySingleValueDecodingContainer(value: string, codingPath: self.codingPath)
    }
    
    private struct URLQueryKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let values: [String:URLQueryNode]
        
        var codingPath: [any CodingKey]
        
        var allKeys: [Key]
        
        init(values: [String : URLQueryNode], codingPath: [any CodingKey]) {
            self.values = values
            self.codingPath = codingPath
            self.allKeys = values.keys.compactMap({ Key(stringValue: $0) })
        }
        
        private func getSingleValue(forKey key: CodingKey) throws -> String {
            guard let node = self.values[key.stringValue], case let .singleValue(value) = node else {
                throw DecodingError.keyNotFound(key, DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Could not find single value for key \(key)"
                ))
            }
            return value
        }
        
        private func _decode<T: LosslessStringConvertible>(_ type: T.Type, forKey key: Key) throws -> T {
            let stringValue = try self.getSingleValue(forKey: key)

            guard let value = T(stringValue) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "The string \"\(stringValue)\" is not convertible to \(type)."
                    )
                )
            }

            return value
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let node = self.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Key \(key) not found."))
            }

            let decoder: _URLQueryDecoder
            switch node {
            case  .keyed(let dict):
                decoder = _URLQueryDecoder(query: dict, codingPath: self.codingPath + [key])
            case .unkeyed(let array):
                decoder = _URLQueryDecoder(query: array, codingPath: self.codingPath + [key])
            case .singleValue(let str):
                decoder = _URLQueryDecoder(query: str, codingPath: self.codingPath + [key])
            }
            return try T(from: decoder)
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try self._decode(type, forKey: key) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try self._decode(type, forKey: key) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try self._decode(type, forKey: key) }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try self._decode(type, forKey: key) }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try self._decode(type, forKey: key) }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try self._decode(type, forKey: key) }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try self._decode(type, forKey: key) }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try self._decode(type, forKey: key) }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try self._decode(type, forKey: key) }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try self._decode(type, forKey: key) }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try self._decode(type, forKey: key) }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try self._decode(type, forKey: key) }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { try self._decode(type, forKey: key) }
        
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            let stringValue = try self.getSingleValue(forKey: key).lowercased()
                
            if stringValue == "true" || stringValue == "1" || stringValue == "" {
                return true
            } else if stringValue == "false" || stringValue == "0" {
                return false
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Invalid boolean value: could not decode \"\(stringValue)\"."
                    )
                )
            }
        }
        
        func contains(_ key: Key) -> Bool {
            self.values[key.stringValue] != nil
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            // No representation for nil in URL query strings
            return false
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            guard let node = self.values[key.stringValue], case let .keyed(dict) = node else {
                throw DecodingError.keyNotFound(
                    key,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Nested container not found for key \(key).")
                )
            }
            let container = URLQueryKeyedDecodingContainer<NestedKey>(values: dict, codingPath: self.codingPath + [key])
            return KeyedDecodingContainer(container)
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            guard let node = self.values[key.stringValue], case let .unkeyed(array) = node else {
                throw DecodingError.keyNotFound(
                    key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Nested unkeyed container for key \(key).")
                )
            }
            return URLQueryUnkeyedDecodingContainer(values: array, codingPath: self.codingPath + [key])
        }
        
        func superDecoder() throws -> any Decoder {
            throw URLQueryDecoderError.notSupported
        }
        
        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw URLQueryDecoderError.notSupported
        }
    }
    
    private struct URLQueryUnkeyedDecodingContainer: UnkeyedDecodingContainer {
        var values: [URLQueryNode]
        
        var codingPath: [any CodingKey]
        
        var count: Int? {
            return self.values.count
        }
        
        var isAtEnd: Bool {
            return self.currentIndex >= self.values.count
        }
        
        var currentIndex: Int
        
        init(values: [URLQueryNode], codingPath: [CodingKey]) {
            self.values = values
            self.codingPath = codingPath
            self.currentIndex = 0
        }
        
        private func getCurrentValue() throws -> String {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unkeyed container is at an end.")
                )
            }
            
            guard case let .singleValue(value) = self.values[self.currentIndex] else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Could not find single value for index \(self.currentIndex)")
                )
            }
            return value
        }
        
        private mutating func _decode<T: LosslessStringConvertible>(_ type: T.Type) throws -> T {
            let stringValue = try self.getCurrentValue()

            guard let value = T(stringValue) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "The string \"\(stringValue)\" is not convertible to \(type)."
                    )
                )
            }

            self.currentIndex += 1
            return value
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unkeyed container is at an end.")
                )
            }
            
            let decoder: _URLQueryDecoder
            let node = self.values[currentIndex]
            
            switch node {
            case  .keyed(let dict):
                decoder = _URLQueryDecoder(query: dict, codingPath: self.codingPath)
            case .unkeyed(let array):
                decoder = _URLQueryDecoder(query: array, codingPath: self.codingPath)
            case .singleValue(let str):
                decoder = _URLQueryDecoder(query: str, codingPath: self.codingPath)
            }
            
            self.currentIndex += 1
            return try T(from: decoder)
        }
    
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 { return try self._decode(type) }
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 { return try self._decode(type) }
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 { return try self._decode(type) }
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 { return try self._decode(type) }
        mutating func decode(_ type: UInt.Type) throws -> UInt { return try self._decode(type) }
        mutating func decode(_ type: Int64.Type) throws -> Int64 { return try self._decode(type) }
        mutating func decode(_ type: Int32.Type) throws -> Int32 { return try self._decode(type) }
        mutating func decode(_ type: Int16.Type) throws -> Int16 { return try self._decode(type) }
        mutating func decode(_ type: Int8.Type) throws -> Int8 { return try self._decode(type) }
        mutating func decode(_ type: Int.Type) throws -> Int { return try self._decode(type) }
        mutating func decode(_ type: Float.Type) throws -> Float { return try self._decode(type) }
        mutating func decode(_ type: Double.Type) throws -> Double { return try self._decode(type) }
        mutating func decode(_ type: String.Type) throws -> String { return try self._decode(type) }
        
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let stringValue = try getCurrentValue().lowercased()
                
            if stringValue == "true" || stringValue == "1" {
                self.currentIndex += 1
                return true
            } else if stringValue == "false" || stringValue == "0" {
                self.currentIndex += 1
                return false
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Invalid boolean value: could not decode \"\(stringValue)\"."
                    )
                )
            }
        }
        
        mutating func decodeNil() throws -> Bool {
            // No representation for nil in URL query strings
            return false
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unkeyed container is at an end.")
                )
            }
            guard case let .keyed(dict) = self.values[self.currentIndex] else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Nested container not found for index \(self.currentIndex).")
                )
            }
            self.currentIndex += 1
            let container = URLQueryKeyedDecodingContainer<NestedKey>(values: dict, codingPath: self.codingPath)
            return KeyedDecodingContainer(container)
        }
        
        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unkeyed container is at an end.")
                )
            }
            guard case let .unkeyed(array) = self.values[self.currentIndex] else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: self.codingPath, debugDescription: "Nested unkeyed container for index \(self.currentIndex).")
                )
            }
            self.currentIndex += 1
            return URLQueryUnkeyedDecodingContainer(values: array, codingPath: self.codingPath)
        }
        
        mutating func superDecoder() throws -> any Decoder {
            throw URLQueryDecoderError.notSupported
        }
    }
    
    private struct URLQuerySingleValueDecodingContainer: SingleValueDecodingContainer {
        var codingPath: [any CodingKey]
        var value: String
        
        init(value: String, codingPath: [any CodingKey]) {
            self.codingPath = codingPath
            self.value = value
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            if let stringConvertible = type as? LosslessStringConvertible.Type {
                guard let value = stringConvertible.init(self.value) as? T else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: self.codingPath, debugDescription: "The string \"\(self.value)\" is not convertible to \(type).")
                    )
                }
                
                return value
            } else {
                let decoder = _URLQueryDecoder(query: self.value, codingPath: self.codingPath)
                return try T(from: decoder)
            }
        }
        
        private func _decode<T: LosslessStringConvertible>(_ type: T.Type) throws -> T {
            guard let value = T(self.value) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "The string \"\(self.value)\" is not convertible to \(type)."
                    )
                )
            }

            return value
        }
        
        func decode(_ type: UInt64.Type) throws -> UInt64 { try self._decode(type) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try self._decode(type) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try self._decode(type) }
        func decode(_ type: UInt8.Type) throws -> UInt8 { try self._decode(type) }
        func decode(_ type: UInt.Type) throws -> UInt { try self._decode(type) }
        func decode(_ type: Int64.Type) throws -> Int64 { try self._decode(type) }
        func decode(_ type: Int32.Type) throws -> Int32 { try self._decode(type) }
        func decode(_ type: Int16.Type) throws -> Int16 { try self._decode(type) }
        func decode(_ type: Int8.Type) throws -> Int8 { try self._decode(type) }
        func decode(_ type: Int.Type) throws -> Int { try self._decode(type) }
        func decode(_ type: Float.Type) throws -> Float { try self._decode(type) }
        func decode(_ type: Double.Type) throws -> Double { try self._decode(type) }
        func decode(_ type: String.Type) throws -> String { try self._decode(type) }
        
        func decode(_ type: Bool.Type) throws -> Bool {
            let stringValue = self.value.lowercased()
            
            if stringValue == "true" || stringValue == "1" {
                return true
            } else if stringValue == "false" || stringValue == "0" {
                return false
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Invalid boolean value: could not decode \"\(stringValue)\"."
                    )
                )
            }
        }
                
        func decodeNil() -> Bool {
            // No representation for nil in URL query strings
            return false
        }
    }
}

enum URLQueryDecoderError: Error {
    case notSupported
    case typeMismatch
}
