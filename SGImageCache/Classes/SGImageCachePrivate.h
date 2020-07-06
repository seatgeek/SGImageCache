//
//  SGImageCachePrivate.h
//  Pods
//
//  Created by James Van-As on 30/06/15.
//
//

#ifndef Pods_SGImageCachePrivate_h
#define Pods_SGImageCachePrivate_h

@interface SGImageCache ()
+ (UIImage *)imageFromMemCacheForCacheKey:(NSString *)cacheKey;
+ (void)setImageInMemCache:(UIImage *)image forCacheKey:(NSString *)cacheKey;
@end

#endif
