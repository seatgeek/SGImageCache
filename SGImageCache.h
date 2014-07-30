//
//  Created by matt on 18/03/13.
//

#import <UIKit/UIKit.h>

typedef void(^SGCacheFetchCompletion)(UIImage *image);

typedef NS_OPTIONS(NSInteger, SGImageCacheLogging) {
    SGImageCacheLogNothing    = 0,
    SGImageCacheLogRequests   = 1 << 0,
    SGImageCacheLogResponses  = 1 << 1,
    SGImageCacheLogErrors     = 1 << 2,
    SGImageCacheLogAll        = (SGImageCacheLogRequests|SGImageCacheLogResponses|SGImageCacheLogErrors)
};

#ifndef __weakSelf
#define __weakSelf __weak typeof(self)
#endif

/**
`SGImageCache` provides a fast and simple disk and memory cache for images
fetched from remote URLs.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        me.imageView.image = image;
    }];
*/

@interface SGImageCache : NSObject

#pragma mark - Fetching Images

/** @name Fetching images */

/**
Fetch an image from cache if available, or remote it not.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        me.imageView.image = image;
    }];

- If the URL is not already queued a new image fetch task will be added to
  <fastQueue>.
- If the URL is already in <fastQueue> the new completion block will be
  added to the existing task.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
  the new completion block will be added to the existing task.
*/
+ (void)getImageForURL:(NSString *)url thenDo:(SGCacheFetchCompletion)completion;

/**
Fetch an image from cache if available, or remote it not.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache slowGetImageForURL:url thenDo:^(UIImage *image) {
        me.imageView.image = image;
    }];

- If the URL is not already queued a new image fetch task will be added to
  <slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the new
  completion block will be added to the existing task.
*/
+ (void)slowGetImageForURL:(NSString *)url thenDo:(SGCacheFetchCompletion)completion;

/**
* Move an image fetch task from <fastQueue> to <slowQueue>.
*/
+ (void)moveTaskToSlowQueueForURL:(NSString *)url;

#pragma mark - House Keeping

/** @name House keeping */

/**
* Delete images from cache older than a specified age, based on the date at
* which the image was added to the cache.
*/
+ (void)flushImagesOlderThan:(NSTimeInterval)age;

#pragma mark - Operation Queues

/** @name Operation queues */

/**
* The operation queue used for non urgent image fetches
* ([slowGetImageForURL:thenDo:](<+[SGImageCache slowGetImageForURL:thenDo:]>)).
* By default this is a serial queue.
*/
@property (nonatomic, strong) NSOperationQueue *slowQueue;

/**
* The operation queue used for urgent image fetches
* ([getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>)). By
* default this queue uses the maximum number of concurrent operations as
* determined by iOS.
*/
@property (nonatomic, strong) NSOperationQueue *fastQueue;

/** @name Misc helpers */

/**
* Returns YES if the image is found in the cache.
*/
+ (BOOL)haveImageForURL:(NSString *)url;

/**
* Retrieves an image from cache. Returns nil if the image is not found in
* the cache.
*
* @warning If you want a single method which will return an image from either
* cache or remote, use
* [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
*/
+ (UIImage *)imageForURL:(NSString *)url;

#pragma - mark - Logging

/** @name Logging */

/**
* Set logging level (defaults to SGImageCacheLogNothing)
*/
+ (void)setLogging:(SGImageCacheLogging)logging;
/**
* Logging level (defaults to SGImageCacheLogNothing)
*/
+ (SGImageCacheLogging)logging;

#pragma mark - Ignore below here plz

@property (atomic, copy) NSString *folderName;
@property (atomic, copy) NSString *cachePath;

+ (SGImageCache *)cache;
- (NSString *)makeCachePath;
- (NSString *)pathForURL:(NSString *)url;
- (NSString *)relativePathForURL:(NSString *)url;
+ (void)addImageData:(NSData *)data forURL:(NSString *)url;

@end
