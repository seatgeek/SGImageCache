//
//  Created by matt on 18/03/13.
//

#import "SGImageCache.h"
#import "SGImageCacheTask.h"
#import <MGEvents/MGEvents.h>

#define FOLDER_NAME @"generic_images_cache"
#define MAX_RETRIES 5

void backgroundDo(void(^block)()) {
    if (NSThread.isMainThread) { // we're on the main thread. ew
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            block();
        });
    } else { // we're already off the main thread. chillax
        block();
    }
}

@implementation SGImageCache

+ (SGImageCache *)cache {
    static SGImageCache *singleton;
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

- (id)init {
    self = [super init];
    self.folderName = FOLDER_NAME;
    self.cachePath = self.makeCachePath;
    [self slowQueue];
    [self fastQueue];
    return self;
}

#pragma mark - Public API

+ (BOOL)haveImageForURL:(NSString *)url {
    if (![url isKindOfClass:NSString.class]) {
        return NO;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[self.cache pathForURL:url]];
}

+ (UIImage *)imageForURL:(NSString *)url {
    if ([UIDevice.currentDevice.systemVersion hasPrefix:@"8"]) {
        return [UIImage imageNamed:[self.cache pathForURL:url]];
    } else {
        return [UIImage imageNamed:[self.cache relativePathForURL:url]];
    }
}

+ (void)getImageForURL:(NSString *)url thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = [self existingSlowQueueTaskFor:url];
        SGImageCacheTask *fastTask = [self existingFastQueueTaskFor:url];

        if (slowTask.isExecuting) { // reuse an executing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [fastTask cancel];
        } else if (fastTask) { // reuse a fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else { // add a fresh task to fast queue
            SGImageCacheTask *task = [self taskForURL:url attempt:1];
            [task addCompletion:completion];
            [self.cache.fastQueue addOperation:task];
        }
    });
}

+ (void)slowGetImageForURL:(NSString *)url thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = [self existingSlowQueueTaskFor:url];
        SGImageCacheTask *fastTask = [self existingFastQueueTaskFor:url];

        if (fastTask && !slowTask.isExecuting) { // reuse existing fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else if (slowTask) { // reuse existing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [fastTask cancel];
        } else { // add a fresh task to slow queue
            SGImageCacheTask *task = [self taskForURL:url attempt:1];
            [task addCompletion:completion];
            [self.cache.slowQueue addOperation:task];
        }
    });
}

+ (void)moveTaskToSlowQueueForURL:(NSString *)url {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = [self existingSlowQueueTaskFor:url];
        SGImageCacheTask *fastTask = [self existingFastQueueTaskFor:url];

        if (slowTask) { // reuse an executing slow task
            [slowTask addCompletions:fastTask.completions];
        } else { // add a fresh task to slow queue
            SGImageCacheTask *task = [self taskForURL:url attempt:1];
            [task addCompletions:fastTask.completions];
            [self.cache.slowQueue addOperation:task];
        }
        [fastTask cancel];
    });
}

+ (void)flushImagesOlderThan:(NSTimeInterval)age {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

        // let the queues finish, then suspend them
        [self.cache.slowQueue waitUntilAllOperationsAreFinished];
        self.cache.slowQueue.suspended = YES;
        [self.cache.fastQueue waitUntilAllOperationsAreFinished];
        self.cache.fastQueue.suspended = YES;

        NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.cache
              .cachePath error:nil];

        for (NSString *file in files) {
            if ([file isEqualToString:@"."] || [file isEqualToString:@".."]) {
                continue;
            }

            NSString *path = [self.cache.cachePath stringByAppendingPathComponent:file];
            NSDate *created = [NSFileManager.defaultManager attributesOfItemAtPath:path
                  error:nil].fileCreationDate;

            // too old. delete it
            if (-created.timeIntervalSinceNow > age) {
                [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            }
        }

        // let the queues run wild again
        self.cache.fastQueue.suspended = NO;
        self.cache.slowQueue.suspended = NO;
    });
}

+ (void)addImageData:(NSData *)data forURL:(NSString *)url {
    [data writeToFile:[self.cache pathForURL:url] atomically:YES];
}

#pragma mark - Task Factory

+ (SGImageCacheTask *)taskForURL:(NSString *)url attempt:(int)attempt {
    SGImageCacheTask *task = [SGImageCacheTask taskForURL:url attempt:attempt];
    __weak SGImageCacheTask *wTask = task;
    task.completionBlock = ^{
        if (!wTask.succeeded) {
            [SGImageCache taskFailed:wTask];
        }
    };
    return task;
}

#pragma mark - Task Finders

+ (SGImageCacheTask *)existingSlowQueueTaskFor:(NSString *)url {
    for (SGImageCacheTask *task in self.cache.slowQueue.operations) {
        if ([task.url isEqualToString:url]) {
            return task;
        }
    }
    return nil;
}

+ (SGImageCacheTask *)existingFastQueueTaskFor:(NSString *)url {
    for (SGImageCacheTask *task in self.cache.fastQueue.operations) {
        if ([task.url isEqualToString:url]) {
            return task;
        }
    }
    return nil;
}

#pragma mark - Fail Handle

+ (void)taskFailed:(SGImageCacheTask *)task {

    // too many retries?
    if (task.attempt >= MAX_RETRIES) {
        for (SGCacheFetchCompletion completion in task.completions) {
            completion(nil);
        }
        return;
    }

    // make and add a retry task
    SGImageCacheTask *retryTask = [self taskForURL:task.url attempt:task.attempt + 1];
    [retryTask addCompletions:task.completions];
    [self.cache.fastQueue addOperation:retryTask];
}

#pragma mark - Cache Setup

- (NSString *)makeCachePath {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,
          YES)[0];
    path = [path stringByAppendingFormat:@"/%@", self.folderName];

    // make the cache directory if necessary
    BOOL isDir;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir]) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO
              attributes:nil error:nil];
    }

    return path;
}

#pragma mark - Getters

- (NSString *)pathForURL:(NSString *)url {
    return [NSString stringWithFormat:@"%@/%@", self.cachePath, @(url.hash)];
}

- (NSString *)relativePathForURL:(NSString *)url {
    return [NSString stringWithFormat:@"../Library/Caches/%@/%@", self.folderName,
                                      @(url.hash)];
}

- (NSOperationQueue *)fastQueue {
    if (_fastQueue) {
        return _fastQueue;
    }

    _fastQueue = NSOperationQueue.new;

    // suspend slowQueue while fastQueue is active
    __weakSelf me = self;
    __weak NSOperationQueue *wQueue = _fastQueue;
    [_fastQueue onChangeOf:@"operationCount" do:^{
        me.slowQueue.suspended = !!wQueue.operationCount;
    }];

    return _fastQueue;
}

- (NSOperationQueue *)slowQueue {
    if (!_slowQueue) {
        _slowQueue = NSOperationQueue.new;
        _slowQueue.maxConcurrentOperationCount = 1;
    }
    return _slowQueue;
}

@end
