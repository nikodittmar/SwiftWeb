//
//  PostgresDecoder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public class PostgresDecoder {
    public func decode<T : Decodable>(_ type: T.Type, from row: PostgresRandomAccessRow) throws -> T {
        return try T(from: PostgresDecoderImpl(row: row))
    }
}

private class PostgresDecoderImpl: Decoder {
    var codingPath: [any CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let row: PostgresRandomAccessRow
    
    init(row: PostgresRandomAccessRow) {
        self.row = row
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(row: row))
    }
    
    private struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let row: PostgresRandomAccessRow
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let type = T.self as? any PostgresDecodable.Type else {
                throw PostgresDecoderError.typeNotSupported(T.self)
            }
            guard let result = try self._decode(type, forKey: key) as? T else {
                throw PostgresDecoderError.typeNotSupported(T.self)
            }
            return result
        }
        
        func _decode<T: PostgresDecodable>(_ type: T.Type, forKey key: Key) throws -> T {
            guard self.contains(key) else {
                throw PostgresDecoderError.keyNotFound(key: key.stringValue)
            }
            do {
                return try row[key.stringValue].decode(T.self)
            } catch {
                throw PostgresDecoderError.decodingError(underlying: error)
            }
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { throw PostgresDecoderError.typeNotSupported(UInt64.self) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { throw PostgresDecoderError.typeNotSupported(UInt32.self) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { throw PostgresDecoderError.typeNotSupported(UInt16.self) }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try self._decode(type, forKey: key) }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { throw PostgresDecoderError.typeNotSupported(UInt.self) }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try self._decode(type, forKey: key) }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try self._decode(type, forKey: key) }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try self._decode(type, forKey: key) }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { throw PostgresDecoderError.typeNotSupported(Int8.self) }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try self._decode(type, forKey: key) }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try self._decode(type, forKey: key) }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try self._decode(type, forKey: key) }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { try self._decode(type, forKey: key) }
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try self._decode(type, forKey: key) }
        
        var codingPath: [any CodingKey] = []
        
        var allKeys: [Key] = []
        
        func contains(_ key: Key) -> Bool {
            row.contains(key.stringValue)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            guard self.contains(key) else {
                throw PostgresDecoderError.keyNotFound(key: key.stringValue)
            }
            return row[key.stringValue].bytes == nil
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            throw PostgresDecoderError.notSupported
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw PostgresDecoderError.notSupported
        }
        
        func superDecoder() throws -> any Decoder {
            throw PostgresDecoderError.notSupported
        }
        
        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw PostgresDecoderError.notSupported
        }
    }
    
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw PostgresDecoderError.notSupported
    }
    
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw PostgresDecoderError.notSupported
    }
}

enum PostgresDecoderError: Error {
    case keyNotFound(key: String)
    case typeNotSupported(Any.Type)
    case notSupported
    case decodingError(underlying: Error)
}

