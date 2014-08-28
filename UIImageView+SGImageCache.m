//
//  Created by matt on 22/05/14.
//

#import "UIImageView+SGImageCache.h"
#import "SGImageCache.h"
#import "MGEvents.h"
#import <objc/runtime.h>

@interface UIImageView ()
@property (nonatomic,assign) BOOL canFlushImage;
@property (nonatomic,assign) BOOL haveFlushedImage;
@property (nonatomic,assign) BOOL registeredForNotifications;
@property (nonatomic,strong) NSString *cachedImageURL;
@property (nonatomic,strong) NSString *cachedImageName;
@end

@implementation UIImageView (SGImageCache)

#pragma mark - Setting Images via URL

- (void)setImageForURL:(NSString *)url {
    [self setImageForURL:url placeholder:nil];
}

- (void)setImageForURL:(NSString *)url placeholder:(UIImage *)placeholder {
    [self setImageForURL:url placeholder:placeholder crossFadeDuration:0];
}

- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration {
    __weakSelf me = self;
    self.image = placeholder;
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        if (!image) {
            return;
        }
        if (url != me.cachedImageURL) {
            return;
        }
        if (duration > 0 && me.window) {
            [UIView transitionWithView:me.superview
                              duration:duration
                               options:UIViewAnimationOptionTransitionCrossDissolve |
                                       UIViewAnimationOptionAllowAnimatedContent
                            animations:^{
                                me.image = image;
                            } completion:nil];
        } else {
            me.image = image;
        }
    }];
}

#pragma mark - Setting Images via Image name

- (void)setImageWithName:(NSString *)name {
    [self setImageWithName:name crossFadeDuration:0];
}

- (void)setImageWithName:(NSString *)name
       crossFadeDuration:(NSTimeInterval)duration {
    __weakSelf me = self;
    if (duration > 0 && me.window) {
        UIImage *image = [SGImageCache imageNamed:name];
        [UIView transitionWithView:me.superview
                          duration:duration
                           options:UIViewAnimationOptionTransitionCrossDissolve |
                                   UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
                            me.image = image;
                        } completion:nil];
    } else {
        self.image = [SGImageCache imageNamed:name];
    }
}

@end
