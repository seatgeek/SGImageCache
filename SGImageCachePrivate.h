//
//  SGImageCachePrivate.h
//  Pods
//
//  Created by James Van-As on 6/05/15.
//
//

#ifndef Pods_SGImageCachePrivate_h
#define Pods_SGImageCachePrivate_h

@interface SGImageCache ()
@property (atomic, copy) NSString *folderName;
@property (atomic, copy) NSString *cachePath;

+ (SGImageCache *)cache;
- (NSString *)makeCachePath;
- (NSString *)pathForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;
- (NSString *)relativePathForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;
+ (void)addImageData:(NSData *)data forURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;
@end

#endif
