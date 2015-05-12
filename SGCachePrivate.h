//
//  SGCachePrivate.h
//  Pods
//
//  Created by James Van-As on 6/05/15.
//
//

#ifndef Pods_SGImageCachePrivate_h
#define Pods_SGImageCachePrivate_h

void backgroundDo(void(^block)());

@class SGCacheTask;

@interface SGCache ()

@property (atomic, copy) NSString *folderName;
@property (atomic, copy) NSString *cachePath;

+ (SGCache *)cache;

- (NSString *)makeCachePath;
- (NSString *)pathForCacheKey:(NSString *)cacheKey;
- (NSString *)pathForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;
- (NSString *)cacheKeyFor:(NSString *)url requestHeaders:(NSDictionary *)headers;

+ (SGCacheTask *)existingSlowQueueTaskFor:(NSString *)cacheKey;
+ (SGCacheTask *)existingFastQueueTaskFor:(NSString *)cacheKey;
+ (void)taskFailed:(SGCacheTask *)task;

@end

#endif
