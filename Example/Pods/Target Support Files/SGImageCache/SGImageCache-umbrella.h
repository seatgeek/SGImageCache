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

#import "NSString+SGImageCacheHash.h"
#import "SGCache.h"
#import "SGCachePrivate.h"
#import "SGCachePromise.h"
#import "SGCacheTask.h"
#import "SGCacheTaskPrivate.h"
#import "SGImageCache.h"
#import "SGImageCachePrivate.h"
#import "SGImageCacheTask.h"
#import "SGImageView.h"
#import "UIImageView+SGImageCache.h"

FOUNDATION_EXPORT double SGImageCacheVersionNumber;
FOUNDATION_EXPORT const unsigned char SGImageCacheVersionString[];

