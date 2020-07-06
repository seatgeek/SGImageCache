//
//  SGHTTPRequest.m
//  SeatGeek
//
//  Created by James Van-As on 31/07/13.
//  Copyright (c) 2013 SeatGeek. All rights reserved.
//

#ifndef TARGET_OS_IOS
#undef SG_INCLUDE_UIKIT
#endif

#import "SGHTTPRequest.h"
#import <AFNetworking/AFURLResponseSerialization.h>
#import <AFNetworking/AFHTTPSessionManager.h>
#ifdef SG_INCLUDE_UIKIT
#import "SGActivityIndicator.h"
#endif
#import "SGHTTPRequestDebug.h"
#import "NSString+SGHTTPRequest.h"
#import <SGHTTPRequest/SGFileCache.h>
#import "MGEvents.h"

#define SGETag              @"eTag"

NSMutableDictionary *gSessionManagers;
NSMutableDictionary *gReachabilityManagers;
#ifdef SG_INCLUDE_UIKIT
SGActivityIndicator *gNetworkIndicator;
#endif
NSMutableDictionary *gRetryQueues;
SGHTTPLogging gLogging = SGHTTPLogNothing;

@interface SGHTTPRequest ()
@property (nonatomic, weak) NSURLSessionDataTask *sessionTask;
@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, strong) NSString *responseString;
@property (nonatomic, strong) NSDictionary *responseHeaders;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) BOOL cancelled;

@property (nonatomic, strong) NSData *multiPartData;
@property (nonatomic, strong) NSString *multiPartName;
@property (nonatomic, strong) NSString *multiPartFilename;
@property (nonatomic, strong) NSString *multiPartMimeType;
@end

void doOnMain(void(^block)(void)) {
    if (NSThread.isMainThread) { // we're on the main thread. yay
        block();
    } else { // we're off the main thread. Bump off.
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
}

@implementation SGHTTPRequest

#pragma mark - Public

+ (SGHTTPRequest *)requestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url method:SGHTTPRequestMethodGet];
}

+ (instancetype)postRequestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url method:SGHTTPRequestMethodPost];
}

+ (instancetype)jsonPostRequestWithURL:(NSURL *)url {
    SGHTTPRequest *request = [[self alloc] initWithURL:url method:SGHTTPRequestMethodPost];
    request.requestFormat = SGHTTPDataTypeJSON;
    return request;
}

+ (instancetype)deleteRequestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url method:SGHTTPRequestMethodDelete];
}

+ (instancetype)putRequestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url method:SGHTTPRequestMethodPut];
}

+ (instancetype)patchRequestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url method:SGHTTPRequestMethodPatch];
}

+ (instancetype)multiPartPostRequestWithURL:(NSURL *)url
                                       data:(NSData *)data
                                       name:(NSString *)name
                                   filename:(NSString *)filename
                                   mimeType:(NSString *)mimeType {
    SGHTTPRequest *request = [[self alloc] initWithURL:url method:SGHTTPRequestMethodMultipartPost];
    request.multiPartData = data;
    request.multiPartName = name;
    request.multiPartFilename = filename;
    request.multiPartMimeType = mimeType;
    return request;
}

+ (instancetype)xmlPostRequestWithURL:(NSURL *)url {
    SGHTTPRequest *request =  [[self alloc] initWithURL:url method:SGHTTPRequestMethodPut];
    request.requestFormat = SGHTTPDataTypeXML;
    return request;
}

+ (instancetype)xmlRequestWithURL:(NSURL *)url {
    SGHTTPRequest *request =  [[self alloc] initWithURL:url method:SGHTTPRequestMethodGet];
    request.responseFormat = SGHTTPDataTypeXML;
    return request;
}

- (void)start {
    if (!self.url) {
        return;
    }

    NSString *baseURL = [SGHTTPRequest baseURLFrom:self.url];

    if (self.logRequests) {
        NSLog(@"%@", self.url);
    }

    AFHTTPSessionManager *manager = [self.class managerForBaseURL:baseURL];

    if (!manager) {
        [self failedWithError:nil task:nil retryURL:baseURL];
        return;
    }

    [self removeCacheFilesIfExpired];

    @synchronized(manager) {
        switch (self.requestFormat) {
            case SGHTTPDataTypeXML:
                manager.requestSerializer = AFHTTPRequestSerializer.serializer;
                [manager.requestSerializer setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
                break;
            case SGHTTPDataTypeJSON:
                manager.requestSerializer = AFJSONRequestSerializer.serializer;
                break;
            default:
                manager.requestSerializer = AFHTTPRequestSerializer.serializer;
                break;
        }

        for (NSString *field in self.requestHeaders) {
            [manager.requestSerializer setValue:self.requestHeaders[field] forHTTPHeaderField:field];
        }

        if (self.eTag.length && ![self.eTag isEqualToString:@"Missing"]) {
            [manager.requestSerializer setValue:self.eTag forHTTPHeaderField:@"If-None-Match"];

            // The iOS URL loading system by default does local caching. If it receives a 304 back,
            // it brings in the most previously cached body for that URL, updates our status code to 200,
            // but seems to keep the other headers from the 304. Unfortunately this means that we get our
            // current eTag back in the headers with the most recent 200 response body, if that previous
            // response lacked an eTag and was not related. So we need to turn off the iOS URL loading system
            // local caching when we are doing our own eTag caching. That way our eTag caching code in -success:
            // can get our 304 responses back undoctored. Local caching will be taken care of by our code.
            manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        } else {
            [manager.requestSerializer setValue:nil forHTTPHeaderField:@"If-None-Match"];
            manager.requestSerializer.cachePolicy = NSURLRequestUseProtocolCachePolicy;
        }

        id success = ^(NSURLSessionTask *task, id responseObject) {
            NSString *contentType = ((NSHTTPURLResponse*)task.response).MIMEType;
            NSString *errorUserInfoReason;

            BOOL noContent;
            switch (((NSHTTPURLResponse*)task.response).statusCode) {
                case 204:
                case 205:
                    noContent = YES;
                    break;
                default:
                    noContent = NO;
            }            
            if (noContent) {
                responseObject = nil;   // AFNetworking returns a silly 
            } else {
                // check that we got the correct content type.
                switch (self.responseFormat) {
                    case SGHTTPDataTypeJSON:
                        if (![AFJSONResponseSerializer.serializer.acceptableContentTypes containsObject:contentType]) {
                            errorUserInfoReason = [NSString stringWithFormat:@"Expected SGHTTPDataTypeJSON but received %@.", contentType];
                        }
                        break;
                    case SGHTTPDataTypeXML:
                        if (![AFXMLParserResponseSerializer.serializer.acceptableContentTypes containsObject:contentType]) {
                            errorUserInfoReason = [NSString stringWithFormat:@"Expected SGHTTPDataTypeXML but received %@.", contentType];
                        }
                        break;
                    default:  // SGHTTPDataTypeHTTP, anything goes
                        break;
                }
            }
            if (errorUserInfoReason) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: NSLocalizedString(@"Unexpected Content-Type", nil),
                    NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorUserInfoReason, nil),
                    NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Ensure the client is requesting the Content-Type sent by the server.", nil)
                };
                NSError *error = [NSError errorWithDomain:AFURLResponseSerializationErrorDomain  // the same domain/code used by AFNetworking
                                                     code:NSURLErrorCannotDecodeContentData
                                                 userInfo:userInfo];
                [self failedWithError:error task:task retryURL:baseURL];
            } else {
                [self success:task responseObject:responseObject];
            }
        };
        id failure = ^(NSURLSessionTask *task, NSError *error) {
            if (((NSHTTPURLResponse*)task.response).statusCode == 304) { // not modified
                [self success:task responseObject:nil];
            } else {
                [self failedWithError:error task:task retryURL:baseURL];
            }
        };

        switch (self.method) {
            case SGHTTPRequestMethodGet:
                _sessionTask = [manager GET:self.url.absoluteString parameters:self.parameters
                                        progress:nil success:success failure:failure];
                break;
            case SGHTTPRequestMethodPost:
                _sessionTask = [manager POST:self.url.absoluteString parameters:self.parameters
                                        progress:nil success:success failure:failure];
                break;
            case SGHTTPRequestMethodMultipartPost:
                {
                __weak SGHTTPRequest *me = self;
                _sessionTask = [manager POST:self.url.absoluteString parameters:self.parameters
                   constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                       [formData appendPartWithFileData:me.multiPartData
                                                   name:me.multiPartName
                                               fileName:me.multiPartFilename
                                               mimeType:me.multiPartMimeType];
                   } progress:nil success:success failure:failure];
                 }
                break;
            case SGHTTPRequestMethodDelete:
                _sessionTask = [manager DELETE:self.url.absoluteString
                                        parameters:self.parameters success:success failure:failure];
                break;
            case SGHTTPRequestMethodPut:
                _sessionTask = [manager PUT:self.url.absoluteString
                                        parameters:self.parameters success:success failure:failure];
                break;
            case SGHTTPRequestMethodPatch:
                _sessionTask = [manager PATCH:self.url.absoluteString
                                        parameters:self.parameters success:success failure:failure];
                break;
        }
    }

    __weak typeof(self) me = self;
    if (self.onUploadProgress) {
        NSProgress *progress = [manager uploadProgressForTask:_sessionTask];
        __weak NSProgress *wProgress = progress;
        [progress onChangeOf:@"fractionCompleted" do:^{
            me.onUploadProgress(wProgress.fractionCompleted);
        }];
    }
    if (self.onDownloadProgress) {
        NSProgress *progress = [manager downloadProgressForTask:_sessionTask];
        __weak NSProgress *wProgress = progress;
        [progress onChangeOf:@"fractionCompleted" do:^{
            me.onDownloadProgress(wProgress.fractionCompleted);
        }];
    }

#ifdef SG_INCLUDE_UIKIT
    if (self.showActivityIndicator) {
        [SGHTTPRequest.networkIndicator incrementActivityCount];
    }
#endif
}

- (void)cancel {
    _cancelled = YES;

    doOnMain(^{
        if (self.onNetworkReachable) {
           [SGHTTPRequest removeRetryCompletion:self.onNetworkReachable forHost:self.url.host];
            self.onNetworkReachable = nil;
        }
        [self->_sessionTask cancel]; // will call the failure block
    });
}

#pragma mark - Private

- (id)initWithURL:(NSURL *)url method:(SGHTTPRequestMethod)method {
    self = [super init];

    self.showActivityIndicator = YES;
    self.allowCacheToDisk = SGHTTPRequest.allowCacheToDisk;
    self.timeToExpire = SGHTTPRequest.defaultCacheMaxAge;
    self.allowNSNull = SGHTTPRequest.allowNSNull;
    self.method = method;
    self.url = url;

    // by default, use the JSON response serialiser only for SeatGeek API requests
    if ([url.host isEqualToString:@"api.seatgeek.com"]) {
        self.responseFormat = SGHTTPDataTypeJSON;
    } else {
        self.responseFormat = SGHTTPDataTypeHTTP;
    }
    self.logging = SGHTTPRequest.logging;

    return self;
}

+ (AFHTTPSessionManager *)managerForBaseURL:(NSString *)baseURL {
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        gSessionManagers = NSMutableDictionary.new;
        gReachabilityManagers = NSMutableDictionary.new;
    });

    AFHTTPSessionManager *manager;
    NSURL *url = [NSURL URLWithString:baseURL];

    @synchronized(self) {
        manager = gSessionManagers[baseURL];
        if (!manager) {
            manager = [[AFHTTPSessionManager alloc] initWithBaseURL:url];
            if (manager) {
                NSArray *responseSerializers = @[AFJSONResponseSerializer.serializer,
                                                 AFXMLParserResponseSerializer.serializer,
                                                 AFHTTPResponseSerializer.serializer];
                manager.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:responseSerializers];
                gSessionManagers[baseURL] = manager;
            } else {
                return nil;
            }
        }
#if !TARGET_OS_WATCH
        if (url.host.length && !gReachabilityManagers[url.host]) {
            AFNetworkReachabilityManager *reacher = [AFNetworkReachabilityManager managerForDomain:url
                  .host];
            if (reacher) {
                gReachabilityManagers[url.host] = reacher;

                reacher.reachabilityStatusChangeBlock = ^(AFNetworkReachabilityStatus status) {
                    switch (status) {
                        case AFNetworkReachabilityStatusReachableViaWWAN:
                        case AFNetworkReachabilityStatusReachableViaWiFi:
                            [self.class runRetryQueueFor:url.host];
                            break;
                        case AFNetworkReachabilityStatusNotReachable:
                        default:
                            break;
                    }
                };
                [reacher startMonitoring];
            }
        }
#endif
    }

    return manager;
}

#pragma mark - Success / Fail Handlers

- (void)success:(NSURLSessionTask *)task responseObject:(id)responseObject {
#ifdef SG_INCLUDE_UIKIT
    if (self.showActivityIndicator) {
        [SGHTTPRequest.networkIndicator decrementActivityCount];
    }
#endif

    NSData *responseData = nil;
    NSString *responseString = nil;

    if ([responseObject isKindOfClass:NSDictionary.class]) {
        responseData = [NSJSONSerialization dataWithJSONObject:responseObject
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
        if (responseData) {
            responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        }
    } else if ([responseObject isKindOfClass:NSString.class]) {
        responseData = [responseObject dataUsingEncoding:NSUTF8StringEncoding];
        responseString = responseObject;
    } else if ([responseObject isKindOfClass:NSData.class]) {
        responseData = responseObject;
    } else if (responseObject) {
        SGHTTPAssert(NO, @"SGHTTPRequest success:responseObject: Unexpected responseObject type for %@", responseObject);
    }
    
    self.responseData = responseData;
    self.responseString = responseString;
    self.statusCode = ((NSHTTPURLResponse*)task.response).statusCode;
    if (!self.cancelled) {
        if (self.logResponses) {
            [self logResponse:task error:nil];
        }
        NSDictionary *responseHeader = ((NSHTTPURLResponse*)task.response).allHeaderFields;
        self.responseHeaders = responseHeader;
        NSString *eTag = responseHeader[@"Etag"];
        NSString *cacheControlPolicy = responseHeader[@"Cache-Control"];
        if ([cacheControlPolicy containsSubstring:@"no-cache"] ||
            [cacheControlPolicy containsSubstring:@"no-store"] ||
            [cacheControlPolicy containsSubstring:@"private"]) {
            self.allowCacheToDisk = NO;
        }
        NSDate *expiryDate = self.timeToExpire ? [NSDate dateWithTimeIntervalSinceNow:self.timeToExpire] : nil;
        if ([cacheControlPolicy containsSubstring:@"max-age"]) {
            NSError *error;
            NSRegularExpression *regex = [NSRegularExpression
                                          regularExpressionWithPattern:@"(max-age=)(\\d+)"
                                          options:NSRegularExpressionCaseInsensitive
                                          error:&error];
            NSTextCheckingResult *match = [regex firstMatchInString:cacheControlPolicy
                                                            options:0
                                                              range:NSMakeRange(0, cacheControlPolicy.length)];
            if (match) {
                NSString *maxAge = [cacheControlPolicy substringWithRange:match.range];
                NSArray *maxAgeComponents = [maxAge componentsSeparatedByString:@"="];
                if (maxAgeComponents.count == 2) {
                    NSString *maxAgeValueString = maxAgeComponents[1];
                    NSTimeInterval expiryInterval = maxAgeValueString.doubleValue;
                    expiryDate = [NSDate dateWithTimeIntervalSinceNow:expiryInterval];
                }
            }
        }
        if (eTag.length) {
            if (self.statusCode == 304) {
                if (!self.responseData.length && self.allowCacheToDisk) {
                    [SGHTTPRequest.cache getCachedDataAsyncFor:self.primaryCacheKey
                            secondaryKeys:@{SGETag:eTag}
                            newExpiryDate:expiryDate dataCompletion:^(NSData *cachedData) {
                             if (cachedData) {
                                 self.responseData = cachedData;
                                 self.eTag = eTag;
                                 if (self.onSuccess) {
                                     self.onSuccess(self);
                                 }
                             } else {
                                 self.eTag = nil;
                                 [self removeCacheFiles];
                                 [self start];   //cached data is missing. try again without eTag
                             }}];
                    return;
                }
            } else if (self.allowCacheToDisk) {
                // response has changed.  Let's cache the new version.
                [self cacheDataForETag:eTag expiryDate:expiryDate];
            }
        } else if (self.eTag.length && self.statusCode == 200) {
            // Sometimes servers can ommit an ETag, even if the contents have changed.
            // (We've experienced this with gzipped payloads stripping ETag information.)
            // In this case, *if* we received a 200 response and received no ETag, we should
            // overwrite the cached copy with the fresh data.
            self.eTag = @"Missing";
            [self cacheDataForETag:self.eTag expiryDate:expiryDate];
        }
        if (!self.allowCacheToDisk) {
            [self removeCacheFiles];
        }
        self.eTag = eTag;
        if (self.onSuccess) {
            self.onSuccess(self);
        }
    }
}

- (void)failedWithError:(NSError *)error task:(NSURLSessionTask *)task
      retryURL:(NSString *)retryURL {

#ifdef SG_INCLUDE_UIKIT
    if (self.showActivityIndicator) {
        [SGHTTPRequest.networkIndicator decrementActivityCount];
    }
#endif

    if (self.cancelled) {
        return;
    }

    NSData *responseData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
    self.error = error;
    self.responseData = responseData;
    self.responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    self.statusCode =  ((NSHTTPURLResponse*)task.response).statusCode;

    if (self.logErrors) {
        [self logResponse:task error:error];
    }

    if (self.onFailure) {
        self.onFailure(self);
    }
    self.error = nil;

    if (self.onNetworkReachable && retryURL) {
        NSURL *url = [NSURL URLWithString:retryURL];
        if (url.host) {
            [[SGHTTPRequest retryQueueFor:url.host] addObject:self.onNetworkReachable];
        }
    }
}

#pragma mark - Getters

- (id)responseJSON {
    return [SGJSONSerialization JSONObjectWithData:self.responseData allowNSNull:self.allowNSNull logURL:self.url.absoluteString];
}

+ (NSMutableArray *)retryQueueFor:(NSString *)baseURL {
    if (!baseURL) {
        return nil;
    }

    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        gRetryQueues = NSMutableDictionary.new;
    });

    NSMutableArray *queue = gRetryQueues[baseURL];
    if (!queue) {
        queue = NSMutableArray.new;
        gRetryQueues[baseURL] = queue;
    }

    return queue;
}

+ (void)runRetryQueueFor:(NSString *)host {
    NSMutableArray *retryQueue = [self retryQueueFor:host];

    NSArray *localCopy = retryQueue.copy;
    [retryQueue removeAllObjects];

    for (SGHTTPRetryBlock retryBlock in localCopy) {
        retryBlock();
    }
}

+ (void)removeRetryCompletion:(SGHTTPRetryBlock)onNetworkReachable forHost:(NSString *)host {
    doOnMain(^{
        if ([[SGHTTPRequest retryQueueFor:host] containsObject:onNetworkReachable]) {
            [[SGHTTPRequest retryQueueFor:host] removeObject:onNetworkReachable];
    }});
}

+ (NSString *)baseURLFrom:(NSURL *)url {
    return [NSString stringWithFormat:@"%@://%@/", url.scheme, url.host];
}

#ifdef SG_INCLUDE_UIKIT
+ (SGActivityIndicator *)networkIndicator {
    if (gNetworkIndicator) {
        return gNetworkIndicator;
    }
    gNetworkIndicator = [[SGActivityIndicator alloc] init];
    return gNetworkIndicator;
}
#endif

#pragma mark - ETag Caching

+ (SGFileCache *)cache {
    SGFileCache *cache = [SGFileCache cacheFor:@"SGHTTPRequestETags"];
    cache.logCache = SGHTTPRequest.logging & SGHTTPLogCache;
    return cache;
}

- (NSString *)eTag {
    if (_allowCacheToDisk && !_eTag) {
        _eTag = [SGHTTPRequest.cache secondaryKeyValueNamed:SGETag forPrimaryKey:self.primaryCacheKey];
    }
    return _eTag;
}

- (NSData *)cachedResponseData {
    if (!self.allowCacheToDisk || !self.eTag) {
        return nil;
    }
    return [SGHTTPRequest.cache cachedDataFor:self.primaryCacheKey secondaryKeys:self.secondaryCacheKeys];
}

- (id)cachedResponseJSON {
    if (!self.allowCacheToDisk) {
        return nil;
    }
    NSData *cachedData = self.cachedResponseData;
    if (!cachedData) {
        return nil;
    }
    return [SGJSONSerialization JSONObjectWithData:cachedData allowNSNull:self.allowNSNull logURL:self.url.absoluteString];
}

- (void)cacheDataForETag:(NSString *)eTag expiryDate:(NSDate *)expiryDate {
    SGHTTPAssert(eTag.length, @"Missing valid eTag");
    if (!eTag.length) {
        return;
    }
    [SGHTTPRequest.cache cacheData:self.responseData for:self.primaryCacheKey secondaryKeys:@{SGETag:eTag} expiryDate:expiryDate];
}

- (void)removeCacheFiles {
    [SGHTTPRequest.cache removeCacheFilesForPrimaryKey:self.primaryCacheKey];
}

- (void)removeCacheFilesIfExpired {
    if ([SGHTTPRequest.cache removeCacheFilesIfExpiredForPrimaryKey:self.primaryCacheKey]) {
        self.eTag = nil;
    }
}

- (NSString *)primaryCacheKey {
    NSMutableString *fullKey = self.url.absoluteString.mutableCopy;
    if (self.requestHeaders.count) {
        for (id key in self.requestHeaders) {
            if ([key isKindOfClass:NSString.class] && [key isEqualToString:@"If-None-Match"]) {
                continue;
            }
            [fullKey appendFormat:@":%@:%@", key, self.requestHeaders[key]];
        }
    }
    return fullKey;
}

- (NSDictionary *)secondaryCacheKeys {
    return self.eTag.length ? @{SGETag:self.eTag} : nil;
}

+ (void)clearCache {
    [self.cache clearCache];
}

static BOOL gAllowCacheToDisk = NO;

+ (void)setAllowCacheToDisk:(BOOL)allowCacheToDisk {
    gAllowCacheToDisk = allowCacheToDisk;
}

+ (BOOL)allowCacheToDisk {
    return gAllowCacheToDisk;
}

+ (void)setMaxDiskCacheSize:(NSUInteger)megaBytes {
    SGHTTPRequest.cache.maxDiskCacheSizeMB = megaBytes;
}

+ (NSInteger)maxDiskCacheSize {
    return SGHTTPRequest.cache.maxDiskCacheSizeMB;
}

- (NSTimeInterval)timeToExpire {
    return _timeToExpire ?: SGHTTPRequest.cache.defaultCacheMaxAge;
}

+ (void)setDefaultCacheMaxAge:(NSTimeInterval)timeToExpire {
    SGHTTPRequest.cache.defaultCacheMaxAge = timeToExpire;
}

+ (NSTimeInterval)defaultCacheMaxAge {
    return SGHTTPRequest.cache.defaultCacheMaxAge;
}

+ (void)initialize {
    [self.cache clearExpiredFiles];
}

#pragma mark - NSNull Handling

static BOOL gAllowNSNulls = YES;

+ (void)setAllowNSNull:(BOOL)allow {
    gAllowNSNulls = allow;
}

+ (BOOL)allowNSNull {
    return gAllowNSNulls;
}

#pragma mark - Logging

+ (void)setLogging:(SGHTTPLogging)logging {
#ifdef DEBUG
    // Logging in debug builds only.
    gLogging = logging;
#endif
}

+ (SGHTTPLogging)logging {
    return gLogging;
}

- (NSString *)boxUpString:(NSString *)string fatLine:(BOOL)fatLine {
    NSMutableString *boxString = NSMutableString.new;
    NSInteger charsInLine = string.length + 4;

    if (fatLine) {
        [boxString appendString:@"\n╔"];
        [boxString appendString:[@"" stringByPaddingToLength:charsInLine - 2 withString:@"═" startingAtIndex:0]];
        [boxString appendString:@"╗\n"];
        [boxString appendString:[NSString stringWithFormat:@"║ %@ ║\n", string]];
        [boxString appendString:@"╚"];
        [boxString appendString:[@"" stringByPaddingToLength:charsInLine - 2 withString:@"═" startingAtIndex:0]];
        [boxString appendString:@"╝\n"];
    } else {
        [boxString appendString:@"\n┌"];
        [boxString appendString:[@"" stringByPaddingToLength:charsInLine - 2 withString:@"─" startingAtIndex:0]];
        [boxString appendString:@"┐\n"];
        [boxString appendString:[NSString stringWithFormat:@"│ %@ │\n", string]];
        [boxString appendString:@"└"];
        [boxString appendString:[@"" stringByPaddingToLength:charsInLine - 2 withString:@"─" startingAtIndex:0]];
        [boxString appendString:@"┘\n"];
    }
    return boxString;
}

- (void)logResponse:(NSURLSessionTask *)task error:(NSError *)error {
    NSString *responseString = self.responseString;
    NSObject *requestParameters = self.parameters;
    NSString *requestMethod = task.originalRequest.HTTPMethod ?: @"";

    if (self.responseData &&
        [NSJSONSerialization isValidJSONObject:self.responseData]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.responseData
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (jsonData) {
            responseString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    if (self.parameters &&
        self.requestFormat == SGHTTPDataTypeJSON &&
        [NSJSONSerialization isValidJSONObject:self.parameters]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.parameters
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (jsonData) {
            requestParameters = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }

    NSMutableString *output = NSMutableString.new;

    if (error) {
        [output appendString:[self boxUpString:[NSString stringWithFormat:@"HTTP %@ Request failed!", requestMethod]
                                       fatLine:YES]];
    } else {
        [output appendString:[self boxUpString:[NSString stringWithFormat:@"HTTP %@ Request succeeded", requestMethod]
                                       fatLine:YES]];
    }
    [output appendString:[self boxUpString:@"URL:" fatLine:NO]];
    [output appendString:[NSString stringWithFormat:@"%@", self.url]];
    [output appendString:[self boxUpString:@"Request Headers:" fatLine:NO]];
    [output appendString:[NSString stringWithFormat:@"%@", self.requestHeaders]];

    // this prints out POST Data: / PUT data: etc
    [output appendString:[self boxUpString:[NSString stringWithFormat:@"%@ Data:", requestMethod]
                                    fatLine:NO]];
    [output appendString:[NSString stringWithFormat:@"%@", requestParameters]];
    [output appendString:[self boxUpString:@"Status Code:" fatLine:NO]];
    [output appendString:[NSString stringWithFormat:@"%@", @(self.statusCode)]];
    [output appendString:[self boxUpString:@"Response:" fatLine:NO]];
    [output appendString:[NSString stringWithFormat:@"%@", responseString]];

    if (error) {
        [output appendString:[self boxUpString:@"NSError:" fatLine:NO]];
        [output appendString:[NSString stringWithFormat:@"%@", error]];
    }
    [output appendString:@"\n═══════════════════════\n\n"];
    NSLog(@"%@", [NSString stringWithString:output]);
}

- (BOOL)logErrors {
    return (self.logging & SGHTTPLogErrors) || (self.logging & SGHTTPLogResponses);
}

- (BOOL)logRequests {
    return self.logging & SGHTTPLogRequests;
}

- (BOOL)logResponses {
    return self.logging & SGHTTPLogResponses;
}

@end
