//
//  NSObject+Observable.swift
//  SimpleTwoWayBinding
//
//  Created by Manish Katoch on 11/26/17.
//

import Foundation

extension NSObject {
    @discardableResult
    public func observe<T>(for observable: Observable<T>, replay: Bool = false, forUI: Bool = false, with: @escaping (T) -> ()) -> BindingReceipt {
        let receipt = observable.bind { observable, value  in
            if forUI {
                DispatchQueue.main.async {
                    with(value)
                }
            }
            else {
                with(value)
            }
        }
        if replay {
            if let value = observable.value {
                if forUI {
                    DispatchQueue.main.async {
                        with(value)
                    }
                }
                else {
                    with(value)
                }
            }
        }
        return receipt
    }
    
    public func observeForUI<T>(for observable: Observable<T>, replay: Bool = true, with: @escaping (T) -> ()) -> BindingReceipt {
        return observe(for: observable, replay: replay, forUI: true, with: with)
    }
}
