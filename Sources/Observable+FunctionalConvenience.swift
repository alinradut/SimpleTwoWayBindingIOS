//
//  Observable+FunctionalConvenience.swift
//  Ride With GPS
//
//  Created by Ryan Forsythe on 2/27/20.
//  Copyright © 2020 Ride with GPS. All rights reserved.
//

import Foundation

public extension Observable {
    /// Bind to this observable with a simple value function, optionally replaying the existing value into the stream immediately
    ///
    /// This is a nice alternative to the standard `bind((Observable<ObservedType>, ObservedType)->Void)`, since we're 99% of the time uninterested in getting a reference to the Observable itself.
    /// - Parameters:
    ///   - replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    ///   - f: an observation function
    @discardableResult
    func bind(replay: Bool = true, _ f: @escaping (ObservedType) -> Void) -> BindingReceipt {
        let r = bind { _, value in f(value) }
        if replay, let value = value {
            f(value)
        }
        return r
    }
    
    func pausableBind(replay: Bool = true, _ f: @escaping (ObservedType) -> Void) -> PausableReceipt {
        PausableReceipt(
            receipt: bind(replay: replay, f),
            unbind: unbind,
            pauseObservations: pauseObservations,
            unpauseObservations: unpauseObservations
        )
    }
    
    @discardableResult
    func bindUI(replay: Bool = true, _ f: @escaping (ObservedType) -> Void) -> BindingReceipt {
        let r: BindingReceipt = bind { _, value in
            DispatchQueue.main.async {
                f(value)
            }
        }
        if replay, let value = value {
            DispatchQueue.main.async {
                f(value)
            }
        }
        return r
    }
    
    func pausableBindUI(replay: Bool = true, _ f: @escaping (ObservedType) -> Void) -> PausableReceipt {
        PausableReceipt(
            receipt: bindUI(replay: replay, f),
            unbind: unbind,
            pauseObservations: pauseObservations,
            unpauseObservations: unpauseObservations
        )
    }
    
    /// Create a new observable whose value is mapped from this observable's values
    /// - Parameters:
    ///   - replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    ///   - f: mapping function from this observable's values to the new observable's values
    func map<A>(replay: Bool = true, _ f: @escaping (ObservedType) -> A) -> Observable<A> {
        let child = Observable<A>()
        let r: BindingReceipt = bind(replay: replay) { [weak child] value in
            child?.value = f(value)
        }
        child.setObserving({ _ = self }, receipt: r)
        return child
    }
    
    /// Create a new observable of the same type as this observable, whose value is filtered before delivery
    /// - Parameters:
    ///   - replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    ///   - f: filter function on this observable's values
    func filter(replay: Bool = true, _ f: @escaping (ObservedType) -> Bool) -> Observable<ObservedType> {
        let child = Observable<ObservedType>()
        let r: BindingReceipt = bind(replay: replay) { [weak child] value in
            if f(value) {
                child?.value = value
            }
        }
        child.setObserving({ _ = self }, receipt: r)
        return child
    }
    
    /// Create a new observable whose value is defined by integrating this observable's value with the new observable's value using the `reducer` function
    /// - Parameters:
    ///   - replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    ///   - initial: initial value for the reducer function, when the new observable is empty
    ///   - reducer: reducer function to integrate our new value with the new observable's value
    func reduce<A>(replay: Bool = true, initial: A, _ reducer: @escaping (A, ObservedType) -> A) -> Observable<A> {
        let child = Observable<A>()
        let r: BindingReceipt = bind(replay: replay) { [weak child] newValue in
            let oldValue = child?.value ?? initial
            child?.value = reducer(oldValue, newValue)
        }
        child.setObserving({ _ = self }, receipt: r)
        return child
    }
    
    func debug(_ message: String) -> Observable {
        map { value in
            print(message + " (Current value: \(value))")
            return value
        }
    }
    
    /// Creates a new observable whose value is mapped from this observable's values, unless the mapping function returns nil
    /// - Parameters:
    ///   - replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    ///   - f: mapping function from this observable's values to an optional of the new observable's values.
    func compactMap<A>(replay: Bool = true, _ f: @escaping (ObservedType) -> A?) -> Observable<A> {
        let child = Observable<A>()
        let r: BindingReceipt = bind(replay: replay) { [weak child] value in
            if let v = f(value) {
                child?.value = v
            }
        }
        child.setObserving({ _ = self }, receipt: r)
        return child
    }
}

public extension Observable where ObservedType: Equatable {
    /// Only emit values when they differ from the previous value in this observable.
    /// - Parameter replay: If there's a value in this observable, after setting up the binding immediately fire the observation function with that value, rather than the default behavior of waiting for a new value to come into the stream. Defaults to true.
    func distinct(replay: Bool = true) -> Observable<ObservedType> {
        let child = Observable<ObservedType>()
        let r: BindingReceipt = bind(replay: replay) { [weak child] newValue in
            if newValue != child?.value {
                child?.value = newValue
            }
        }
        child.setObserving({ _ = self }, receipt: r)
        return child
    }
}


let ObserverZipThread = DispatchQueue(label: "RWGPS.Observer.Zipping")

/// Given two observables, create a new observable that produces a tuple of the two observers' current values any time either emits a value
public func zip<A, B>(replay: Bool = true, _ a: Observable<A>, _ b: Observable<B>) -> Observable<(A?, B?)> {
    let child = Observable<(A?, B?)>()
    let ra: BindingReceipt = a.bind { [weak child] a in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil)
            child?.value = (a, old.1)
        }
    }
    let rb: BindingReceipt = b.bind { [weak child] b in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil)
            child?.value = (old.0, b)
        }
    }
    if replay {
        ObserverZipThread.sync {
            child.value = (a.value, b.value)
        }
    }
    child.setObserving({ _ = a }, receipt: ra)
    child.setObserving({ _ = b }, receipt: rb)
    return child
}

public func zip<A, B, C>(replay: Bool = true, _ a: Observable<A>, _ b: Observable<B>, _ c: Observable<C>) -> Observable<(A?, B?, C?)> {
    let child = Observable<(A?, B?, C?)>()
    let ra: BindingReceipt = a.bind { [weak child] a in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil)
            child?.value = (a, old.1, old.2)
        }
    }
    let rb: BindingReceipt = b.bind { [weak child] b in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil)
            child?.value = (old.0, b, old.2)
        }
    }
    let rc: BindingReceipt = c.bind { [weak child] c in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil)
            child?.value = (old.0, old.1, c)
        }
    }
    if replay {
        ObserverZipThread.sync {
            child.value = (a.value, b.value, c.value)
        }
    }
    child.setObserving({ _ = a }, receipt: ra)
    child.setObserving({ _ = b }, receipt: rb)
    child.setObserving({ _ = c }, receipt: rc)
    return child
}

public func zip<A, B, C, D>(replay: Bool = true, _ a: Observable<A>, _ b: Observable<B>, _ c: Observable<C>, _ d: Observable<D>) -> Observable<(A?, B?, C?, D?)> {
    let child = Observable<(A?, B?, C?, D?)>()
    let ra: BindingReceipt = a.bind { [weak child] a in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil)
            child?.value = (a, old.1, old.2, old.3)
        }
    }
    let rb: BindingReceipt = b.bind { [weak child] b in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil)
            child?.value = (old.0, b, old.2, old.3)
        }
    }
    let rc: BindingReceipt = c.bind { [weak child] c in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil)
            child?.value = (old.0, old.1, c, old.3)
        }
    }
    let rd: BindingReceipt = d.bind { [weak child] c in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil)
            child?.value = (old.0, old.1, old.2, c)
        }
    }
    if replay {
        ObserverZipThread.sync {
            child.value = (a.value, b.value, c.value, d.value)
        }
    }
    child.setObserving({ _ = a }, receipt: ra)
    child.setObserving({ _ = b }, receipt: rb)
    child.setObserving({ _ = c }, receipt: rc)
    child.setObserving({ _ = d }, receipt: rd)
    return child
}

public func zip<A, B, C, D, E>(replay: Bool = true, _ a: Observable<A>, _ b: Observable<B>, _ c: Observable<C>, _ d: Observable<D>, _ e: Observable<E>) -> Observable<(A?, B?, C?, D?, E?)> {
    let child = Observable<(A?, B?, C?, D?, E?)>()
    let ra: BindingReceipt = a.bind { [weak child] a in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil, nil)
            child?.value = (a, old.1, old.2, old.3, old.4)
        }
    }
    let rb: BindingReceipt = b.bind { [weak child] b in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil, nil)
            child?.value = (old.0, b, old.2, old.3, old.4)
        }
    }
    let rc: BindingReceipt = c.bind { [weak child] c in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil, nil)
            child?.value = (old.0, old.1, c, old.3, old.4)
        }
    }
    let rd: BindingReceipt = d.bind { [weak child] d in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil, nil)
            child?.value = (old.0, old.1, old.2, d, old.4)
        }
    }
    let re: BindingReceipt = e.bind { [weak child] e in
        ObserverZipThread.sync {
            let old = child?.value ?? (nil, nil, nil, nil, nil)
            child?.value = (old.0, old.1, old.2, old.3, e)
        }
    }
    if replay {
        ObserverZipThread.sync {
            child.value = (a.value, b.value, c.value, d.value, e.value)
        }
    }
    
    child.setObserving({ _ = a }, receipt: ra)
    child.setObserving({ _ = b }, receipt: rb)
    child.setObserving({ _ = c }, receipt: rc)
    child.setObserving({ _ = d }, receipt: rd)
    child.setObserving({ _ = e }, receipt: re)
    return child
}
