//
//  SGHTTPRequest.h
//  SeatGeek
//
//  Created by James Van-As on 31/07/13.
//  Copyright (c) 2013 SeatGeek. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGJSONSerialization.h"
#import "SGFileCache.h"

@class SGHTTPRequest;

typedef void (^SGHTTPResponseBlock)(SGHTTPRequest *req);
typedef void (^SGHTTPRetryBlock)(void);
typedef void (^SGHTTPProgressBlock)(double progress);

typedef NS_OPTIONS(NSInteger, SGHTTPRequestMethod) {
    SGHTTPRequestMethodGet,
    SGHTTPRequestMethodPost,
    SGHTTPRequestMethodDelete,
    SGHTTPRequestMethodPut,
    SGHTTPRequestMethodPatch,
    SGHTTPRequestMethodMultipartPost
};

typedef NS_OPTIONS(NSInteger, SGHTTPDataType) {
    SGHTTPDataTypeHTTP,
    SGHTTPDataTypeJSON,
    SGHTTPDataTypeXML
};

typedef NS_OPTIONS(NSInteger, SGHTTPLogging) {
    SGHTTPLogNothing    = 0,
    SGHTTPLogRequests   = 1 << 0,
    SGHTTPLogResponses  = 1 << 1,
    SGHTTPLogErrors     = 1 << 2,
    SGHTTPLogNullCleanses  = 1 << 3,
    SGHTTPLogCache      = 1 << 4,
    SGHTTPLogAll        = (SGHTTPLogRequests|SGHTTPLogResponses|SGHTTPLogErrors|SGHTTPLogNullCleanses|SGHTTPLogCache)
};

@interface SGHTTPRequest : NSObject

#pragma mark Request Creation

/** @name Request creation */

/**
* Returns a new GET request instance for the given URL.
*/
+ (instancetype)requestWithURL:(NSURL *)url;

/**
* Returns a new POST request instance for the given URL.
*/
+ (instancetype)postRequestWithURL:(NSURL *)url;

/**
* Returns a new POST request instance for the given URL, configured to send the
* POST <parameters> as a JSON string.
*/
+ (instancetype)jsonPostRequestWithURL:(NSURL *)url;

/**
* Returns a new DELETE request instance for the given URL.
*/
+ (instancetype)deleteRequestWithURL:(NSURL *)url;

/**
* Returns a new PUT request instance for the given URL.
*/
+ (instancetype)putRequestWithURL:(NSURL *)url;

/**
* Returns a new PATCH request instance for the given URL.
*/
+ (instancetype)patchRequestWithURL:(NSURL *)url;

/**
 * Returns a new multipart POST request instance for the given URL and parameters
 */
+ (instancetype)multiPartPostRequestWithURL:(NSURL *)url
                                       data:(NSData *)data
                                       name:(NSString *)name
                                   filename:(NSString *)filename
                                   mimeType:(NSString *)mimeType;

/**
* Returns a new POST request instance for the given URL, configured to send the
* POST <parameters> as an XML string.
*/
+ (instancetype)xmlPostRequestWithURL:(NSURL *)url;

/**
* Returns a new GET request instance for the given URL, configured to parse the
* response data as XML.
*/
+ (instancetype)xmlRequestWithURL:(NSURL *)url;

#pragma mark Starting and Stopping

/** @name Starting and Stopping */

- (void)start;
- (void)cancel;

#pragma mark State change callbacks

/** @name State change callbacks */

/**
* Called after request success. You can access the request's final <responseData>,
* <responseString>, and <statusCode> values in this block.
*/
@property (nonatomic, copy) SGHTTPResponseBlock onSuccess;

/**
* Called after request failure. You can access the request's final <responseData>,
* <responseString>, <statusCode>, and <error> values in this block.
*/
@property (nonatomic, copy) SGHTTPResponseBlock onFailure;

/**
 * Called as request upload progresses. Client code that needs to update a progress
 * view etc can use this.
 *
 * NOTE: May be called on background thread.
 */
@property (nonatomic, copy) SGHTTPProgressBlock onUploadProgress;

/**
 * Called as reponse download progresses.
 *
 * NOTE: May be called on background thread.
 */
@property (nonatomic, copy) SGHTTPProgressBlock onDownloadProgress;

/**
Called when a failed request's network resource becomes available again. This
allows for silent retries on unreliable network connections, eliminating the need
for manual 'Retry' buttons.

The easiest way to implement this is to contain your request code in a method,
and call back to that method in your `onNetworkReachable` block, thus firing off
a new identical request.

    - (void)requestThings {
        NSURL *url = [NSURL URLWithString:@"http://example.com/things"];

        // create a GET request
        SGHTTPRequest *req = [SGHTTPRequest requestWithURL:url];

        __weak typeof(self) me = self;

        req.onNetworkReachable = ^{
            [me requestThings];
        };

        // start the request in the background
        [req start];
    }
*/
@property (nonatomic, copy) SGHTTPRetryBlock onNetworkReachable;

#pragma mark Response data and errors

/** @name Response data and errors */

/**
* The raw response data for both successful and failed requests.
*/
- (NSData *)responseData;

/**
* The response string for both successful and failed requests.
*/
- (NSString *)responseString;

/**
* An NSDictionary or NSArray, assuming the response data is JSON.
*/
- (id)responseJSON;

/**
 * An NSDictionary containing the response headers.
 */
- (NSDictionary *)responseHeaders;

/**
* The HTTP status code for both successful and failed requests.
*/
- (NSInteger)statusCode;

/**
* An error object available on failed requests.
*/
- (NSError *)error;

#pragma mark Settings and Options

/** @name Settings and options */

/**
* The URL of the HTTP request
*/
@property (nonatomic, strong) NSURL *url;

/**
* A dictionary of POST fields and values to send with the request.
*/
@property (nonatomic, strong) NSDictionary *parameters;

/**
 * An optional dictionary of HTTP header fields and values to send with the request.
 */
@property (nonatomic, strong) NSDictionary *requestHeaders;

/**
* Whether to show the status bar network activity indicator or not. Default is YES.
*/
@property (nonatomic, assign) BOOL showActivityIndicator;

/**
* The HTTP request method (GET, POST, DELETE, PUT).
*/
@property (nonatomic, assign) SGHTTPRequestMethod method;

/**
* The format to use for request parameters (HTTP, JSON, XML).
*/
@property (nonatomic, assign) SGHTTPDataType requestFormat;

/**
* The format to expect and parse for response data (HTTP, JSON, XML).
*/
@property (nonatomic, assign) SGHTTPDataType responseFormat;

/**
 * Extracts the base URL from a given URL
 */
+ (NSString *)baseURLFrom:(NSURL *)url;

#pragma mark Null handling
/** @name Null handling */

/**
 * Global option to allow NSNull objects in json response dictionaries.
 * Default is YES.
 */
+ (void)setAllowNSNull:(BOOL)allow;

/**
 * Returns the global option to allow NSNull objects in json response dictionaries.
 * Default is YES
 */
+ (BOOL)allowNSNull;

/**
 * Whether to allow NSNull objects in json response dictionaries for this SGHTTPRequest object.
 * Defaults to SGHTTPRequest.allowNSNull
 */
@property (nonatomic, assign) BOOL allowNSNull;

#pragma mark Logging
/** @name Logging */

/**
* Optional per-request logging (defaults to global SGHTTPRequest logging setting)
*/
@property (nonatomic, assign) SGHTTPLogging logging;

/**
 * SGHTTP Request Logging (defaults to SGHTTPLogNothing.)  Logging is available for DEBUG builds only.
 */
+ (void)setLogging:(SGHTTPLogging)logging;

/**
 * SGHTTP Request Logging (defaults to SGHTTPLogNothing.)
 */
+ (SGHTTPLogging)logging;

#pragma mark ETag Caching
/** @name ETag Caching */

/**
 * Sets the default setting for whether new HTTP requests can be cached to disk.
 * This can be overridden with the `allowCacheToDisk` property on a
 * SGHTTPRequst object for per http request granularity.
 * Caching is based on the HTTP ETag.  Default is NO.
 */
+ (void)setAllowCacheToDisk:(BOOL)allowCacheToDisk;

/**
 * The default setting for whether new HTTP requests can be cached to disk.
 * Default is NO.
 */

+ (BOOL)allowCacheToDisk;

/**
 * Whether successful responses are allowed to be cached to disk.
 * Caching is based on the HTTP ETag.  Defaults to SGHTTPRequest.allowCacheToDisk
 */
@property (nonatomic, assign) BOOL allowCacheToDisk;

/**
 * Sets the maximum size for the ETag disk cache.  Defaults to 20MB.  For unlimited,
 * set to zero.
 */
+ (void)setMaxDiskCacheSize:(NSUInteger)megaBytes;

/**
 * Sets the default max-age of cached http responses for this HTTPRequest.
 * Defaults to SGHTTPRequest.defaultCacheMaxAge
 */
@property (nonatomic, assign) NSTimeInterval timeToExpire;

/**
 * Sets the default max-age of cached http responses.  
 * Defaults to 30 days (2592000 seconds)
 */
+ (void)setDefaultCacheMaxAge:(NSTimeInterval)timeToExpire;

/**
 * Clears the Etag disk cache completely.
 */
+ (void)clearCache;

/**
 * The HTTP ETag value (optional).  Can be used for response caching.
 * This is automatically used if the server responds with an ETag value.
 * If `allowCacheToDisk` is YES, then the response data will be cached
 * to disk and keyed by it's ETag.
 */
@property (nonatomic, strong) NSString *eTag;

/**
 * The cached raw response data for the current eTag. nil if no cached data.
 */
- (NSData *)cachedResponseData;

/**
 * The cached response JSON. nil if no cached data.
 */
- (id)cachedResponseJSON;

/**
 * Remove any cached response JSON for this request if it exists.
 */
- (void)removeCacheFiles;

/**
 * Remove any cached response JSON for this request if it has expired.
 * This is automatically called on each new request start.
 */
- (void)removeCacheFilesIfExpired;



@end
