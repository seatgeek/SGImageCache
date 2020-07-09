//
//  Created by matt on 18/03/13.
//

#import <UIKit/UIKit.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <PromiseKit/PromiseKit.h>
#pragma clang pop
#import "SGCache.h"

/**
`SGImageCache` provides a fast and simple disk and memory cache for images
fetched from remote URLs.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        me.imageView.image = image;
    }];
*/

@interface SGImageCache : SGCache

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
+ (nonnull SGCachePromise *)getImageForURL:(nonnull NSString *)url
NS_SWIFT_UNAVAILABLE("Use getImage(url:onReceive:) instead");

/**
Fetch an image from cache if available, or remote it not, sending HTTP headers
with the request. Returns a PromiseKit promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";
    NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

- If the URL is not already queued a new image fetch task will be added to
<fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
the promise will resolve when the existing task completes.
 */
+ (nonnull SGCachePromise *)getImageForURL:(nonnull NSString *)url requestHeaders:(nullable NSDictionary *)headers
NS_SWIFT_UNAVAILABLE("Use getImage(url:requestHeaders:onReceive:) instead");

/**
Fetch an image from cache if available, or remote it not, sending HTTP headers
with the request and providing an explicit cache key. Returns a PromiseKit
promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";
    NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
    NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

- If the URL is not already queued a new image fetch task will be added to
<fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
the promise will resolve when the existing task completes.
*/
+ (nonnull SGCachePromise *)getImageForURL:(nonnull NSString *)url
                            requestHeaders:(nonnull NSDictionary *)headers
                                  cacheKey:(nonnull NSString *)cacheKey
NS_SWIFT_UNAVAILABLE("Use getImage(url:requestHeaders:cacheKey:onReceive:) instead");

/**
 Fetch an image from remote. Returns a PromiseKit promise that resolves with
 a UIImage.

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
+ (nonnull SGCachePromise *)getRemoteImageForURL:(nonnull NSString *)url
NS_SWIFT_UNAVAILABLE("Use getRemoteImage(url:onReceive:) instead");

/**
 Fetch an image from remote, sending HTTP headers with the request.
 Returns a PromiseKit promise that resolves with a UIImage.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (nonnull SGCachePromise *)getRemoteImageForURL:(nonnull NSString *)url
                                  requestHeaders:(nullable NSDictionary *)headers
NS_SWIFT_UNAVAILABLE("Use getRemoteImage(url:requestHeaders:onReceive:) instead");

/**
 Fetch an image from remote, sending HTTP headers with the request and providing 
 an explicit cache key. Returns a PromiseKit promise that resolves with a UIImage.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
 NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (nonnull SGCachePromise *)getRemoteImageForURL:(nonnull NSString *)url
                                  requestHeaders:(nullable NSDictionary *)headers
                                        cacheKey:(nonnull NSString *)cacheKey
NS_SWIFT_UNAVAILABLE("Use getRemoteImage(url:requestHeaders:cacheKey:onReceive:) instead");

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
+ (nonnull SGCachePromise *)slowGetImageForURL:(nonnull NSString *)url
NS_SWIFT_UNAVAILABLE("Use slowGetImage(url:onReceive:) instead");

/**
Fetch an image from cache if available, or remote it not, sending HTTP headers
with the request. Returns a PromiseKit promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";
    NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

- If the URL is not already queued a new image fetch task will be added to
<slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
resolve when the existing task completes.
*/
+ (nonnull SGCachePromise *)slowGetImageForURL:(nonnull NSString *)url
                                requestHeaders:(nullable NSDictionary *)headers
NS_SWIFT_UNAVAILABLE("Use slowGetImage(url:requestHeaders:onReceive:) instead");

/**
Fetch an image from cache if available, or remote it not, sending HTTP headers
with the request and providing an explicit cache key. Returns a PromiseKit
promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";
    NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
    NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

- If the URL is not already queued a new image fetch task will be added to
<slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
resolve when the existing task completes.
*/
+ (nonnull SGCachePromise *)slowGetImageForURL:(nonnull NSString *)url
                                requestHeaders:(nullable NSDictionary *)headers
                                      cacheKey:(nonnull NSString *)cacheKey
NS_SWIFT_UNAVAILABLE("Use slowGetImage(url:requestHeaders:cacheKey:onReceive:) instead");

#pragma mark - House Keeping

/** @name House keeping */

/**
* Delete images from cache older than a specified age, based on the date at
* which the image was added to the cache.
*/
+ (void)flushImagesOlderThan:(NSTimeInterval)age;

/** @name Misc helpers */

/**
* Returns YES if the image is found in the cache.
*/
+ (BOOL)haveImageForURL:(nonnull NSString *)url;

/**
 * Returns YES if the image with matching URL and HTTP headers is found in the cache.
 */
+ (BOOL)haveImageForURL:(nonnull NSString *)url requestHeaders:(nullable NSDictionary *)headers;

/**
* Returns YES if the image is found in the cache.
*/
+ (BOOL)haveImageForCacheKey:(nonnull NSString *)cacheKey;

/**
* Retrieves an image from cache. Returns nil if the image is not found in
* the cache.
*
* @warning If you want a single method which will return an image from either
* cache or remote, use
* [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
*/
+ (nullable UIImage *)imageForURL:(nonnull NSString *)url;

/**
 * Retrieves an image  with matching URL and HTTP headers if found in the cache.
 * Returns nil if the image is not found in the cache.
 *
 * @warning If you want a single method which will return an image from either
 * cache or remote, use
 * [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
 */
+ (nullable UIImage *)imageForURL:(nonnull NSString *)url requestHeaders:(nullable NSDictionary *)headers;

/**
* Retrieves an imagewith matching cache key if found in the cache.
* Returns nil if the image is not found in the cache.
*
* @warning If you want a single method which will return an image from either
* cache or remote, use
* [getImageForURL:thenDo:](<+[SGImageCache getImageForURL:thenDo:]>) instead.
*/
+ (nullable UIImage *)imageForCacheKey:(nonnull NSString *)cacheKey;

/**
 * Retrieves an image from the cache or application asset bundle if not cached.
 */

+ (nullable UIImage *)imageNamed:(nonnull NSString *)named;

/**
 * Adds an image to the cache manually.  Useful for using images generated on
 * the device (eg. from the camera) which are then uploaded to the given url.
 */
+ (void)addImage:(nonnull UIImage *)image forURL:(nonnull NSString *)url;

/**
 * Removes an image from the cache manually.  Useful for forcing a fresh image
 * to be downloaded from the given url.
 */
+ (void)removeImageForURL:(nonnull NSString *)url;

#pragma - mark - Memory Cache

/** @name Memory Cache */

/**
 * Set Memory Cache Size in MB (defaults to 100MB)
 * This is not a hard limit and iOS will determine
 * periodically when and which items to purge from memory.
 */
+ (void)setMemoryCacheSize:(NSUInteger)megaBytes;

+ (nonnull NSCache *)globalMemCache;

@end

#pragma mark - Simple Interface for Swift

@interface SGImageCache (Simple)

#pragma mark - Fetching Images

/** @name Fetching images */

/**
 Fetch an image from cache if available, or remote it not.

 let url = "http://example.com/image.jpg"

 SGImageCache.getImage(url: url) { [weak self] image in
    self?.imageView.image = image
 }

 - If the url is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the url is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the url is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getImageForURL:(nonnull NSString *)url
             onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getImage(url:onReceive:));

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request.

 let url = "http://example.com/image.jpg"

 SGImageCache.getImage(url: url, requestHeaders: ["Authorization" : @"abcd1234"]) { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getImageForURL:(nonnull NSString *)url
        requestHeaders:(nullable NSDictionary *)headers
             onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getImage(url:requestHeaders:onReceive:));

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request and providing an explicit cache key.

 let url = "http://example.com/image.jpg"

 SGImageCache.getImage(url: url,
 requestHeaders: ["Authorization" : @"abcd1234"],
 cacheKey: "\(userID)") { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getImageForURL:(nonnull NSString *)url
        requestHeaders:(nullable NSDictionary *)headers
              cacheKey:(nonnull NSString *)cacheKey
             onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getImage(url:requestHeaders:cacheKey:onReceive:));

/**
 Fetch an image from remote.

 let url = "http://example.com/image.jpg"

 SGImageCache.getRemoteImage(url: url) { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getRemoteImageForURL:(nonnull NSString *)url
                   onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getRemoteImage(url:onReceive:));

/**
 Fetch an image from remote, sending HTTP headers with the request.

 let url = "http://example.com/image.jpg"

 SGImageCache.getRemoteImage(url: url, requestHeaders: ["Authorization" : @"abcd1234"]) { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getRemoteImageForURL:(nonnull NSString *)url
              requestHeaders:(nullable NSDictionary *)headers
                   onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getRemoteImage(url:requestHeaders:onReceive:));


/**
 Fetch an image from remote, sending HTTP headers with the request and providing
 an explicit cache key.

 let url = "http://example.com/image.jpg"

 SGImageCache.getRemoteImage(url: url,
 requestHeaders: ["Authorization" : @"abcd1234"],
 cacheKey: "\(userID)") { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (void)getRemoteImageForURL:(nonnull NSString *)url
              requestHeaders:(nullable NSDictionary *)headers
                    cacheKey:(nonnull NSString *)cacheKey
                   onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(getRemoteImage(url:requestHeaders:cacheKey:onReceive:));

/**
 Fetch an image from cache if available, or remote it not.

 let url = "http://example.com/image.jpg"

 SGImageCache.slowGetRemoteImage(url: url) { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <slowQueue>.
 - If the URL is already in either <slowQueue> or <fastQueue> the promise will
 resolve when the existing task completes.
 */
+ (void)slowGetImageForURL:(nonnull NSString *)url
                 onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(slowGetImage(url:onReceive:));

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request.

 let url = "http://example.com/image.jpg"

 SGImageCache.slowGetRemoteImage(url: url,
 requestHeaders: ["Authorization" : @"abcd1234"]) { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <slowQueue>.
 - If the URL is already in either <slowQueue> or <fastQueue> the promise will
 resolve when the existing task completes.
 */
+ (void)slowGetImageForURL:(nonnull NSString *)url
            requestHeaders:(nullable NSDictionary *)headers
                 onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(slowGetImage(url:requestHeaders:onReceive:));

/**
 Fetch an image from cache if available, or remote it not, sending HTTP headers
 with the request and providing an explicit cache key.

 let url = "http://example.com/image.jpg"

 SGImageCache.slowGetRemoteImage(url: url,
 requestHeaders: ["Authorization" : @"abcd1234"],
 cacheKey: "\(userID)") { [weak self] image in
 self?.imageView.image = image
 }

 - If the URL is not already queued a new image fetch task will be added to
 <slowQueue>.
 - If the URL is already in either <slowQueue> or <fastQueue> the promise will
 resolve when the existing task completes.
 */
+ (void)slowGetImageForURL:(nonnull NSString *)url
            requestHeaders:(nullable NSDictionary *)headers
                  cacheKey:(nonnull NSString *)cacheKey
                 onReceive:(void (^_Nonnull)(UIImage *_Nullable))onReceive
NS_SWIFT_NAME(slowGetImage(url:requestHeaders:cacheKey:onReceive:));

@end
