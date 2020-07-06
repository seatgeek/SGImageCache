//
//  Created by matt on 24/09/12.
//

#import "MGBlockWrapper.h"

/**
* Provides lightweight, blocks based keypath observing and custom events.
*/

@interface NSObject (MGEvents)

#pragma mark - Custom event observing

/** @name Custom event observing */

@property (nonatomic, retain) NSMutableDictionary *MGEventHandlers;

#pragma mark Observing specific objects

/**
When a custom event is triggered with the given name, perform the given block.

    [earth on:@"ChangedShape" do:^{
        NSLog(@"the earth has changed shape");
    }];
*/
- (void)on:(NSString *)eventName do:(MGBlock)handler;

/**
 When a custom event is triggered by any of the given names, perform the given block.

 [earth onAnyOf:@[@"ChangedShape", @"StoppedSpinning"] do:^{
     NSLog(@"the earth has changed shape or stopped spinning");
 }];
 */
- (void)onAnyOf:(NSArray *)eventNames do:(MGBlock)handler;

/**
* When a custom event is triggered with the given name, perform the given block
* once. The block will not be performed on future triggering of the same event.
*/
- (void)on:(NSString *)eventName doOnce:(MGBlock)handler;

/**
When a custom event is triggered with the given name, perform the given block.
The block may potentially be provided a context object.

    [earth on:@"ChangedShape" doWithContext:^(id context) {
        NSLog(@"the earth has changed shape.");
        NSLog(@"some details about the shape change: %@", context);
    }];
*/
- (void)on:(NSString *)eventName doWithContext:(MGBlockWithContext)handler;

/**
 When a custom event is triggered with any of the given names, perform the given block.
 The block may potentially be provided a context object.

 [earth onAnyOf:@[@"ChangedShape", @"StoppedSpinning"] doWithContext:^(id context) {
     NSLog(@"the earth has changed shape or stopped spinning.");
     NSLog(@"some details about the change: %@", context);
 }];
 */
- (void)onAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler;

#pragma mark Observing other objects

/**
 When a particular object triggers the specified event, perform the given block.

 [self when:earth does:@"ChangedShape" do:^{
    NSLog(@"the earth has changed shape");
 }];
*/

- (void)when:(id)object does:(NSString *)eventName do:(MGBlock)handler;

/**
 When a particular object triggeres any of the specified events, perform the given block.

 [self when:earth doesAnyOf:@[@"ChangedShape", @"StoppedSpinning"] do:^{
     NSLog(@"the earth has changed shape or stopped spinning");
 }];
 */

- (void)when:(id)object doesAnyOf:(NSArray *)eventNames do:(MGBlock)handler;

/**
 When a particular object triggers the specified event, perform the given block.
 The block may potentially be provided a context object.
 [self when:earth does:@"ChangedShape" doWithContext:^(id context) {
     NSLog(@"some details about the change: %@", context);
 }];
*/

- (void)when:(id)object does:(NSString *)eventName doWithContext:(MGBlockWithContext)handler;

/**
 When a particular object triggers any of the specified events, perform the given block.
 The block may potentially be provided a context object.
 [self when:earth doesAnyOf:@[@"ChangedShape", @"StoppedSpinning"] doWithContext:^(id context) {
 NSLog(@"some details about the change: %@", context);
 }];
 */

- (void)when:(id)object doesAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler;

#pragma mark Listening for an event from any object

/**
 When any object of the given class triggers the specified event, perform the given block.

 [self whenAny:Earth.class does:@"ChangedShape" do:^{
 NSLog(@"an earth has changed shape");
 }];
 */

- (void)whenAny:(Class)objectOfClass does:(NSString *)eventName do:(MGBlock)handler;

/**
 When any object triggeres any of the specified events, perform the given block.

 [self when:earth doesAnyOf:@[@"ChangedShape", @"StoppedSpinning"] do:^{
 NSLog(@"the earth has changed shape or stopped spinning");
 }];
 */

- (void)whenAny:(Class)objectOfClass doesAnyOf:(NSArray *)eventNames do:(MGBlock)handler;

/**
 When any object triggers the specified event, perform the given block.
 The block may potentially be provided a context object.
 [self whenAny:Earth.class does:@"ChangedShape" doWithContext:^(id context) {
 NSLog(@"some details about the change: %@", context);
 }];
 */

- (void)whenAny:(Class)objectOfClass does:(NSString *)eventName doWithContext:(MGBlockWithContext)handler;

/**
 When any object triggers any of the specified events, perform the given block.
 The block may potentially be provided a context object.
 [self whenAny:Earth.class doesAnyOf:@[@"ChangedShape", @"StoppedSpinning"] doWithContext:^(id context) {
 NSLog(@"some details about the change: %@", context);
 }];
 */

- (void)whenAny:(Class)objectOfClass doesAnyOf:(NSArray *)eventNames doWithContext:(MGBlockWithContext)handler;

#pragma mark - Custom event triggering

/** @name Custom event triggering */

/**
Trigger a custom event.

    [earth trigger:@"ChangedShape"];
*/
- (void)trigger:(NSString *)eventName;

/**
Trigger a custom event, providing context.

    [earth trigger:@"ChangedShape" withContext:@{ @"newShape": @"flat" }];
*/
- (void)trigger:(NSString *)eventName withContext:(id)context;

#pragma mark - Keypath observing

/** @name Keypath observing */

@property (nonatomic, retain) NSMutableDictionary *MGObservers;

/**
On change of the given keypath, perform the given block.

    [box onChangeOf:@"selected" do:^{
        NSLog(@"my selected state changed to: %@", box.selected ? @"ON" : @"OFF");
    }];
*/
- (void)onChangeOf:(NSString *)keypath do:(MGBlock)block;

/**
On change of any of the given keypaths, perform the given block.

    [box onChangeOfAny:@[@"selected", @"highlighted"] do:^{
        NSLog(@"my selected state is: %@", box.selected ? @"ON" : @"OFF");
        NSLog(@"my highlighted state is: %@", box.highlighted ? @"ON" : @"OFF");
    }];
*/
- (void)onChangeOfAny:(NSArray *)keypaths do:(MGBlock)block;

@property (nonatomic, copy) MGBlock onDealloc;

@end
