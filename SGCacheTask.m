//
//  Created by matt on 22/05/14.
//

#import "SGCacheTask.h"
#import "SGHTTPRequest.h"
#import "AFURLConnectionOperation.h"
#import "AFURLResponseSerialization.h"
#import "SGCachePrivate.h"

@interface SGCacheTask ()
@property (nonatomic, strong) SGHTTPRequest *request;
@end

@implementation SGCacheTask {
    BOOL _isExecuting, _isFinished;
    NSMutableArray *_completions;
}

- (id)init {
    self = [super init];
    _completions = @[].mutableCopy;
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

- (void)addCompletions:(NSArray *)completions {
    if (completions.count) {
        @synchronized (self) {
            [_completions addObjectsFromArray:completions];
        }
    }
}

- (void)start {
    self.executing = YES;
    if (self.isCancelled) {
        [self finish];
        return;
    }
    if (!self.remoteFetchOnly && [SGCache haveFileForURL:self.url]) {
        [self completedWithFile:[SGCache fileForURL:self.url]];
    } else {
        [self fetchRemoteFile];
    }
}

- (void)fetchRemoteFile {
    self.request = [SGHTTPRequest requestWithURL:[NSURL URLWithString:self.url]];
    self.request.responseFormat = SGHTTPDataTypeHTTP;
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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [me completedWithFile:req.responseData];
        });
    };
    self.request.onNetworkReachable = ^{
        [me fetchRemoteFile];
    };
    self.request.onFailure = ^(SGHTTPRequest *req) {
        id info = req.error.userInfo;
        NSInteger code = [info[AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
        if (code == 404) { // give up on 404
            [me completedWithFile:nil];
        } //else let it fall through to a retry
    };
    [self.request start];
}

- (void)completedWithFile:(NSData *)data {
    [SGCache addData:data forCacheKey:self.cacheKey];

    // call the completion blocks on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SGCacheFetchCompletion completion in self.completions) {
            completion(data);
        }
    });

    self.succeeded = YES;
    [self finish];
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

#pragma mark - Getters

- (NSArray *)completions {
    @synchronized (self) {
        return _completions.copy;
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
