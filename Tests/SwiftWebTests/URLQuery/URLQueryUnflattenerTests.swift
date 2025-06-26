//
//  URLQueryUnflattenerTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/23/25.
//
import Testing
@testable import SwiftWeb

@Suite class URLQueryUnflattenerTests {
    @Test("Single value nodes")
    func test1() throws {
        let queryItems = [
            "foo":["bar"],
        ]
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .singleValue("bar"))
    }
    
    @Test("Unkeyed node")
    func test2() throws {
        let queryItems = [
            "foo[]":["bar","baz","quz"],
        ]
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .unkeyed([
            .singleValue("bar"),
            .singleValue("baz"),
            .singleValue("quz")
        ]))
    }

    @Test("Unkeyed node without bracket notation")
    func test3() throws {
        let queryItems = [
            "foo":["bar","baz","quz"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .unkeyed([
            .singleValue("bar"),
            .singleValue("baz"),
            .singleValue("quz")
        ]))
    }
    
    @Test("Nested unkeyed node within unkeyed node")
    func test4() throws {
        let queryItems = [
            "foo[0][]":["bar","baz","quz"],
            "foo[1][]":["swift","on","server"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .unkeyed([
            .unkeyed([
                .singleValue("bar"),
                .singleValue("baz"),
                .singleValue("quz")
            ]),
            .unkeyed([
                .singleValue("swift"),
                .singleValue("on"),
                .singleValue("server")
            ])
        ]))
    }
    
    @Test("Nested unkeyed node within unkeyed node without bracket notation")
    func test5() throws {
        let queryItems = [
            "foo[0]":["bar","baz","quz"],
            "foo[1]":["swift","on","server"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .unkeyed([
            .unkeyed([
                .singleValue("bar"),
                .singleValue("baz"),
                .singleValue("quz")
            ]),
            .unkeyed([
                .singleValue("swift"),
                .singleValue("on"),
                .singleValue("server")
            ])
        ]))
    }
    
    @Test("Invalid bracket notation")
    func test6() throws {
        let queryItems = [
            "foo[][]":["bar","baz","quz","swift","on","server"],
        ]
        
        #expect(throws: URLQueryUnflattenerError.invalidBrackets) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Keyed node")
    func test7() throws {
        let queryItems = [
            "foo[name]":["bar"],
            "foo[role]":["baz"]
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["foo"] == .keyed([
            "name":.singleValue("bar"),
            "role":.singleValue("baz")
        ]))
    }
    
    @Test("Nested keyed node")
    func test8() throws {
        let queryItems = [
            "scene[shape][name]":["bob"],
            "scene[shape][type]":["cube"]
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["scene"] == .keyed([
            "shape":.keyed([
                "name":.singleValue("bob"),
                "type":.singleValue("cube")
            ])
        ]))
    }
    
    @Test("Nested unkeyed node within keyed node")
    func test9() throws {
        let queryItems = [
            "scene[names][]":["bob", "alex"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["scene"] == .keyed([
            "names":.unkeyed([
                .singleValue("bob"),
                .singleValue("alex")
            ])
        ]))
    }
    
    @Test("Nested unkeyed node within keyed node without bracket notation")
    func test10() throws {
        let queryItems = [
            "scene[names]":["bob", "alex"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["scene"] == .keyed([
            "names":.unkeyed([
                .singleValue("bob"),
                .singleValue("alex")
            ])
        ]))
    }
    
    @Test("Doubly nested keyed node within nested unkeyed node within keyed node")
    func test11() throws {
        let queryItems = [
            "scene[shapes][0][name]":["bob"],
            "scene[shapes][0][type]":["cube"],
            "scene[shapes][1][name]":["alex"],
            "scene[shapes][1][type]":["sphere"]
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["scene"] == .keyed([
            "shapes":.unkeyed([
                .keyed([
                    "name":.singleValue("bob"),
                    "type":.singleValue("cube")
                ]),
                .keyed([
                    "name":.singleValue("alex"),
                    "type":.singleValue("sphere")
                ])
            ])
        ]))
    }
    
    @Test("Empty unkeyed node")
    func test12() throws {
        let queryItems = [
            "people[]":[""],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["people"] == .unkeyed([.singleValue("")]))
            
    }
    
    @Test("Empty single value node")
    func test13() throws {
        let queryItems = [
            "name":[""],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["name"] == .singleValue(""))
    }
    
    @Test("Empty keyed node")
    func test14() throws {
        let queryItems = [
            "author[name]":[""],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["author"] == .keyed(["name": .singleValue("")]))
    }
    
    @Test("Test empty")
    func test15() throws {
        let queryItems: [String:[String]] = [:]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res == [:])
    }
    
    @Test("Test single value and keyed type conflict")
    func test16() throws {
        let queryItems = [
            "author[name]":["Alex"],
            "author":["Alex"]
        ]
        
        #expect(throws: URLQueryUnflattenerError.typeConflict) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test single value and unkeyed type conflict")
    func test17() throws {
        let queryItems = [
            "author[]":["Alex"],
            "author":["Alex"]
        ]
        
        #expect(throws: URLQueryUnflattenerError.redeclaration) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test invalid redeclaration")
    func test18() throws {
        let queryItems = [
            "authors[]":["Paul", "Adam", "Jack"],
            "authors":["Alex", "Mike", "John"]
        ]
        
        #expect(throws: URLQueryUnflattenerError.redeclaration) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test keyed and unkeyed type conflict")
    func test19() throws {
        let queryItems = [
            "author[]":["Alex"],
            "author[name]":["Alex"]
        ]
        
        #expect(throws: URLQueryUnflattenerError.typeConflict) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test ordered keyed node")
    func test20() throws {
        let queryItems = [
            "authors[2]":["Alex"],
            "authors[0]":["John"],
            "authors[1]":["Mike"]
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["authors"] == .unkeyed([
            .singleValue("John"),
            .singleValue("Mike"),
            .singleValue("Alex")
        ]))
    }
    
    @Test("Test index and empty keyed node")
    func test21() throws {
        let queryItems = [
            "author[]":["Alex"],
            "author[1]":["Josh"]
        ]
        
        #expect(throws: URLQueryUnflattenerError.invalidIndex) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test invalid bracket order")
    func test22() throws {
        let queryItems = [
            "author][":["Alex", "John"],
        ]
        
        #expect(throws: URLQueryUnflattenerError.invalidBrackets) {
            try URLQueryUnflattener.unflatten(queryItems)
        }
    }
    
    @Test("Test combined example")
    func test23() throws {
        let queryItems = [
            "scene[1][name]" : ["albert"],
            "scene[1][type]" : ["cube"],
            "scene[0][name]" : ["bob"],
            "scene[0][type]" : ["prism"],
            "camera" : ["orthographic"],
            "lights[]" : ["directional", "point", "spot", "area"],
            "rendering_modes" : ["raytraced", "rasterized"],
        ]
        
        let res = try URLQueryUnflattener.unflatten(queryItems)
        #expect(res["scene"] == .unkeyed([
            .keyed([
                "name" : .singleValue("bob"),
                "type" : .singleValue("prism")
            ]),
            .keyed([
                "name" : .singleValue("albert"),
                "type" : .singleValue("cube")
            ])
        ]))
        #expect(res["camera"] == .singleValue("orthographic"))
        #expect(res["lights"] == .unkeyed([
            .singleValue("directional"),
            .singleValue("point"),
            .singleValue("spot"),
            .singleValue("area")
        ]))
        #expect(res["rendering_modes"] == .unkeyed([
            .singleValue("raytraced"),
            .singleValue("rasterized")
        ]))
    }
}
