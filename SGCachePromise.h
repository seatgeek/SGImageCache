//
//  SGCachePromise.h
//  Pods
//
//  Created by James Van-As on 13/05/15.
//
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <PromiseKit/Promise.h>
#pragma clang pop

#import <MGEvents/MGEvents.h>

typedef void(^SGCacheFetchCompletion)(id obj);
typedef void(^SGCacheFetchFail)(NSError *error, BOOL wasFatal);
typedef void(^SGCacheFetchOnRetry)(void);

@interface SGCachePromise : PMKPromise
@property (nonatomic, copy) SGCacheFetchOnRetry onRetry;
@property (nonatomic, copy) SGCacheFetchFail onFail;
@end
