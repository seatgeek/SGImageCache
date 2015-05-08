//
//  Created by matt on 18/03/13.
//

#import <MGEvents/MGEvents.h>
#import "SGImageCache.h"
#import "SGImageCacheTask.h"
#import "SGCachePrivate.h"

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
    return [self haveImageForURL:url requestHeaders:nil];
}

+ (BOOL)haveImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    if (![url isKindOfClass:NSString.class]) {
        return NO;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[self.cache pathForURL:url requestHeaders:requestHeaders]];
}

+ (UIImage *)imageForURL:(NSString *)url {
    return [self imageForURL:url requestHeaders:nil];
}

+ (UIImage *)imageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers {
    UIImage *image = [self.globalMemCache objectForKey:url];
    if (image) {
        return image;
    }

    NSData *data = [NSData dataWithContentsOfFile:[self.cache pathForURL:url requestHeaders:headers]];
    image = [UIImage imageWithData:data];
    if (!image) {
        return nil;
    }

    // quickly guess rough byte size of the image
    int height = image.size.height,
    width = image.size.width;
    int bytesPerRow = 4 * width;
    if (bytesPerRow % 16) {
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
    }

    NSUInteger imageCost = height * bytesPerRow;
    [self.globalMemCache setObject:image forKey:url cost:imageCost];

    return image;
}

+ (UIImage *)imageNamed:(NSString *)name {
    UIImage *image = [self.globalMemCache objectForKey:name];
    if (image) {
        return image;
    }

    image = [UIImage imageNamed:name];
    if (!image) {
        return nil;
    }

    // quickly guess rough byte size of the image
    int height = image.size.height,
    width = image.size.width;
    int bytesPerRow = 4 * width;
    if (bytesPerRow % 16) {
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
    }

    NSUInteger imageCost = height * bytesPerRow;
    [self.globalMemCache setObject:image forKey:name cost:imageCost];
    
    return image;
}

+ (PMKPromise *)getImageForURL:(NSString *)url {
    return [self getImageForURL:url requestHeaders:nil];
}

+ (PMKPromise *)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self getImageForURL:url requestHeaders:requestHeaders thenDo:^(UIImage *image) {
            fulfill(image);
        }];
    }];
}

+ (PMKPromise *)slowGetImageForURL:(NSString *)url {
    return [self slowGetImageForURL:url requestHeaders:nil];
}

+ (PMKPromise *)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self slowGetImageForURL:url requestHeaders:requestHeaders thenDo:^(UIImage *image) {
            fulfill(image);
        }];
    }];
}

+ (void)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = (id)[self existingSlowQueueTaskFor:url requestHeaders:headers];
        SGImageCacheTask *fastTask = (id)[self existingFastQueueTaskFor:url requestHeaders:headers];

        if (slowTask.isExecuting) { // reuse an executing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            slowTask.forceDecompress = YES;
            [fastTask cancel];
        } else if (fastTask) { // reuse a fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else { // add a fresh task to fast queue
            SGImageCacheTask *task = (id)[self taskForURL:url requestHeaders:headers attempt:1];
            [task addCompletion:completion];
            task.forceDecompress = YES;
            [self.cache.fastQueue addOperation:task];
        }
    });
}

+ (void)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      thenDo:(SGCacheFetchCompletion)completion {
    if (![url isKindOfClass:NSString.class] || !url.length) {
        return;
    }

    backgroundDo(^{
        SGImageCacheTask *slowTask = (id)[self existingSlowQueueTaskFor:url requestHeaders:headers];
        SGImageCacheTask *fastTask = (id)[self existingFastQueueTaskFor:url requestHeaders:headers];

        if (fastTask && !slowTask.isExecuting) { // reuse existing fast task
            [fastTask addCompletion:completion];
            [fastTask addCompletions:slowTask.completions];
            [slowTask cancel];
        } else if (slowTask) { // reuse existing slow task
            [slowTask addCompletion:completion];
            [slowTask addCompletions:fastTask.completions];
            [fastTask cancel];
        } else { // add a fresh task to slow queue
            SGImageCacheTask *task = (id)[self taskForURL:url requestHeaders:headers attempt:1];
            [task addCompletion:completion];
            [self.cache.slowQueue addOperation:task];
        }
    });
}

+ (void)flushImagesOlderThan:(NSTimeInterval)age {
    [self flushFilesOlderThan:age];
}

#pragma mark - Task Factory

+ (SGImageCacheTask *)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      attempt:(int)attempt {
    SGImageCacheTask *task = [SGImageCacheTask taskForURL:url requestHeaders:headers
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
    });
    return globalCache;
}

@end
