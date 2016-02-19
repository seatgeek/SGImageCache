//
//  Created by matt on 18/03/13.
//

#import <MGEvents/MGEvents.h>
#import "SGImageCache.h"
#import "SGImageCacheTask.h"
#import "SGCachePrivate.h"
#import "SGCachePromise.h"
#import "SGImageCachePrivate.h"

#define FOLDER_NAME @"SGImageCache"
#define MAX_RETRIES 5

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
    return [self haveFileForURL:url];
}

+ (BOOL)haveImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    return [self haveFileForURL:url requestHeaders:headers];
}

+ (BOOL)haveImageForCacheKey:(NSString *)cacheKey {
    return [self haveFileForCacheKey:cacheKey];
}

+ (UIImage *)imageForURL:(NSString *)url {
    return [self imageForURL:url requestHeaders:nil];
}

+ (UIImage *)imageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self imageForCacheKey:cacheKey];
}

+ (UIImage *)imageForCacheKey:(NSString *)cacheKey {
    UIImage *image = [self imageFromMemCacheForCacheKey:cacheKey];
    if (image) {
        return image;
    }

    NSData *data = [NSData dataWithContentsOfFile:[self.cache pathForCacheKey:cacheKey]];
    image = [UIImage imageWithData:data];
    if (!image) {
        return nil;
    }

    [self setImageInMemCache:image forCacheKey:cacheKey];
    return image;
}

+ (UIImage *)imageNamed:(NSString *)name {
    UIImage *image = [self imageFromMemCacheForCacheKey:name];
    if (image) {
        return image;
    }

    image = [UIImage imageNamed:name];
    if (!image) {
        return nil;
    }

    [self setImageInMemCache:image forCacheKey:name];
    return image;
}

+ (void)addImage:(UIImage *)image forURL:(NSString *)url {
    int height = image.size.height,
    width = image.size.width;
    int bytesPerRow = 4 * width;
    if (bytesPerRow % 16) {
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
    }
    NSUInteger imageCost = height * bytesPerRow;
    NSString *cacheKey = [self.cache cacheKeyFor:url requestHeaders:nil];
    [self.globalMemCache setObject:image forKey:cacheKey cost:imageCost];
    NSData *data = UIImagePNGRepresentation(image);
    [SGImageCache addData:data forCacheKey:cacheKey];
}

+ (void)removeImageForURL:(NSString *)url {
    NSString *cacheKey = [self.cache cacheKeyFor:url requestHeaders:nil];
    [self setImageInMemCache:nil forCacheKey:cacheKey];
    [SGImageCache removeDataForCacheKey:cacheKey];
}

+ (SGCachePromise *)getImageForURL:(NSString *)url {
    return [self getImageForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self getImageForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey {
    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getImageForURL:url requestHeaders:headers cacheKey:cacheKey remoteFetchOnly:NO
                          thenDo:^(UIImage *image) {
                              fulfill(image);
                          } onFail:^(NSError *error, BOOL wasFatal) {
                              if (wasFatal) {
                                  reject(error);
                              }
                          } promise:promise];
        });
    }];
    return promise;
}

+ (SGCachePromise *)getRemoteImageForURL:(NSString *)url {
    return [self getRemoteImageForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)getRemoteImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self getRemoteImageForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)getRemoteImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
                            cacheKey:(NSString *)cacheKey {
    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getImageForURL:url requestHeaders:headers cacheKey:cacheKey remoteFetchOnly:YES
                          thenDo:^(UIImage *image) {
                              fulfill(image);
                          } onFail:^(NSError *error, BOOL wasFatal) {
                              if (wasFatal) {
                                  reject(error);
                              }
                          } promise:promise];
        });
    }];
    return promise;
}

+ (SGCachePromise *)slowGetImageForURL:(NSString *)url {
    return [self slowGetImageForURL:url requestHeaders:nil];
}

+ (SGCachePromise *)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    id cacheKey = [self.cache cacheKeyFor:url requestHeaders:headers];
    return [self slowGetImageForURL:url requestHeaders:headers cacheKey:cacheKey];
}

+ (SGCachePromise *)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey {
    __block SGCachePromise *promise = [SGCachePromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        dispatch_async(dispatch_get_main_queue(), ^{
        [self slowGetImageForURL:url requestHeaders:headers cacheKey:cacheKey
              thenDo:^(UIImage *image) {
                  fulfill(image);
              } onFail:^(NSError *error, BOOL wasFatal) {
                  if (wasFatal) {
                      reject(error);
                  }
              } promise:promise];
        });
    }];
    return promise;
}

+ (void)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey remoteFetchOnly:(BOOL)remoteOnly
                thenDo:(SGCacheFetchCompletion)completion
                onFail:(SGCacheFetchFail)failBlock
               promise:(SGCachePromise *)promise {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = (id)[self existingSlowQueueTaskFor:cacheKey];
        SGImageCacheTask *fastTask = (id)[self existingFastQueueTaskFor:cacheKey];

        if (slowTask.isExecuting) { // reuse an executing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [slowTask addFailBlock:failBlock];
            [slowTask addFailBlocks:fastTask.onFailBlocks];
            slowTask.forceDecompress = YES;
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
            SGImageCacheTask *task = (id)[self taskForURL:url requestHeaders:headers
                  cacheKey:cacheKey attempt:1];
            task.remoteFetchOnly = remoteOnly;
            [task addCompletion:completion];
            [task addFailBlock:failBlock];
            task.promise = promise;
            task.forceDecompress = YES;
            [self.cache.fastQueue addOperation:task];
        }
    });
}

+ (void)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey thenDo:(SGCacheFetchCompletion)completion
                    onFail:(SGCacheFetchFail)failBlock
                   promise:(SGCachePromise *)promise {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = (id)[self existingSlowQueueTaskFor:cacheKey];
        SGImageCacheTask *fastTask = (id)[self existingFastQueueTaskFor:cacheKey];

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
            SGImageCacheTask *task = (id)[self taskForURL:url requestHeaders:headers
                  cacheKey:cacheKey attempt:1];
            [task addCompletion:completion];
            [task addFailBlock:failBlock];
            task.promise = promise;
            [self.cache.slowQueue addOperation:task];
        }
    });
}

+ (void)flushImagesOlderThan:(NSTimeInterval)age {
    [self flushFilesOlderThan:age];
}

#pragma mark - Private

+ (UIImage *)imageFromMemCacheForCacheKey:(NSString *)cacheKey {
    return [self.globalMemCache objectForKey:cacheKey];
}

+ (void)setImageInMemCache:(UIImage *)image forCacheKey:(NSString *)cacheKey {
    if (!image) {
        [self.globalMemCache removeObjectForKey:cacheKey];
        return;
    }
    // quickly guess rough byte size of the image
    int height = image.size.height, width = image.size.width;
    int bytesPerRow = 4 * width;
    if (bytesPerRow % 16) {
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
    }
    NSUInteger imageCost = height * bytesPerRow;
    [self.globalMemCache setObject:image forKey:cacheKey cost:imageCost];
}

#pragma mark - Task Factory

+ (SGCacheTask *)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey attempt:(int)attempt {
    SGImageCacheTask *task = [SGImageCacheTask taskForURL:url requestHeaders:headers cacheKey:cacheKey
          attempt:attempt];
    __weak SGImageCacheTask *wTask = task;
    task.completionBlock = ^{
        if (!wTask.succeeded) {
            [SGImageCache taskFailed:wTask];
        }
    };
    return task;
}

+ (void)setMemoryCacheSize:(NSUInteger)megaBytes {
    self.globalMemCache.totalCostLimit = megaBytes * 1000000;
}

+ (NSCache *)globalMemCache {
    static NSCache *globalCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if !TARGET_OS_WATCH
        globalCache = NSCache.new;
        globalCache.totalCostLimit = 100000000;  // 100 MB ish
        [NSNotificationCenter.defaultCenter
             addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
             object:nil
             queue:[NSOperationQueue mainQueue]
             usingBlock:^(NSNotification *note) {
                 // attempt to flush the cache, and then reactivate it some-time later
                 NSInteger costLimit = globalCache.totalCostLimit;
                 globalCache.totalCostLimit = 1;
                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                     globalCache.totalCostLimit = costLimit;
                 });
                 [SGImageCache trigger:SGCacheFlushed];
             }];
#else
        globalCache = NSCache.new;
        globalCache.totalCostLimit = 10000000;  // 10 MB ish
#endif
    });
    return globalCache;
}

@end
