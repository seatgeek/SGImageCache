//
//  Created by matt on 22/05/14.
//

#import "SGCache.h"

@interface SGCacheTask : NSOperation

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic, copy) NSString *cacheKey;
@property (nonatomic, assign) BOOL succeeded;
@property (nonatomic, assign) int attempt;
@property (nonatomic, assign) BOOL remoteFetchOnly;

+ (instancetype)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers
      cacheKey:(NSString *)cacheKey attempt:(int)attempt;

- (NSArray *)completions;
- (void)addCompletion:(SGCacheFetchCompletion)completion;
- (void)addCompletions:(NSArray *)completions;
- (BOOL)matchesCacheKey:(NSString *)cacheKey;

@end
