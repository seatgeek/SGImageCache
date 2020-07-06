#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "MGBlockWrapper.h"
#import "MGDeallocAction.h"
#import "MGEvents.h"
#import "MGObserver.h"
#import "MGWeakHandler.h"
#import "NSObject+MGEvents.h"
#import "UIControl+MGEvents.h"

FOUNDATION_EXPORT double MGEventsVersionNumber;
FOUNDATION_EXPORT const unsigned char MGEventsVersionString[];

