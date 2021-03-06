//
//  Observable.swift
//  SimpleTwoWayBinding
//
//  Created by Manish Katoch on 11/26/17.
//

import Foundation

public class ReceiptBag {
    public var receipts: [PausableReceipt] = []
    
    func pause() { receipts.forEach { $0.pauseObservations() } }
    func unpause() { receipts.forEach { $0.unpauseObservations() } }
    
    public init() {}
}

public struct BindingReceipt: Hashable, Identifiable {
    public let id = UUID()
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: BindingReceipt, rhs: BindingReceipt) -> Bool { lhs.id == rhs.id }
}

public struct PausableReceipt {
    public let receipt: BindingReceipt
    
    public var unbind: (BindingReceipt) -> Void
    public var pauseObservations: () -> Void
    public var unpauseObservations: () -> Void
     
    public func add(to bag: ReceiptBag) { bag.receipts.append(self) }
}

public class Observable<ObservedType> {
    public typealias Observer = (_ observable: Observable<ObservedType>, ObservedType) -> Void
    
    /// Map of receipt objects to the binding blocks those objects represent; see bind(observer:) and unbind(:)
    private var observers: [BindingReceipt: Observer] = [:]
    /// Map of other observers we've been bound to; see map(:) & other functional conveniences. This allows us to hold strong references to the anonymous observables generated in a chained series of calls, and break them when needed.
    private var bindings: [BindingReceipt: () -> Void] = [:]
    
    public var value: ObservedType? {
        didSet {
            if let value = value {
                notifyObservers(value)
            }
        }
    }
    
    public init(_ value: ObservedType? = nil) {
        self.value = value
    }
    
    @discardableResult
    public func bind(observer: @escaping Observer) -> BindingReceipt {
        let r = BindingReceipt()
        observers[r] = observer
        return r
    }
    
    public func pausableBind(observer: @escaping Observer) -> PausableReceipt {
        PausableReceipt(
            receipt: bind(observer: observer),
            unbind: unbind,
            pauseObservations: pauseObservations,
            unpauseObservations: unpauseObservations)
    }
    
    public func setObserving(_ referenceHolder: @escaping () -> Void, receipt: BindingReceipt) {
        bindings[receipt] = referenceHolder
    }
    
    public func unbind(_ r: BindingReceipt) {
        guard observers[r] != nil else {
            print("Warning: attempted to unbind with an invalid receipt")
            return
        }
        observers[r] = nil
        bindings[r] = nil
    }
    
    private func notifyObservers(_ value: ObservedType) {
        observers.values.forEach { [unowned self] observer in
            guard paused == false else { return }
            observer(self, value)
        }
    }
    
    private var paused: Bool = false
    
    public func pauseObservations() { paused = true }
    public func unpauseObservations() { paused = false }
}

