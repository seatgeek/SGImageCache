//
//  Created by matt on 19/10/12.
//

#if !TARGET_OS_WATCH

#import "MGBlockWrapper.h"

/**
* Provides lightweight, blocks based control event observing.
*/

@interface UIControl (MGEvents)

@property (nonatomic, retain) NSMutableDictionary *MGEventHandlers;

/**
When a control event is triggered of the given kind, perform the given block.

    [button onControlEvent:UIControlEventTouchUpInside do:^{
        NSLog(@"i've been tapped!");
    }];
*/
- (void)onControlEvent:(UIControlEvents)controlEvent do:(MGBlock)handler;

/**
* Remove all event handlers for the given control event.
*/
- (void)removeHandlersForControlEvent:(UIControlEvents)controlEvent;

@end

#endif
