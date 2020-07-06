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

#import "SGFileCache.h"
#import "NSObject+SGHTTPRequest.h"
#import "NSString+SGHTTPRequest.h"
#import "SGHTTPRequestDebug.h"
#import "SGJSONSerialization.h"
#import "SGHTTPRequest.h"

FOUNDATION_EXPORT double SGHTTPRequestVersionNumber;
FOUNDATION_EXPORT const unsigned char SGHTTPRequestVersionString[];

