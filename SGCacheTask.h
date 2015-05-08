//
//  Created by matt on 22/05/14.
//

#import "SGCache.h"

@interface SGCacheTask : NSOperation

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic, assign) BOOL succeeded;
@property (nonatomic, assign) int attempt;

+ (instancetype)taskForURL:(NSString *)url requestHeaders:(NSDictionary *)headers attempt:(int)attempt;

- (NSArray *)completions;
- (void)addCompletion:(SGCacheFetchCompletion)completion;
- (void)addCompletions:(NSArray *)completions;
- (BOOL)isEqualToTask:(SGCacheTask *)task;
- (BOOL)matchesURL:(NSString *)url requestHeaders:(NSDictionary *)requestHeaders;

@end
