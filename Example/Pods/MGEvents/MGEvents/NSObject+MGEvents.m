//
//  Created by matt on 24/09/12.
//

#import "NSObject+MGEvents.h"
#import "MGObserver.h"
#import "MGWeakHandler.h"
#import "MGDeallocAction.h"
#import <objc/runtime.h>

static char *MGObserversKey = "MGObserversKey";
static char *MGEventHandlersKey = "MGEventHandlersKey";
static char *MGDeallocActionKey = "MGDeallocActionKey";

#define MGProxyHandlers @"MGProxyHandlers"

@implementation NSObject (MGEvents)

#pragma mark - Custom events

- (void)on:(NSString *)eventName do:(MGBlock)handler {
  [self on:eventName do:handler once:NO context:NO];
}

- (void)onAnyOf:(NSArray *)eventNames do:(MGBlock)handler {
    for (NSString *eventName in eventNames) {
        [self on:eventName do:handler];
    }
}

- (void)on:(NSString *)eventName doOnce:(MGBlock)handler {
  [self on:eventName do:handler once:YES context:NO];
}

- (void)on:(NSString *)eventName doWithContext:(MGBlockWithContext)handler {
  [self on:eventName do:(MGBlock)handler once:NO context:YES];
}

- (void)onAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler {
    for (NSString *eventName in eventNames) {
        [self on:eventName doWithContext:handler];
    }
}

- (void)on:(NSString *)eventName do:(MGBlock)handler once:(BOOL)once
   context:(BOOL)isContextBlock {

  // get all handlers for this event type
  NSMutableArray *handlers = self.MGEventHandlers[eventName];
  if (!handlers) {
    handlers = @[].mutableCopy;
    self.MGEventHandlers[eventName] = handlers;
  }

  if (isContextBlock) {
    [handlers addObject:@{@"blockWithContext" : [handler copy], @"once" : @(once)
    }];
  } else {
    [handlers addObject:@{@"block" : [handler copy], @"once" : @(once)}];
  }
}

- (void)when:(id)object does:(NSString *)eventName do:(MGBlock)handler {
    [self when:object does:eventName do:handler context:NO];
}

- (void)when:(id)object doesAnyOf:(NSArray *)eventNames do:(MGBlock)handler {
    for (NSString *eventName in eventNames) {
        [self when:object does:eventName do:handler];
    }
}

- (void)when:(id)object does:(NSString *)eventName doWithContext:(MGBlockWithContext)handler {
    [self when:object does:eventName do:(MGBlock)handler context:YES];
}

- (void)when:(id)object doesAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler {
    for (NSString *eventName in eventNames) {
        [self when:object does:eventName doWithContext:handler];
    }
}

- (void)when:(NSObject *)object does:(NSString *)eventName do:(MGBlock)handler
      context:(BOOL)isContextBlock {

    // get the proxy handlers array
    NSMutableArray *handlers = self.MGEventHandlers[MGProxyHandlers];
    if (!handlers) {
        handlers = @[].mutableCopy;
        self.MGEventHandlers[MGProxyHandlers] = handlers;
    }

    // get the target object's handlers array
    NSMutableArray *theirHandlers = object.MGEventHandlers[eventName];
    if (!theirHandlers) {
        theirHandlers = @[].mutableCopy;
        object.MGEventHandlers[eventName] = theirHandlers;
    }

    id handlerDict = isContextBlock
          ? @{@"blockWithContext":[handler copy], @"once":@NO}
          : @{@"block":[handler copy], @"once":@NO};

    // store the handler dict locally
    [handlers addObject:handlerDict];

    // give the target object a weak reference to it, so that if we dealloc
    // it goes away with us, instead of lingering forever
    [theirHandlers addObject:[MGWeakHandler handlerWithDict:handlerDict]];
}

- (void)whenAny:(Class)objectOfClass does:(NSString *)eventName do:(MGBlock)handler {
    [self when:objectOfClass does:[NSObject globalMGEventNameFor:eventName] do:handler];
}

- (void)whenAny:(Class)objectOfClass doesAnyOf:(NSArray *)eventNames do:(MGBlock)handler {
    NSMutableArray *mangledEventNames = NSMutableArray.new;
    for (NSString *eventName in eventNames) {
        [mangledEventNames addObject:[NSObject globalMGEventNameFor:eventName]];
    }
    [self when:objectOfClass doesAnyOf:mangledEventNames.copy do:handler];
}

- (void)whenAny:(Class)objectOfClass does:(NSString *)eventName doWithContext:(MGBlockWithContext)handler {
    [self when:objectOfClass does:[NSObject globalMGEventNameFor:eventName] doWithContext:handler];
}

- (void)whenAny:(Class)objectOfClass doesAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler {
    NSMutableArray *mangledEventNames = NSMutableArray.new;
    for (NSString *eventName in eventNames) {
        [mangledEventNames addObject:[NSObject globalMGEventNameFor:eventName]];
    }
    [self when:objectOfClass doesAnyOf:mangledEventNames.copy doWithContext:handler];
}

- (void)trigger:(NSString *)eventName {
    [self trigger:eventName withContext:nil];
}

- (void)trigger:(NSString *)eventName withContext:(id)context {
  NSMutableArray *handlers = self.MGEventHandlers[eventName];
    for (id handler in handlers.copy) {
        NSDictionary *handlerDict = [handler isKindOfClass:MGWeakHandler.class]
              ? [handler dict]
              : handler;
        if (!handlerDict) {
            [handlers removeObject:handler];
            continue;
        }
        if (handlerDict[@"blockWithContext"]) {
            MGBlockWithContext block = handlerDict[@"blockWithContext"];
            block(context);
        } else if (handlerDict[@"block"]) {
            MGBlock block = handlerDict[@"block"];
            block();
        }
        if ([handlerDict[@"once"] boolValue]) {
            [handlers removeObject:handler];
        }
    }
    if (!class_isMetaClass(object_getClass(self))) {
        [self.class trigger:[NSObject globalMGEventNameFor:eventName] withContext:context];
    }
}

#pragma mark - Property observing

- (void)onChangeOf:(NSString *)keypath do:(MGBlock)block {

  // get observers for this keypath
  NSMutableArray *observers = self.MGObservers[keypath];
  if (!observers) {
    observers = @[].mutableCopy;
    self.MGObservers[keypath] = observers;

  }

  // make and store an observer
  MGObserver *observer = [MGObserver observerFor:self keypath:keypath block:block];
  [observers addObject:observer];

  __unsafe_unretained id _self = self;
  __unsafe_unretained id _observer = observer;
  observer.onDealloc = ^{
      [_self removeObserver:_observer forKeyPath:keypath];
  };

  // force this object to be thrown in the autorelease pool, and not
  // be possible to be freed immediately by ARC if nothing is retaining the
  // object.  This can cause a KVO exception on x86 if this happens.
  static NSMutableArray *runloopRetainer;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    runloopRetainer = NSMutableArray.new;
  });
  [runloopRetainer addObject:self];
  dispatch_async(dispatch_get_main_queue(), ^{
    [runloopRetainer removeObject:self];
  });
}

- (void)onChangeOfAny:(NSArray *)keypaths do:(MGBlock)block {
  for (NSString *keypath in keypaths) {
    [self onChangeOf:keypath do:block];
  }
}

#pragma mark - Getters

- (NSMutableDictionary *)MGEventHandlers {
  id handlers = objc_getAssociatedObject(self, MGEventHandlersKey);
  if (!handlers) {
    handlers = @{}.mutableCopy;
    self.MGEventHandlers = handlers;
  }
  return handlers;
}

- (NSMutableDictionary *)MGObservers {
  id observers = objc_getAssociatedObject(self, MGObserversKey);
  if (!observers) {
    observers = @{}.mutableCopy;
    self.MGObservers = observers;
  }
  return observers;
}

- (MGBlock)onDealloc {
  MGDeallocAction *wrapper = objc_getAssociatedObject(self, MGDeallocActionKey);
  return wrapper.block;
}

+ (NSString *)globalMGEventNameFor:(NSString *)objectEvent {
    return [objectEvent stringByAppendingString:@"-MGGlobalEvent"];
}

#pragma mark - Setters

- (void)setMGEventHandlers:(NSMutableDictionary *)handlers {
  objc_setAssociatedObject(self, MGEventHandlersKey, handlers,
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setMGObservers:(NSMutableDictionary *)observers {
  objc_setAssociatedObject(self, MGObserversKey, observers,
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setOnDealloc:(MGBlock)block {
  MGDeallocAction *wrapper = objc_getAssociatedObject(self, MGDeallocActionKey);
  if (!wrapper) {
    wrapper = MGDeallocAction.new;
    objc_setAssociatedObject(self, MGDeallocActionKey, wrapper,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  wrapper.block = block;
}

@end
