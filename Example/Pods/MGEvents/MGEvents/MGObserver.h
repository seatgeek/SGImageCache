//
//  Created by matt on 2/04/14.
//
//

#import "MGBlockWrapper.h"

@interface MGObserver : NSObject

@property (nonatomic, copy) MGBlock block;

+ (MGObserver *)observerFor:(NSObject *)object keypath:(NSString *)keypath
    block:(MGBlock)block;

@end
