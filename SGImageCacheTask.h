//
//  Created by matt on 22/05/14.
//

#import "SGImageCache.h"

@interface SGImageCacheTask : NSOperation

@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) BOOL succeeded;
@property (nonatomic, assign) int attempt;
@property (nonatomic, assign) BOOL forceDecompress;

+ (instancetype)taskForURL:(NSString *)url attempt:(int)attempt;

- (NSArray *)completions;
- (void)addCompletion:(SGCacheFetchCompletion)completion;
- (void)addCompletions:(NSArray *)completions;

@end
