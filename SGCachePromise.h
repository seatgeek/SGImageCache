//
//  SGCachePromise.h
//  Pods
//
//  Created by James Van-As on 13/05/15.
//
//

#import "Promise.h"
#import "MGEvents.h"

typedef void(^SGCacheFetchCompletion)(id obj);
typedef void(^SGCacheFetchFail)(NSError *error, BOOL wasFatal);
typedef void(^SGCacheFetchOnRetry)();

@interface SGCachePromise : PMKPromise
@property (nonatomic, copy) SGCacheFetchOnRetry onRetry;
@property (nonatomic, copy) SGCacheFetchFail onFail;
@end
