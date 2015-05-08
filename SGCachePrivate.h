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
- (NSString *)pathForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

+ (SGCacheTask *)existingFastQueueTaskFor:(NSString *)url requestHeaders:(NSDictionary *)headers;
+ (SGCacheTask *)existingSlowQueueTaskFor:(NSString *)url requestHeaders:(NSDictionary *)headers;
+ (void)addData:(NSData *)data forURL:(NSString *)url requestHeaders:(NSDictionary *)headers;
+ (void)taskFailed:(SGCacheTask *)task;

@end

#endif
