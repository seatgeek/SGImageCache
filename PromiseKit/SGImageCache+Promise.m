//
//  SGImageCache+Promise.m
//  Dustin Bachrach
//
//  Created by Dustin Bachrach on 9/15/14.
//  Copyright (c) 2014 Dustin Bachrach. All rights reserved.
//

#import "SGImageCache+Promise.h"


@implementation SGImageCache (PromiseKit)

+ (PMKPromise*)getImageForURL:(NSString*)url
{
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self getImageForURL:url thenDo:^(UIImage* image) {
            fulfill(image);
        }];
    }];
}

+ (PMKPromise*)slowGetImageForURL:(NSString*)url
{
    return [PMKPromise new:^(PMKPromiseFulfiller fulfill, PMKPromiseRejecter reject) {
        [self slowGetImageForURL:url thenDo:^(UIImage* image) {
            fulfill(image);
        }];
    }];
}

@end
