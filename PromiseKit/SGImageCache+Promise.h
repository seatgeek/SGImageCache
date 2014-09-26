//
//  SGImageCache+Promise.h
//  Dustin Bachrach
//
//  Created by Dustin Bachrach on 9/15/14.
//  Copyright (c) 2014 Dustin Bachrach. All rights reserved.
//

#import "SGImageCache.h"
#import <PromiseKit/PromiseKit.h>


@interface SGImageCache (PromiseKit)

+ (PMKPromise*)getImageForURL:(NSString*)url;

+ (PMKPromise*)slowGetImageForURL:(NSString*)url;

@end
