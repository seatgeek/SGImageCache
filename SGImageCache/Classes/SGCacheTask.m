//
//  Created by matt on 22/05/14.
//

#import "SGCacheTask.h"
#import "SGHTTPRequest.h"
#import "SGCachePrivate.h"
#import "SGCachePromise.h"

@interface SGCacheTask ()
@property (nonatomic, strong) SGHTTPRequest *request;
@property (nonatomic, strong) NSError *currentErrorStatus;
@property (nonatomic, assign) BOOL currentErrorRetry;
@end

@implementation SGCacheTask {
    BOOL _isExecuting, _isFinished;
    NSMutableOrderedSet *_completions;
    NSMutableOrderedSet *_failBlocks;
    NSMutableOrderedSet *_retryBlocks;
}

- (id)init {
    self = [super init];
    _completions = NSMutableOrderedSet.new;
    _failBlocks = NSMutableOrderedSet.new;
    _retryBlocks = NSMutableOrderedSet.new;
    _cacheClass = SGCache.class;
    return self;
}

+ (instancetype)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey attempt:(int)attempt {
    SGCacheTask *task = self.new;
    task.attempt = attempt;
    task.url = url;
    task.requestHeaders = headers;
    task.cacheKey = cacheKey;
    return task;
}

- (void)addCompletion:(SGCacheFetchCompletion)completion {
    if (completion) {
        @synchronized (self) {
            [_completions addObject:[completion copy]];
        }
    }
}

- (void)addCompletions:(NSMutableOrderedSet *)completions {
    if (completions.count) {
        @synchronized (self) {
            [_completions unionOrderedSet:completions];
        }
    }
}

- (void)addFailBlock:(SGCacheFetchFail)fail {
    if (fail) {
        @synchronized (self) {
            [_failBlocks addObject:[fail copy]];
        }
    }
}

- (void)addFailBlocks:(NSMutableOrderedSet *)fails {
    if (fails.count) {
        @synchronized (self) {
            [_failBlocks unionOrderedSet:fails];
        }
    }
}

- (void)addRetryBlock:(SGCacheFetchOnRetry)retry {
    if (retry) {
        @synchronized (self) {
            [_retryBlocks addObject:[retry copy]];
        }
    }
}

- (void)addRetryBlocks:(NSMutableOrderedSet *)retries {
    if (retries.count) {
        @synchronized (self) {
            [_retryBlocks unionOrderedSet:retries];
        }
    }
}

- (void)start {
    self.executing = YES;
    if (self.isCancelled) {
        [self finish];
        return;
    }
    if (!self.remoteFetchOnly && [self.cacheClass haveFileForURL:self.url]) {
        [self completedWithFile:[self.cacheClass fileForURL:self.url]];
    } else {
        [self fetchRemoteFile];
    }
}

- (void)fetchRemoteFile {
    self.currentErrorStatus = nil;
    self.request = [SGHTTPRequest requestWithURL:[NSURL URLWithString:self.url]];
    self.request.responseFormat = SGHTTPDataTypeHTTP;
    self.request.allowCacheToDisk = NO;

    if (self.requestHeaders) {
        self.request.requestHeaders = self.requestHeaders;
    }

    self.request.logging = SGHTTPLogNothing;
    if (SGCache.logging & SGImageCacheLogErrors) {
        self.request.logging |= SGHTTPLogErrors;
    }
    if (SGCache.logging & SGImageCacheLogRequests) {
        self.request.logging |= SGHTTPLogRequests;
    }
    if (SGCache.logging & SGImageCacheLogResponses) {
        self.request.logging |= SGHTTPLogResponses;
    }

    __weakSelf me = self;
    self.request.onSuccess = ^(SGHTTPRequest *req) {
        me.currentErrorStatus = nil;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [me completedWithFile:req.responseData];
        });
    };
    self.request.onNetworkReachable = ^{
        [me willRetry];
        [me fetchRemoteFile];
    };
    self.request.onFailure = ^(SGHTTPRequest *req) {
        me.currentErrorStatus = req.error;
        NSInteger code = req.statusCode;
        if (code >= 400 && code < 408) { // give up on 4XX http errors
            me.currentErrorRetry = NO;
            [me failedWithError:req.error allowRetry:NO];
        } else {
            me.currentErrorRetry = YES;
            [me failedWithError:req.error allowRetry:YES];
        }
    };
    [self.request start];
}

- (void)completedWithFile:(NSData *)data {
    [self.cacheClass addData:data forCacheKey:self.cacheKey];

    // call the completion blocks on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SGCacheFetchCompletion completion in self.completions) {
            completion(data);
        }
    });

    self.succeeded = YES;
    [self finish];
}

- (void)failedWithError:(NSError *)error allowRetry:(BOOL)allowRetry {
    self.succeeded = NO;

    // call the completion blocks on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SGCacheFetchFail failBlock in self.onFailBlocks) {
            failBlock(error, !allowRetry);
        }
    });

    if (!allowRetry) {
        [self finish];
    }
}

- (void)willRetry {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SGCacheFetchOnRetry retryBlock in self.onRetryBlocks) {
            retryBlock();
        }
    });
}

- (void)finish {
    self.executing = NO;
    self.finished = YES;
}

- (void)cancel {
    if (self.isExecuting) {
        [self.request cancel];
        [self finish];
    }
    [super cancel];
}

#pragma mark - Equivalence

- (BOOL)matchesCacheKey:(NSString *)cacheKey {
    return [cacheKey isEqualToString:self.cacheKey];
}

#pragma mark - Setters

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setPromise:(SGCachePromise *)promise {
    _promise = promise;
    if (promise.onRetry) {
        [self addRetryBlock:promise.onRetry];
    }
    if (promise.onFail) {
        [self addFailBlock:promise.onFail];
    }
    if (self.request && self.currentErrorStatus) {
        [self failedWithError:self.currentErrorStatus allowRetry:self.currentErrorRetry];
        [self fetchRemoteFile];
    }
}

#pragma mark - Getters

- (NSArray *)completions {
    @synchronized (self) {
        return _completions.copy;
    }
}

- (NSArray *)onFailBlocks {
    @synchronized (self) {
        return _failBlocks.copy;
    }
}

- (NSArray *)onRetryBlocks {
    @synchronized (self) {
        return _retryBlocks.copy;
    }
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

- (BOOL)isConcurrent {
    return YES;
}

@end
