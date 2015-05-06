//
//  Created by matt on 18/03/13.
//

#import <UIKit/UIKit.h>
#import <PromiseKit/PromiseKit.h>

typedef void(^SGCacheFetchCompletion)(UIImage *image);

typedef NS_OPTIONS(NSInteger, SGImageCacheLogging) {
    SGImageCacheLogNothing            = 0,
    SGImageCacheLogRequests           = 1 << 0,
    SGImageCacheLogResponses          = 1 << 1,
    SGImageCacheLogErrors             = 1 << 2,
    SGImageCacheLogMemoryFlushing     = 1 << 3,
    SGImageCacheLogAll                = (SGImageCacheLogRequests|SGImageCacheLogResponses|
                                         SGImageCacheLogErrors|SGImageCacheLogMemoryFlushing)
};

#ifndef __weakSelf
#define __weakSelf __weak typeof(self)
#endif

#define SGImageCacheFlushed @"SGImageCacheFlushed"

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
Returns a PromiseKit promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache getImageForURL:url].then(^(UIImage *image) {
        me.imageView.image = image;
    });

- If the URL is not already queued a new image fetch task will be added to
  <fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
  existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
  the promise will resolve when the existing task completes.
*/
+ (PMKPromise *)getImageForURL:(NSString *)url;

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request.
 Returns a PromiseKit promise that resolves with a UIImage.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

 */
+ (PMKPromise *)getImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

/**
Fetch an image from cache if available, or remote it not.
Returns a PromiseKit promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache slowGetImageForURL:url].then(^(UIImage *image) {
        me.imageView.image = image;
    });

- If the URL is not already queued a new image fetch task will be added to
  <slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
  resolve when the existing task completes.
*/
+ (PMKPromise *)slowGetImageForURL:(NSString *)url;

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request.
 Returns a PromiseKit promise that resolves with a UIImage.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"}; */
+ (PMKPromise *)slowGetImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

/**
* Move an image fetch task from <fastQueue> to <slowQueue>.
*/
+ (void)moveTaskToSlowQueueForURL:(NSString *)url;

/**
 * Move an image fetch task using http request headers from <fastQueue> to <slowQueue>.
 */
+ (void)moveTaskToSlowQueueForURL:(NSString *)url  requestHeaders:(NSDictionary *)requestHeaders;

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
 * Returns YES if the image with matching URL and HTTP headers is found in the cache.
 */
+ (BOOL)haveImageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

/**
* Retrieves an image from cache. Returns nil if the image is not found in
* the cache.
*
* @warning If you want a single method which will return an image from either
* cache or remote, use
* [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
*/
+ (UIImage *)imageForURL:(NSString *)url;


/**
 * Retrieves an image  with matching URL and HTTP headers is found in the cache.
 * Returns nil if the image is not found in the cache.
 *
 * @warning If you want a single method which will return an image from either
 * cache or remote, use
 * [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
 */

+ (UIImage *)imageForURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

/**
 * Retrieves an image from the cache or application asset bundle if not cached.
 */

+ (UIImage *)imageNamed:(NSString *)named;

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

#pragma - mark - Memory Cache

/** @name Memory Cache */

/**
 * Set Memory Cache Size in MB (defaults to 100MB)
 * This is not a hard limit and iOS will determine
 * periodically when and which items to purge from memory.
 */
+ (void)setMemoryCacheSize:(NSUInteger)megaBytes;

@end
