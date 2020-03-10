//
//  SimpleTwoWayBindingTests.swift
//  SimpleTwoWayBindingExampleTests
//
//  Created by Ryan Forsythe on 3/4/20.
//  Copyright © 2020 Ryan Forsythe. All rights reserved.
//

@testable import SimpleTwoWayBinding
import XCTest

class SimpleTwoWayBindingTests: XCTestCase {
    func testBasicBind() {
        let o = Observable<String>()
        var i = 0
        _ = o.bind(replay: false) {
            i = 1
            XCTAssertEqual("foo", $0)
        }
        o.value = "foo"
        XCTAssertEqual(i, 1)
    }
    
    func testBasicUnbind() {
        let o = Observable<String>()
        let ro = o.bind {
            XCTAssertEqual(3, $0.count)
        }
        o.value = "foo"
        o.unbind(ro)
        o.value = "foobar"
    }

    func testMap() {
        let o = Observable<String>()
        var oBindingFired = false
        _ = o.bind {
            oBindingFired = true
            XCTAssertEqual("b", $0.first)
        }
        var p: Observable<Int>? = o.map { $0.count }
        var pBindingFired = false
        var rp = p?.bind {
            pBindingFired = true
            XCTAssertEqual(3, $0)
        }
        o.value = "bar"
        XCTAssert(oBindingFired)
        XCTAssert(pBindingFired)
        
        // Delete the mapped observable
        p = nil
        // Unbind from the mapped property
        rp = nil
        
        oBindingFired = false
        pBindingFired = false
        o.value = "boom" // Would cause a failure in the p binding if it were still active
        XCTAssert(oBindingFired)
        XCTAssertFalse(pBindingFired)
    }
    
    func testDeepMap() {
        let o: Observable<String> = Observable()
        var oBindingFired = false

        _ = o.bind {
            oBindingFired = true
            XCTAssertEqual("b", $0.first)
        }
        enum DeepMapError: Error {
            case badMap
        }
        
        var p: Observable<Result<String, DeepMapError>>? = o
            .map { $0.count }
            .map { $0 == 3 }
            .map { $0 ? .success("Three") : .failure(.badMap) }
        
        var pBindingFired = false
        var rp = p?.bind { result in
            pBindingFired = true
            switch result {
            case .success(let s): XCTAssertEqual("Three", s)
            case .failure: XCTFail()
            }
        }
        
        o.value = "boo"
        XCTAssert(pBindingFired)
        
        p = nil
        rp = nil
        
        oBindingFired = false
        pBindingFired = false
        o.value = "boom"
        XCTAssert(oBindingFired)
        XCTAssertFalse(pBindingFired)
    }
    
    func testDeepInterruptedMap() {
        let o: Observable<String> = Observable()
        _ = o.bind {
            XCTAssertEqual("b", $0.first)
        }
        enum DeepMapError: Error {
            case badMap
        }
        var p: Observable<Int>? = o
            .map { $0.count }
        var q: Observable<Bool>? = p?
            .map { $0 == 3 }
        let v: Observable<Result<String, DeepMapError>>? = q?
            .map { $0 ? .success("Three") : .failure(.badMap) }
        
        var pBindingFired = false
        _ = v?.bind { result in
            pBindingFired = true
            switch result {
            case .success(let s): XCTAssertEqual("Three", s)
            case .failure: XCTFail()
            }
        }
        
        // If we knock out the middle of the chain, the chain should still be functional
        p = nil
        q = nil
        pBindingFired = false
        o.value = "bee"
        XCTAssert(pBindingFired)
    }
    
    func testReplay() {
        let o: Observable<String> = Observable()
        var expectation: String?
        var bindFired = false
        let bindingFunction: (String) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        _ = o.bind(replay: true, bindingFunction)
        XCTAssertFalse(bindFired)
        expectation = "foo"
        o.value = "foo"
        XCTAssertTrue(bindFired)
        
        let p: Observable<String> = Observable()
        p.value = "foo"
        bindFired = false
        _ = p.bind(bindingFunction)
        XCTAssertTrue(bindFired)
        expectation = "bar"
        p.value = "bar"
        XCTAssertTrue(bindFired)
    }
    
    func testSimpleFilter() {
        let o: Observable<String> = Observable()
        let fo = o.filter { $0.count == 3 }
                
        var bindFired = false
        var expectation: String?
        let bindingFunction: (String) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        
        _ = fo.bind(bindingFunction)
        expectation = "foo"
        o.value = "foo"
        XCTAssertTrue(bindFired)
        
        expectation = "this would cause a fail in the binding function"
        bindFired = false
        
        o.value = "foobar"
        XCTAssertFalse(bindFired)
    }
    
    func testDeepFilter() {
        let o: Observable<String> = Observable()
        let fo = o
            .filter { $0.count == 3 }
            .filter { $0.first == "f" }
            .filter { $0.last == "o" }

        var bindFired = false
        var expectation: String?
        let bindingFunction: (String) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        _ = fo.bind(bindingFunction)
        
        expectation = "foo"
        o.value = "foo"
        XCTAssertTrue(bindFired)
        
        expectation = "this would cause a fail in the binding function"
        bindFired = false
        o.value = "foobar"
        XCTAssertFalse(bindFired)
        
        expectation = "fro"
        bindFired = false
        o.value = "fro"
        XCTAssertTrue(bindFired)
    }
    
    func testReduce() {
        let o: Observable<String> = Observable()
        let ro = o
            .reduce(initial: "", +)
        
        var expectation: String?
        var bindFired = false
        let bindingFunction: (String) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        _ = ro.bind(bindingFunction)
        
        expectation = "f"
        o.value = "f"
        XCTAssertTrue(bindFired)
        
        expectation = "fo"
        o.value = "o"
        expectation = "foo"
        o.value = "o"
    }
    
    func testDeepReduce() {
        let o: Observable<String> = Observable()
        let ro = o
            .reduce(initial: "", +)
            .reduce(initial: 0, { $0 + $1.count })
        
        var expectation: Int?
        var bindFired = false
        let bindingFunction: (Int) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        _ = ro.bind(bindingFunction)
        
        expectation = 1
        o.value = "f"
        XCTAssertTrue(bindFired)
        
        expectation = 3
        o.value = "o"
        expectation = 6
        o.value = "o"
    }
    
    func testZip() {
        let o: Observable<String> = Observable()
        var p: Observable<Int>? = Observable()
        let op = zip(o, p!)
        
        var expectation: (String?, Int?) = (nil, nil)
        var bindFired = false
        let bindingFunction: ((String?, Int?)) -> Void = {
            bindFired = true
            XCTAssertEqual($0.0, expectation.0)
            XCTAssertEqual($0.1, expectation.1)
        }
        _ = op.bind(bindingFunction)
        
        expectation = ("foo", nil)
        o.value = "foo"
        XCTAssertTrue(bindFired)
        
        expectation = ("foo", 42)
        p?.value = 42
        expectation = ("bar", 42)
        o.value = "bar"
        
        p = nil
        bindFired = false
        expectation = ("baz", 42)
        o.value = "baz"
        XCTAssert(bindFired)
    }
    
    func testDistinct() {
        let o: Observable<String> = Observable()
        let uo = o.distinct()
        
        var bindFired = false
        var expectation: String?
        let bindingFunction: (String) -> Void = {
            bindFired = true
            XCTAssertEqual($0, expectation)
        }
        _ = uo.bind(bindingFunction)
        
        expectation = "foo"
        o.value = "foo"
        XCTAssert(bindFired)
        bindFired = false
        o.value = "foo"
        XCTAssertFalse(bindFired)
        expectation = "bar"
        o.value = "bar"
        XCTAssert(bindFired)
    }
}