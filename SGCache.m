//
//  Created by matt on 7/05/15.
//

#import <MGEvents/MGEvents.h>
#import "SGCache.h"
#import "SGCacheTask.h"
#import "SGCachePrivate.h"

#define FOLDER_NAME @"SGCache"
#define MAX_RETRIES 5

SGImageCacheLogging gSGImageCacheLogging = SGImageCacheLogNothing;

void backgroundDo(void(^block)()) {
    if (NSThread.isMainThread) { // we're on the main thread. ew
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block();
        });
    } else { // we're already off the main thread. chillax
        block();
    }
}

@implementation SGCache

+ (SGCache *)cache {
    static SGCache *singleton;
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

+ (BOOL)haveFileForURL:(NSString *)url {
    return [self haveFileForURL:url requestHeaders:nil];
}

+ (BOOL)haveFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    if (![url isKindOfClass:NSString.class]) {
        return NO;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[self.cache pathForURL:url
          requestHeaders:requestHeaders]];
}

+ (NSData *)fileForURL:(NSString *)url {
    return [self fileForURL:url requestHeaders:nil];
}

+ (NSData *)fileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [NSData dataWithContentsOfFile:[self.cache pathForURL:url requestHeaders:headers]];
}

+ (PMKPromise *)getFileForURL:(NSString *)url {
    return [self getFileForURL:url requestHeaders:nil];
}

+ (PMKPromise *)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self getFileForURL:url requestHeaders:requestHeaders thenDo:^(NSData *data) {
            fulfill(data);
        }];
    }];
}

+ (PMKPromise *)slowGetFileForURL:(NSString *)url {
    return [self slowGetFileForURL:url requestHeaders:nil];
}

+ (PMKPromise *)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self slowGetFileForURL:url requestHeaders:requestHeaders thenDo:^(NSData *data) {
            fulfill(data);
        }];
    }];
}

+ (void)getFileForURL:(NSString *)url thenDo:(SGCacheFetchCompletion)completion {
    [self getFileForURL:url requestHeaders:nil thenDo:completion];
}

+ (void)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders
      thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *slowTask = [self existingSlowQueueTaskFor:url
              requestHeaders:requestHeaders];
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:url
              requestHeaders:requestHeaders];

        if (slowTask.isExecuting) { // reuse an executing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [fastTask cancel];
        } else if (fastTask) { // reuse a fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else { // add a fresh task to fast queue
            SGCacheTask *task = [self taskForURL:url requestHeaders:requestHeaders attempt:1];
            [task addCompletion:completion];
            [self.cache.fastQueue addOperation:task];
        }
    });
}

+ (void)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders
      thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *slowTask = [self existingSlowQueueTaskFor:url
              requestHeaders:requestHeaders];
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:url
              requestHeaders:requestHeaders];

        if (fastTask && !slowTask.isExecuting) { // reuse existing fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else if (slowTask) { // reuse existing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [fastTask cancel];
        } else { // add a fresh task to slow queue
            SGCacheTask *task = [self taskForURL:url requestHeaders:requestHeaders attempt:1];
            [task addCompletion:completion];
            [self.cache.slowQueue addOperation:task];
        }
    });
}

+ (void)moveTaskToSlowQueueForURL:(NSString *)url {
    [self moveTaskToSlowQueueForURL:url requestHeaders:nil];
}

+ (void)moveTaskToSlowQueueForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:url
              requestHeaders:requestHeaders];

        if (fastTask) {
            SGCacheTask *slowTask = [self existingSlowQueueTaskFor:url
                  requestHeaders:requestHeaders];

            if (slowTask) { // reuse an executing slow task
                [slowTask addCompletions:fastTask.completions];
            } else { // add a fresh task to slow queue
                SGCacheTask *task = [self taskForURL:url requestHeaders:requestHeaders
                      attempt:1];
                [task addCompletions:fastTask.completions];
                [self.cache.slowQueue addOperation:task];
            }
            [fastTask cancel];
        }
    });
}

+ (void)flushFilesOlderThan:(NSTimeInterval)age {
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
            NSDate *created = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil].fileCreationDate;

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

+ (void)addData:(NSData *)data forURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    [data writeToFile:[self.cache pathForURL:url requestHeaders:headers] atomically:YES];
}

#pragma mark - Task Factory

+ (SGCacheTask *)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders
      attempt:(int)attempt {
    SGCacheTask *task = [SGCacheTask taskForURL:url requestHeaders:requestHeaders attempt:attempt];
    __weak SGCacheTask *wTask = task;
    task.completionBlock = ^{
        if (!wTask.succeeded) {
            [SGCache taskFailed:wTask];
        }
    };
    return task;
}

#pragma mark - Task Finders

+ (SGCacheTask *)existingSlowQueueTaskFor:(NSString *)url requestHeaders:(NSDictionary *)headers {
    for (SGCacheTask *task in self.cache.slowQueue.operations) {
        if ([task matchesURL:url requestHeaders:headers]) {
            return task;
        }
    }
    return nil;
}

+ (SGCacheTask *)existingFastQueueTaskFor:(NSString *)url requestHeaders:(NSDictionary *)headers {
    for (SGCacheTask *task in self.cache.fastQueue.operations) {
        if ([task matchesURL:url requestHeaders:headers]) {
            return task;
        }
    }
    return nil;
}

#pragma mark - Fail Handle

+ (void)taskFailed:(SGCacheTask *)task {

    // too many retries?
    if (task.attempt >= MAX_RETRIES) {
        for (SGCacheFetchCompletion completion in task.completions) {
            completion(nil);
        }
        return;
    }

    // make and add a retry task
    SGCacheTask *retryTask = [self taskForURL:task.url requestHeaders:task.requestHeaders
          attempt:task.attempt + 1];
    [retryTask addCompletions:task.completions];
    [self.cache.fastQueue addOperation:retryTask];
}

#pragma mark - File and Memory Cache Setup

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

- (NSString *)hashForDictionary:(NSDictionary *)dict {
    NSMutableString *hash = [NSMutableString stringWithFormat:@"%@", @(dict.hash)];
    for (id key in dict) {
        [hash appendFormat:@"%@", @([key hash])];
        id value = dict[key];
        if ([value conformsToProtocol:@protocol(NSObject)]) {
            [hash appendFormat:@"%@", @([value hash])];
        }
    }
    return hash;
}

- (NSString *)pathForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    if (requestHeaders) {
        return [NSString stringWithFormat:@"%@/%@%@", self.cachePath, @(url.hash),
                                          [self hashForDictionary:requestHeaders]];
    } else {
        return [NSString stringWithFormat:@"%@/%@", self.cachePath, @(url.hash)];
    }
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

#pragma mark - Logging

+ (void)setLogging:(SGImageCacheLogging)logging {
    gSGImageCacheLogging = logging;
}

+ (SGImageCacheLogging)logging {
    return gSGImageCacheLogging;
}

@end

