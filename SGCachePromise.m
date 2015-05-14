//
//  SGCachePromise.m
//  Pods
//
//  Created by James Van-As on 13/05/15.
//
//

#import "SGCachePromise.h"
#import "SGCache.h"
#import "SGCachePrivate.h"

@implementation SGCachePromise

- (void)setOnRetry:(SGCacheFetchOnRetry)onRetry {
    _onRetry = [onRetry copy];
    [SGCache addRetryForPromise:self retryBlock:_onRetry];
}

- (void)setOnFail:(SGCacheFetchFail)onFail {
    _onFail = [onFail copy];
    [SGCache addFailForPromise:self failBlock:onFail];
}

@end
