//
//  Created by matt on 7/05/15.
//

#import <UIKit/UIKit.h>
#import <PromiseKit/PromiseKit.h>

typedef void(^SGCacheFetchCompletion)(id obj);

typedef NS_OPTIONS(NSInteger, SGImageCacheLogging) {SGImageCacheLogNothing = 0,
    SGImageCacheLogRequests = 1 << 0,
    SGImageCacheLogResponses = 1 << 1,
    SGImageCacheLogErrors = 1 << 2,
    SGImageCacheLogMemoryFlushing = 1 << 3,
    SGImageCacheLogAll = (SGImageCacheLogRequests | SGImageCacheLogResponses | SGImageCacheLogErrors | SGImageCacheLogMemoryFlushing)};

#ifndef __weakSelf
#define __weakSelf __weak typeof(self)
#endif

#define SGCacheFlushed @"SGCacheFlushed"

/**
`SGCache` provides a fast and simple disk and memory cache for files
fetched from remote URLs.

NSString *url = @"http://example.com/image.jpg";

__weak typeof(self) me = self;
[SGCache getFileForURL:url].then(^(NSData *data) {
    // do stuff with the file
});
*/

@interface SGCache : NSObject

#pragma mark - Fetching Images

/** @name Fetching files */

/**
Fetch a file from cache if available, or remote it not.
Returns a PromiseKit promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";

__weak typeof(self) me = self;
[SGCache getFileForURL:url].then(^(NSData *data) {
    // do stuff with the file
});

- If the URL is not already queued a new file fetch task will be added to
<fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
the promise will resolve when the existing task completes.
*/
+ (PMKPromise *)getFileForURL:(NSString *)url;

/**
Fetch a file from cache if available, or remote it not, sending HTTP headers
with the request.
Returns a PromiseKit promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";
NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

- If the URL is not already queued a new file fetch task will be added to
<fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
the promise will resolve when the existing task completes.
*/
+ (PMKPromise *)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;

/**
Fetch a file from cache if available, or remote it not, sending HTTP headers
with the request and providing an explicit cache key. Returns a PromiseKit
promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";
NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

- If the URL is not already queued a new file fetch task will be added to
<fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the
existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
the promise will resolve when the existing task completes.
*/
+ (PMKPromise *)getFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey;


/**
 Fetch a file from remote it.
 Returns a PromiseKit promise that resolves with an NSData.

 NSString *url = @"http://example.com/image.jpg";

 __weak typeof(self) me = self;
 [SGCache getFileForURL:url].then(^(NSData *data) {
 // do stuff with the file
 });

 - If the URL is not already queued a new file fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (PMKPromise *)getRemoteFileForURL:(NSString *)url;


/**
 Fetch a file from remote, sending HTTP headers with the request.
 Returns a PromiseKit promise that resolves with an NSData.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

 - If the URL is not already queued a new file fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (PMKPromise *)getRemoteFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;


/**
 Fetch a file from remote, sending HTTP headers with the request and 
 providing an explicit cache key. Returns a PromiseKit promise that resolves 
 with an NSData.

 NSString *url = @"http://example.com/image.jpg";
 NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
 NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

 - If the URL is not already queued a new file fetch task will be added to
 <fastQueue>.
 - If the URL is already in <fastQueue> the promise will resolve when the
 existing task completes.
 - If the URL is already in <slowQueue> it will be moved to <fastQueue> and
 the promise will resolve when the existing task completes.
 */
+ (PMKPromise *)getRemoteFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
                           cacheKey:(NSString *)cacheKey;

/**
Fetch a file from cache if available, or remote it not.
Returns a PromiseKit promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";

__weak typeof(self) me = self;
[SGCache slowGetFileForURL:url].then(^(NSData *data) {
    // do stuff with the file
});

- If the URL is not already queued a new file fetch task will be added to
<slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
resolve when the existing task completes.
*/
+ (PMKPromise *)slowGetFileForURL:(NSString *)url;

/**
Fetch a file from cache if available, or remote it not, sending HTTP headers
with the request. Returns a PromiseKit promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";
NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};

- If the URL is not already queued a new file fetch task will be added to
<slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
resolve when the existing task completes.
*/
+ (PMKPromise *)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;

/**
Fetch a file from cache if available, or remote it not, sending HTTP headers
with the request and providing an explicit cache key. Returns a PromiseKit
promise that resolves with an NSData.

NSString *url = @"http://example.com/image.jpg";
NSDictionary *requestHeaders = @{@"Authorization" : @"abcd1234"};
NSStrig *cacheKey = [NSString stringWithFormat:@"%@%@", username, url];

- If the URL is not already queued a new file fetch task will be added to
<slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will
resolve when the existing task completes.
*/
+ (PMKPromise *)slowGetFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey;

/**
* Move an image fetch task from <fastQueue> to <slowQueue>.
*/
+ (void)moveTaskToSlowQueueForURL:(NSString *)url;

/**
* Move an image fetch task identified by URL and HTTP request headers from
* <fastQueue> to <slowQueue>.
*/
+ (void)moveTaskToSlowQueueForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;

/**
* Move an image fetch task identified by cache key from <fastQueue> to <slowQueue>.
*/
+ (void)moveTaskToSlowQueueForCacheKey:(NSString *)cacheKey;

#pragma mark - House Keeping

/** @name House keeping */

/**
* Delete files from cache older than a specified age, based on the date at
* which the file was added to the cache.
*/
+ (void)flushFilesOlderThan:(NSTimeInterval)age;

#pragma mark - Operation Queues

/** @name Operation queues */

/**
* The operation queue used for non urgent file fetches
* ([slowGetFileForURL:](<+[SGCache slowGetFileForURL:]>)).
* By default this is a serial queue.
*/
@property (nonatomic, strong) NSOperationQueue *slowQueue;

/**
* The operation queue used for urgent file fetches
* ([getFileForURL:](<+[SGCache getFileForURL:]>)). By
* default this queue uses the maximum number of concurrent operations as
* determined by iOS.
*/
@property (nonatomic, strong) NSOperationQueue *fastQueue;

/** @name Misc helpers */

/**
* Returns YES if the file is found in the cache.
*/
+ (BOOL)haveFileForURL:(NSString *)url;

/**
* Returns YES if the file with matching URL and HTTP headers is found in the cache.
*/
+ (BOOL)haveFileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;

/**
* Returns YES if the file is found in the cache.
*/
+ (BOOL)haveFileForCacheKey:(NSString *)cacheKey;

/**
* Retrieves a file from cache. Returns nil if the file is not found in
* the cache.
*
* @warning If you want a single method which will return a file from either
* cache or remote, use
* [getFileForURL:](<+[SGCache getFileForURL:]>) instead.
*/
+ (NSData *)fileForURL:(NSString *)url;

/**
* Retrieves a file with matching URL and HTTP headers if found in the cache.
* Returns nil if the file is not found in the cache.
*
* @warning If you want a single method which will return a file from either
* cache or remote, use
* [getFileForURL:](<+[SGCache getFileForURL:]>) instead.
*/

+ (NSData *)fileForURL:(NSString *)url requestHeaders:(NSDictionary *)headers;

/**
* Retrieves a file with matching cache key if found in the cache.
* Returns nil if the file is not found in the cache.
*
* @warning If you want a single method which will return a file from either
* cache or remote, use
* [getFileForURL:](<+[SGCache getFileForURL:]>) instead.
*/

+ (NSData *)fileForCacheKey:(NSString *)cacheKey;

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

+ (void)addData:(NSData *)data forCacheKey:(NSString *)cacheKey;

@end

