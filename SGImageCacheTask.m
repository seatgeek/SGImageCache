//
//  Created by matt on 22/05/14.
//

#import "SGImageCacheTask.h"
#import "SGHTTPRequest.h"
#import "AFURLConnectionOperation.h"

@interface SGImageCacheTask ()
@property (nonatomic, strong) SGHTTPRequest *request;
@end

@implementation SGImageCacheTask {
    BOOL _isExecuting, _isFinished;
    NSMutableArray *_completions;
}

- (id)init {
    self = [super init];
    _completions = @[].mutableCopy;
    return self;
}

+ (instancetype)taskForURL:(NSString *)url attempt:(int)attempt {
    SGImageCacheTask *task = self.new;
    task.attempt = attempt;
    task.url = url;
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
    if ([SGImageCache haveImageForURL:self.url]) {
        [self completedWithImage:[SGImageCache imageForURL:self.url]];
    } else {
        [self fetchRemoteImage];
    }
}

- (void)fetchRemoteImage {
    self.request = [SGHTTPRequest requestWithURL:[NSURL URLWithString:self.url]];
    __weakSelf me = self;
    self.request.onSuccess = ^(SGHTTPRequest *req) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = [UIImage imageWithData:req.responseData];
            if (image) {
                [SGImageCache addImageData:req.responseData forURL:me.url];
                [me completedWithImage:image];
            } else {
                [me finish];
            }
        });
    };
    self.request.onNetworkReachable = ^{
        [me finish];
    };
    self.request.onFailure = ^(SGHTTPRequest *req) {
        id info = req.error.userInfo;
        NSInteger code = [info[AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
        if (code == 404) { // give up on 404
            [me completedWithImage:nil];
        } else { // let it fall through to a retry
            [me finish];
        }
    };
    [self.request start];
}

- (void)completedWithImage:(UIImage *)image {

    // force a decompress
    if (self.forceDecompress) {
        UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
        [image drawAtPoint:CGPointZero];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    // call the completion blocks on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SGCacheFetchCompletion completion in self.completions) {
            completion(image);
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
    return _completions;
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
