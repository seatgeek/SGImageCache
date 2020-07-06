//
//  NSObject+Events.swift
//  SeatGeek
//
//  Created by Yuki O'Brien on 5/13/20.
//  Copyright © 2020 SeatGeek. All rights reserved.
//

import UIKit

public typealias EventName = String
public typealias EventHandler = (Any?) -> Void

/// Protocol for object based event handling and dispatching.
@objc public protocol EventHandling {
    
    /// Adds a handler for when an event is triggered.
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    func on(event: EventName, do handler: @escaping EventHandler)
    
    /// Adds a handler to execute once for when an event is triggered.
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    func on(event: EventName, doOnce handler: @escaping EventHandler)
    
    /// Adds a handler to be called when an event is triggered.
    /// - Parameters:
    ///   - event: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    ///   - once: Whether the hanlder should be executed once or repeatedly.
    func on(event: EventName, do handler: @escaping EventHandler, once: Bool)
    
    /// Adds a handler for when an event is triggered.
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    static func on(event: EventName, do handler: @escaping EventHandler)
    
    /// Adds a handler to execute once for when an event is triggered.
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    static func on(event: EventName, doOnce handler: @escaping EventHandler)
    
    /// Adds a handler to be called when an event is triggered.
    /// - Parameters:
    ///   - event: The name of the event
    ///   - handler: The handler to call when the event is triggered.
    ///   - once: Whether the hanlder should be executed once or repeatedly.
    static func on(event: EventName, do handler: @escaping EventHandler, once: Bool)
    
    /// Adds a handler to be called when any of the supplied events are triggered.
    /// - Parameters:
    ///   - events: The names of the events.
    ///   - handler: The handler to call when the event is triggered.
    func onAnyOf(events: [EventName], do handler: @escaping EventHandler)
    
    /// Adds a handler to be executed when an event is triggered.
    /// - Parameters:
    ///   - object: The object that will trigger the event.
    ///   - eventName: The name of the event.
    ///   - handler: The callback to execute.
    func when(object: NSObject, does eventName: EventName, do handler: @escaping EventHandler)
    
    /// Adds a handler to be executed when any one of a collection of events is triggered.
    /// - Parameters:
    ///   - object: The object that will trigger the event.
    ///   - eventNames: The names of the events.
    ///   - handler: The callback to execute.
    func when(object: NSObject, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler)
    
    ///  Adds a handler to be executed when an events is triggered by a type.
    /// - Parameters:
    ///   - type: The type that will trigger the event.
    ///   - eventName: The name of the event.
    ///   - handler: The callback to be executed.
    func when(type: NSObject.Type, does eventName: EventName, do handler: @escaping EventHandler)
    
    ///  Adds a handler to be executed when any one of a collection of events is triggered by a type.
    /// - Parameters:
    ///   - type: The type that will trigger the event.
    ///   - eventNames: The names of the events.
    ///   - handler: The callback to be executed.
    func when(type: NSObject.Type, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler)
    
    /// Adds a handler to be executed when any instance of the supplied type triggers an event.
    /// - Parameters:
    ///   - type: The type of instances that trigger the event.
    ///   - eventName: The name of the event.
    ///   - handler: The callback to execute.
    func whenAny(of type: NSObject.Type, does eventName: EventName, do handler: @escaping EventHandler)
    
    /// Adds a handler to be executed when any instance of the supplied type triggers any one of a collection of events.
    /// - Parameters:
    ///   - type: The type of instances that trigger the event.
    ///   - eventNames: The names of the events.
    ///   - handler: The callback to execute.
    func whenAny(of type: NSObject.Type, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler)
    
    /// Triggers an event.
    /// - Parameter event: Name of event to trigger.
    func triggerEvent(_ event: EventName)
    
    /// Triggers and event with context.
    /// - Parameters:
    ///   - event: The name fo the event.
    ///   - context: The context su[[lied to any callbacks.
    func triggerEvent(_ event: EventName, withContext context: AnyObject?)
    
    /// Triggers an event.
    /// - Parameter event: Name of event to trigger.
    static func triggerEvent(_ event: EventName)
    
    /// Triggers and event with context.
    /// - Parameters:
    ///   - event: The name fo the event.
    ///   - context: The context su[[lied to any callbacks.
    static func triggerEvent(_ event: EventName, withContext context: AnyObject?)
}

extension NSObject: EventHandling {
    private static let SGProxyHandlersKey = "SGObjectEventsProxyHandlers"
    private static let SGUserInfoContextKey = "SGUserInfoContextKey"
    
    private final class TokenContainer: NSObject {
        var token: NotificationToken?
    }
    
    public func on(event: EventName, do handler: @escaping EventHandler) {
        on(event: event, do: handler, once: false)
    }
    
    public func on(event: EventName, doOnce handler: @escaping EventHandler) {
        on(event: event, do: handler, once: true)
    }
    
    public func on(event: EventName, do handler: @escaping EventHandler, once: Bool) {
        let tokenContainer = TokenContainer()
        let notificationToken = NotificationCenter.default.observe(name: Notification.Name(event),
                                           object: self,
                                           queue: nil,
                                           using: { [weak self, weak tokenContainer] notification in
                                            guard let self = self,
                                                let tokenContainer = tokenContainer else {
                                                    return
                                            }
                                            
                                            handler(notification.userInfo?[NSObject.SGUserInfoContextKey])
                                            if once {
                                                self.sg_notificationTokens.remove(tokenContainer)
                                            }
        })
        tokenContainer.token = notificationToken
        
        sg_notificationTokens.insert(tokenContainer)
    }
    
    public static func on(event: EventName, do handler: @escaping EventHandler) {
        on(event: event, do: handler, once: false)
    }
    
    public static func on(event: EventName, doOnce handler: @escaping EventHandler) {
        on(event: event, do: handler, once: true)
    }
    
    public static func on(event: EventName, do handler: @escaping EventHandler, once: Bool) {
        let tokenContainer = TokenContainer()
        let notificationToken = NotificationCenter.default.observe(name: Notification.Name(event),
                                                                   object: self,
                                                                   queue: nil,
                                                                   using: { [weak tokenContainer] notification in
                                                                    guard let tokenContainer = tokenContainer else {
                                                                            return
                                                                    }
                                                                    
                                                                    handler(notification.userInfo?[NSObject.SGUserInfoContextKey])
                                                                    if once {
                                                                        self.sg_notificationTokens.remove(tokenContainer)
                                                                    }
        })
        tokenContainer.token = notificationToken
        
        sg_notificationTokens.insert(tokenContainer)
    }
    
    public func onAnyOf(events: [EventName], do handler: @escaping EventHandler) {
        events.forEach { on(event: $0, do: handler) }
    }
    
    public func when(object: NSObject, does eventName: EventName, do handler: @escaping EventHandler) {
        let tokenContainer = TokenContainer()
        let notificationToken = NotificationCenter.default.observe(name: Notification.Name(eventName),
                                                                   object: object,
                                                                   queue: nil,
                                                                   using: { notification in

                                                                    handler(notification.userInfo?[NSObject.SGUserInfoContextKey])
        })
        tokenContainer.token = notificationToken
        
        sg_notificationTokens.insert(tokenContainer)
    }
    
    public func when(object: NSObject, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler) {
        eventNames.forEach { when(object: object, does: $0, do: handler) }
    }
    
    public func when(type: NSObject.Type, does eventName: EventName, do handler: @escaping EventHandler) {
        let tokenContainer = TokenContainer()
        let notificationToken = NotificationCenter.default.observe(name: Notification.Name(eventName),
                                                                   object: type,
                                                                   queue: nil,
                                                                   using: { notification in
                                                                    handler(notification.userInfo?[NSObject.SGUserInfoContextKey])
        })
        tokenContainer.token = notificationToken
        
        sg_notificationTokens.insert(tokenContainer)
    }
    
    public func when(type: NSObject.Type, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler) {
        eventNames.forEach { when(type: type, does: $0, do: handler) }
    }
    
    public func whenAny(of type: NSObject.Type, does eventName: EventName, do handler: @escaping EventHandler) {
        when(type: type, does: NSObject.sg_globalEventName(for: eventName), do: handler)
    }
    
    public func whenAny(of type: NSObject.Type, doesAnyOf eventNames: [EventName], do handler: @escaping EventHandler) {
        eventNames.forEach { whenAny(of: type, does: $0, do: handler) }
    }
    
    public func triggerEvent(_ event: EventName) {
        triggerEvent(event, withContext: nil)
    }
    
    public func triggerEvent(_ event: EventName, withContext context: AnyObject?) {
        defer {
            type(of: self).triggerEvent(NSObject.sg_globalEventName(for: event), withContext: context)
        }
        
        var userInfo: [AnyHashable: Any]?
        if let context = context {
            userInfo = [NSObject.SGUserInfoContextKey: context]
        }
        
        NotificationCenter.default.post(name: Notification.Name(event),
                                        object: self,
                                        userInfo: userInfo)
    }
    
    public static func triggerEvent(_ event: EventName) {
        triggerEvent(event, withContext: nil)
    }
    
    public static func triggerEvent(_ event: EventName, withContext context: AnyObject?) {
        var userInfo: [AnyHashable: Any]?
        if let context = context {
            userInfo = [NSObject.SGUserInfoContextKey: context]
        }
        
        NotificationCenter.default.post(name: Notification.Name(event),
                                        object: self,
                                        userInfo: userInfo)
    }
    
    private static func sg_globalEventName(for eventName: EventName) -> EventName {
        return "\(eventName)-SGGlobalEvent"
    }
    
    private struct SGObjectEventAssociatedKeys {
        static var EventHandlers = "sg_notificationTokens"
    }
    
    private var sg_notificationTokens: Set<TokenContainer> {
        get {
            if let tokens = objc_getAssociatedObject(self, &SGObjectEventAssociatedKeys.EventHandlers) as? Set<TokenContainer> {
                return tokens
            }
            
            let tokens = Set<TokenContainer>()
            self.sg_notificationTokens = tokens
            return tokens
        }
        
        set {
            objc_setAssociatedObject(self, &SGObjectEventAssociatedKeys.EventHandlers, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private static var sg_notificationTokens: Set<TokenContainer> {
        get {
            if let tokens = objc_getAssociatedObject(self, &SGObjectEventAssociatedKeys.EventHandlers) as? Set<TokenContainer> {
                return tokens
            }
            
            let tokens = Set<TokenContainer>()
            self.sg_notificationTokens = tokens
            return tokens
        }
        
        set {
            objc_setAssociatedObject(self, &SGObjectEventAssociatedKeys.EventHandlers, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
