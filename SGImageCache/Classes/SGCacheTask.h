//
//  Created by matt on 22/05/14.
//

#import "SGCache.h"
#import "SGCachePromise.h"

@interface SGCacheTask : NSOperation

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic, copy) NSString *cacheKey;
@property (nonatomic, assign) BOOL succeeded;
@property (nonatomic, assign) int attempt;
@property (nonatomic, assign) BOOL remoteFetchOnly;
@property (nonatomic, weak) SGCachePromise *promise;
@property (nonatomic, assign) Class cacheClass;

+ (instancetype)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey attempt:(int)attempt;

- (NSMutableOrderedSet *)completions;
- (void)addCompletion:(SGCacheFetchCompletion)completion;
- (void)addCompletions:(NSMutableOrderedSet *)completions;

- (NSMutableOrderedSet *)onFailBlocks;
- (void)addFailBlock:(SGCacheFetchFail)fail;
- (void)addFailBlocks:(NSMutableOrderedSet *)fails;

- (NSMutableOrderedSet *)onRetryBlocks;
- (void)addRetryBlock:(SGCacheFetchOnRetry)retry;
- (void)addRetryBlocks:(NSMutableOrderedSet *)retries;

- (BOOL)matchesCacheKey:(NSString *)cacheKey;

@end
