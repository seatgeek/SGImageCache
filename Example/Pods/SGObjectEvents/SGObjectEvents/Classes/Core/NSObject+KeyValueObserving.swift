//
//  NSObject+KeyValueObserving.swift
//  Pods
//
//  Created by Yuki O'Brien on 6/4/20.
//

import Foundation

@objc extension NSObject {
    public func onChangeOfAny(keyPaths: [String], do handler: @escaping () -> Void) {
        keyPaths.forEach { onChangeOf(keyPath: $0, do: handler) }
    }
    
    public func onChangeOf(keyPath: String, do handler: @escaping () -> Void) {
        var observers = sg_observers[keyPath] ?? [SGObjectObserver]()
        let observer = SGObjectObserver(objectToObserve: self, keyPath: keyPath, callBack: handler)
        observers.append(observer)
        
        observer.onDeinit = { [weak self, weak observer] in
            guard let self = self,
                let observer = observer else {
                    return
            }
            
            self.removeObserver(observer, forKeyPath: keyPath)
        }
        
        sg_observers[keyPath] = observers
    }
    
    private static func sg_globalEventName(for eventName: EventName) -> EventName {
        return "\(eventName)-SGGlobalEvent"
    }
    
    private struct SGKeyValueObservingAssociatedKeys {
        static var ObjectObservers = "sg_objectObservers"
    }
    
    private var sg_observers: [String: [SGObjectObserver]] {
        get {
            if let objectObservers = objc_getAssociatedObject(self, &SGKeyValueObservingAssociatedKeys.ObjectObservers) as? [String: [SGObjectObserver]] {
                return objectObservers
            }
            
            let objectObservers = [String: [SGObjectObserver]]()
            self.sg_observers = objectObservers
            return objectObservers
        }
        
        set {
            objc_setAssociatedObject(self, &SGKeyValueObservingAssociatedKeys.ObjectObservers, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

fileprivate final class SGObjectObserver: NSObject {
    let callBack: () -> Void
    
    init(objectToObserve: NSObject, keyPath: String, callBack: @escaping () -> Void) {
        self.callBack = callBack
        super.init()
        
        objectToObserve.addObserver(self,
                                    forKeyPath: keyPath,
                                    options: .new,
                                     context: nil)
    }
    
    public override func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey: Any]?,
                                      context: UnsafeMutableRawPointer?) {
        callBack()
    }
    
    public var onDeinit: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.DeinitAction) as? (() -> Void)
        }
        
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.DeinitAction, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct AssociatedKeys {
        static var DeinitAction = "sg_deinitAction"
    }
}

fileprivate final class SGDeallocAction: NSObject {
    let actionBlock: () -> Void
    
    init(actionBlock: @escaping () -> Void) {
        self.actionBlock = actionBlock
        super.init()
    }
    
    deinit {
        actionBlock()
    }
}
