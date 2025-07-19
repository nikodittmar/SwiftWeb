//
//  PostgresDecoder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/18/25.
//

import PostgresNIO
import Foundation

internal class PostgresEncoder {
    internal func encode<T : Encodable>(_ value: T) throws -> [String: PostgresEncodable] {
        let encoder = _PostgresEncoder()
        try value.encode(to: encoder)
        return encoder.row
    }
}

private class _PostgresEncoder: Encoder {
    var codingPath: [any CodingKey] = []

    var userInfo: [CodingUserInfoKey : Any] = [:]

    var row: [String: PostgresEncodable] = [:]

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(PostgresKeyedEncodingContainer<Key>(encoder: self))
    }

    private struct PostgresKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: _PostgresEncoder
        var codingPath: [any CodingKey] { self.encoder.codingPath }

        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            switch value {
                case let pgEncodable as PostgresEncodable:
                    self.encoder.row[key.stringValue] = pgEncodable
                case let array as [any Encodable]:
                    let jsonStrings = try array.map { value in
                        let jsonData = try JSONEncoder().encode(value)
                        guard let jsonString =  String(data: jsonData, encoding: .utf8) else {
                            throw PostgresEncoderError.typeNotSupported(T.self)
                        }
                        return jsonString
                    }
                    self.encoder.row[key.stringValue] = jsonStrings
                default:
                    self.encoder.row[key.stringValue] = try JSONEncoder().encode(value)
            }
        }

        mutating func encode(_ value: UInt64, forKey key: Key) throws { throw PostgresEncoderError.typeNotSupported(UInt64.self) }
        mutating func encode(_ value: UInt32, forKey key: Key) throws { throw PostgresEncoderError.typeNotSupported(UInt32.self) }
        mutating func encode(_ value: UInt16, forKey key: Key) throws { throw PostgresEncoderError.typeNotSupported(UInt16.self) }
        mutating func encode(_ value: UInt8, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: UInt, forKey key: Key) throws { throw PostgresEncoderError.typeNotSupported(UInt.self) }
        mutating func encode(_ value: Int64, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Int32, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Int16, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Int8, forKey key: Key) throws { throw PostgresEncoderError.typeNotSupported(Int8.self) }
        mutating func encode(_ value: Int, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Float, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Double, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: String, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }
        mutating func encode(_ value: Bool, forKey key: Key) throws { self.encoder.row[key.stringValue] = value }

        mutating func encodeNil(forKey key: Key) throws { self.encoder.row[key.stringValue] = nil }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError("Nested keyed encoding is not supported.")
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            fatalError("Nested unkeyed encoding is not supported.")
        }

        mutating func superEncoder() -> any Encoder {
            fatalError("Superclass encoding is not supported.")
        }

        mutating func superEncoder(forKey key: Key) -> any Encoder {
            fatalError("Superclass encoding is not supported.")
        }
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        fatalError(" encoding is not supported.")
    }



    func singleValueContainer() -> any SingleValueEncodingContainer {
        fatalError("Unimplemented!")
    }
}

public enum PostgresEncoderError: Error {
    case typeNotSupported(Any.Type)
    case notSupported
}
