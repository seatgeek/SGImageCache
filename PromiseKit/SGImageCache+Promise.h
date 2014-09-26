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

/**
Fetch an image from cache if available, or remote it not.
Returns a promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache getImageForURL:url].then(^(UIImage *image) {
        me.imageView.image = image;
    });

- If the URL is not already queued a new image fetch task will be added to
  <fastQueue>.
- If the URL is already in <fastQueue> the promise will resolve when the existing task completes.
- If the URL is already in <slowQueue> it will be moved to <fastQueue> and
  the promise will resolve when the existing task completes.
*/
+ (PMKPromise*)getImageForURL:(NSString*)url;

/**
Fetch an image from cache if available, or remote it not.
Returns a promise that resolves with a UIImage.

    NSString *url = @"http://example.com/image.jpg";

    __weak typeof(self) me = self;
    [SGImageCache slowGetImageForURL:url].then(^(UIImage *image) {
        me.imageView.image = image;
    });

- If the URL is not already queued a new image fetch task will be added to
  <slowQueue>.
- If the URL is already in either <slowQueue> or <fastQueue> the promise will resolve when the existing task completes.
*/
+ (PMKPromise*)slowGetImageForURL:(NSString*)url;

@end
