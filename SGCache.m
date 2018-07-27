//
//  Created by matt on 7/05/15.
//

#import <MGEvents/MGEvents.h>
#import "SGCache.h"
#import "SGCacheTask.h"
#import "SGCachePrivate.h"
#import "SGCachePromise.h"
#import "NSString+SGImageCacheHash.h"

#define FOLDER_NAME @"SGCache"
#define MAX_RETRIES 5

SGImageCacheLogging gSGImageCacheLogging = SGImageCacheLogNothing;

void backgroundDo(void(^block)(void)) {
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
    return [self haveFileForCacheKey:[self.cache cacheKeyFor:url requestHeaders:nil]];
}

+ (BOOL)haveFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [self haveFileForCacheKey:[self.cache cacheKeyFor:url requestHeaders:headers]];
}

+ (BOOL)haveFileForCacheKey:(NSString *)cacheKey {
    if (![cacheKey isKindOfClass:NSString.class]) {
        return NO;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[self.cache pathForCacheKey:cacheKey]];
}

+ (NSData *)fileForURL:(NSString *)url {
    return [NSData dataWithContentsOfFile:[self.cache pathForURL:url requestHeaders:nil]];
}

+ (NSData *)fileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [NSData dataWithContentsOfFile:[self.cache pathForURL:url requestHeaders:headers]];
}

+ (NSData *)fileForCacheKey:(NSString *)cacheKey {
    return [NSData dataWithContentsOfFile:[self.cache pathForCacheKey:cacheKey]];
}

+ (SGCachePromise *)getFileForURL:(NSString *)url {
    return [self getFileForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self getFileForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey {

    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
        [self getFileForURL:url requestHeaders:headers cacheKey:cacheKey remoteFetchOnly:NO
                     thenDo:^(NSData *data) {
                         fulfill(data);
                     } onFail:^(NSError *error, BOOL wasFatal) {
                         if (wasFatal) {
                             reject(error);
                         }
                     } promise:promise];
        });
    }];
    return promise;
}

+ (SGCachePromise *)getRemoteFileForURL:(NSString *)url {
    return [self getRemoteFileForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)getRemoteFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self getRemoteFileForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)getRemoteFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
                           cacheKey:(NSString *)cacheKey {
    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getFileForURL:url requestHeaders:headers cacheKey:cacheKey remoteFetchOnly:YES
                         thenDo:^(NSData *data) {
                             fulfill(data);
                         } onFail:^(NSError *error, BOOL wasFatal) {
                             if (wasFatal) {
                                 reject(error);
                             }
                         } promise:promise];
        });
    }];
    return promise;
}

+ (SGCachePromise *)slowGetFileForURL:(NSString *)url {
    return [self slowGetFileForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self slowGetFileForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey {
    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self slowGetFileForURL:url requestHeaders:headers cacheKey:cacheKey
                             thenDo:^(NSData *data) {
                                 fulfill(data);
                             } onFail:^(NSError *error, BOOL wasFatal) {
                                 if (wasFatal) {
                                     reject(error);
                                 }
                             } promise:promise];
        });
    }];
    return promise;
}

+ (void)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
             cacheKey:(NSString *)cacheKey remoteFetchOnly:(BOOL)remoteOnly
               thenDo:(SGCacheFetchCompletion)completion
               onFail:(SGCacheFetchFail)failBlock
              promise:(SGCachePromise *)promise {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *slowTask = [self existingSlowQueueTaskFor:cacheKey];
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:cacheKey];

        if (slowTask.isExecuting) { // reuse an executing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [slowTask addFailBlock:failBlock];
            [slowTask addFailBlocks:fastTask.onFailBlocks];
            slowTask.promise = promise;
            [fastTask cancel];
        } else if (fastTask) { // reuse a fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [fastTask addFailBlock:failBlock];
            [fastTask addFailBlocks:slowTask.onFailBlocks];
            fastTask.promise = promise;
            [slowTask cancel];
        } else { // add a fresh task to fast queue
            SGCacheTask *task = [self taskForURL:url requestHeaders:headers cacheKey:cacheKey
                  attempt:1];
            task.remoteFetchOnly = remoteOnly;
            [task addCompletion:completion];
            [task addFailBlock:failBlock];
            task.promise = promise;
            [self.cache.fastQueue addOperation:task];
        }
    });
}

+ (void)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders
      cacheKey:(NSString *)cacheKey thenDo:(SGCacheFetchCompletion)completion
                   onFail:(SGCacheFetchFail)failBlock
                  promise:(SGCachePromise *)promise {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *slowTask = [self existingSlowQueueTaskFor:cacheKey];
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:cacheKey];

        if (fastTask && !slowTask.isExecuting) { // reuse existing fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [fastTask addFailBlock:failBlock];
            [fastTask addFailBlocks:slowTask.onFailBlocks];
            fastTask.promise = promise;
            [slowTask cancel];
        } else if (slowTask) { // reuse existing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [slowTask addFailBlock:failBlock];
            [slowTask addFailBlocks:fastTask.onFailBlocks];
            slowTask.promise = promise;
            [fastTask cancel];
        } else { // add a fresh task to slow queue
            SGCacheTask *task = [self taskForURL:url requestHeaders:requestHeaders cacheKey:cacheKey
                  attempt:1];
            [task addCompletion:completion];
            [task addFailBlock:failBlock];
            task.promise = promise;
            [self.cache.slowQueue addOperation:task];
        }
    });
}

+ (void)moveTaskToSlowQueueForURL:(NSString *)url {
    [self moveTaskToSlowQueueForURL:url requestHeaders:nil];
}

+ (void)moveTaskToSlowQueueForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    [self moveTaskToSlowQueueForCacheKey:[self.cache cacheKeyFor:url requestHeaders:headers]];
}

+ (void)moveTaskToSlowQueueForCacheKey:(NSString *)cacheKey {
    if (![cacheKey isKindOfClass:NSString.class] || !cacheKey.length) {
        return;
    }

    backgroundDo(^{
        SGCacheTask *fastTask = [self existingFastQueueTaskFor:cacheKey];

        if (fastTask) {
            SGCacheTask *slowTask = [self existingSlowQueueTaskFor:cacheKey];

            if (slowTask) { // reuse an executing slow task
                [slowTask addCompletions:fastTask.completions];
            } else { // add a fresh task to slow queue
                SGCacheTask *task = [self taskForURL:fastTask.url
                      requestHeaders:fastTask.requestHeaders cacheKey:cacheKey attempt:1];
                [task addCompletions:fastTask.completions];
                [self.cache.slowQueue addOperation:task];
            }
            [fastTask cancel];
        }
    });
}

+ (void)flushFilesOlderThan:(NSTimeInterval)age {
    // let the queues finish, then suspend them    
    [self.cache.slowQueue waitUntilAllOperationsAreFinished];
    self.cache.slowQueue.suspended = YES;
    [self.cache.fastQueue waitUntilAllOperationsAreFinished];
    self.cache.fastQueue.suspended = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

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
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cache.fastQueue.suspended = NO;
            self.cache.slowQueue.suspended = NO;
        });
    });
}

+ (void)addData:(NSData *)data forCacheKey:(NSString *)cacheKey {
    [data writeToFile:[self.cache pathForCacheKey:cacheKey] atomically:YES];
}

+ (void)removeDataForCacheKey:(NSString *)cacheKey {
    NSString *path = [self.cache pathForCacheKey:cacheKey];
    if (path.length) {
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}

#pragma mark - Task Factory

+ (SGCacheTask *)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders
      cacheKey:(NSString *)cacheKey attempt:(int)attempt {
    SGCacheTask *task = [SGCacheTask taskForURL:url requestHeaders:requestHeaders cacheKey:cacheKey
          attempt:attempt];
    __weak SGCacheTask *wTask = task;
    task.completionBlock = ^{
        if (!wTask.succeeded) {
            [SGCache taskFailed:wTask];
        }
    };
    return task;
}

#pragma mark - Task Finders

+ (SGCacheTask *)existingSlowQueueTaskFor:(NSString *)cacheKey {
    for (SGCacheTask *task in self.cache.slowQueue.operations) {
        if ([task matchesCacheKey:cacheKey]) {
            return task;
        }
    }
    return nil;
}

+ (SGCacheTask *)existingFastQueueTaskFor:(NSString *)cacheKey {
    for (SGCacheTask *task in self.cache.fastQueue.operations) {
        if ([task matchesCacheKey:cacheKey]) {
            return task;
        }
    }
    return nil;
}

+ (SGCacheTask *)taskForPromise:(SGCachePromise *)promise {
    if (!promise) {
        return nil;
    }
    for (SGCacheTask *task in self.cache.fastQueue.operations) {
        if (promise == task.promise) {
            return task;
        }
    }
    for (SGCacheTask *task in self.cache.slowQueue.operations) {
        if (promise == task.promise) {
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
          cacheKey:nil attempt:task.attempt + 1];
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
        if ([value respondsToSelector:@selector(sgCacheHash)]) {
            [hash appendFormat:@"%@", [value sgCacheHash]];
        } else if ([value conformsToProtocol:@protocol(NSObject)]) {
            [hash appendFormat:@"%@", @([value hash])];
        }
    }
    return hash;
}

- (NSString *)pathForCacheKey:(NSString *)cacheKey {
    return [NSString stringWithFormat:@"%@/%@", self.cachePath, cacheKey.sgCacheHash];
}

- (NSString *)pathForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [self pathForCacheKey:[self cacheKeyFor:url requestHeaders:headers]];
}

- (NSString *)cacheKeyFor:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [NSString stringWithFormat:@"%@%@", url.sgCacheHash, [self hashForDictionary:headers]];
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

#pragma mark - Retry handling

+ (void)addRetryForPromise:(SGCachePromise *)promise retryBlock:(SGCacheFetchOnRetry)retry {
    SGCacheTask *task = [self taskForPromise:promise];
    [task addRetryBlock:retry];
}

+ (void)addFailForPromise:(SGCachePromise *)promise failBlock:(SGCacheFetchFail)failBlock {
    SGCacheTask *task = [self taskForPromise:promise];
    [task addFailBlock:failBlock];
}

#pragma mark - Logging

+ (void)setLogging:(SGImageCacheLogging)logging {
    gSGImageCacheLogging = logging;
}

+ (SGImageCacheLogging)logging {
    return gSGImageCacheLogging;
}

@end

