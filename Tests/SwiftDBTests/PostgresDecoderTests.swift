//
//  PostgresDecoderTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import Testing
@testable import PostgresNIO
@testable import SwiftDB

func makeTestDataRow(_ buffers: ByteBuffer?...) -> DataRow {
    var bytes = ByteBuffer()
    buffers.forEach { column in
        switch column {
        case .none:
            bytes.writeInteger(Int32(-1))
        case .some(var input):
            bytes.writeInteger(Int32(input.readableBytes))
            bytes.writeBuffer(&input)
        }
    }
    
    return DataRow(columnCount: Int16(buffers.count), bytes: bytes)
}

@Suite struct PostgresDecoderTests {
    
    let decoder = PostgresDecoder()
    let row = PostgresRow(
        data: makeTestDataRow(ByteBuffer(integer: 5), ByteBuffer(string: "John Appleseed")),
        lookupTable: ["id": 0, "name": 1],
        columns: [
            RowDescription.Column(
                name: "id",
                tableOID: 1,
                columnAttributeNumber: 1,
                dataType: .int8,
                dataTypeSize: 0,
                dataTypeModifier: 0,
                format: .binary
            ),
            RowDescription.Column(
                name: "name",
                tableOID: 1,
                columnAttributeNumber: 1,
                dataType: .text,
                dataTypeSize: 0,
                dataTypeModifier: 0,
                format: .binary
            )
        ]
    )
    
    @Test func testDecode() {
        struct Person: Model {
            static let schema: String = "People"
            
            var id: Int?
            var name: String
        }
        
        let person = try? decoder.decode(Person.self, from: row.makeRandomAccess())
        #expect(person != nil)
        #expect(person?.id == 5)
        #expect(person?.name == "John Appleseed")
    }
    
    @Test func testMissingField() {
        struct Person: Model {
            static let schema: String = "People"
            
            var id: Int?
        }
        
        let person = try? decoder.decode(Person.self, from: row.makeRandomAccess())
        #expect(person != nil)
        #expect(person?.id == 5)
    }
    
    @Test func testExtraField() {
        struct Person: Model {
            static let schema: String = "People"
            
            var id: Int?
            var name: String
            var age: Int
        }

        let person = try? decoder.decode(Person.self, from: row.makeRandomAccess())
        #expect(person == nil)
    }
    
    @Test func testIncorrectType() {
        struct Person: Model {
            static let schema: String = "People"
            
            var id: Int?
            var name: Int
        }
        let person = try? decoder.decode(Person.self, from: row.makeRandomAccess())
        #expect(person == nil)
    }
    
    @Test func testDecodeNil() {
        struct Person: Model {
            static let schema: String = "People"
            
            var id: Int?
            var name: String
        }
        
        struct PersonOptional: Model {
            static let schema: String = "People"
            
            var id: Int?
            var name: String?
        }
        
        let rowWithNil = PostgresRow(
            data: makeTestDataRow(ByteBuffer(integer: 5), nil),
            lookupTable: ["id": 0, "name": 1],
            columns: [
                RowDescription.Column(
                    name: "id",
                    tableOID: 1,
                    columnAttributeNumber: 1,
                    dataType: .int8,
                    dataTypeSize: 0,
                    dataTypeModifier: 0,
                    format: .binary
                ),
                RowDescription.Column(
                    name: "name",
                    tableOID: 1,
                    columnAttributeNumber: 1,
                    dataType: .text,
                    dataTypeSize: 0,
                    dataTypeModifier: 0,
                    format: .binary
                )
            ]
        )
        
        let person = try? decoder.decode(Person.self, from: rowWithNil.makeRandomAccess())
        let personOptional = try? decoder.decode(PersonOptional.self, from: rowWithNil.makeRandomAccess())

        #expect(person == nil)
        #expect(personOptional != nil)
        #expect(personOptional?.name == nil)
        #expect(personOptional?.id == 5)
    }
}

