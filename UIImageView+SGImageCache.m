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

- (void)setImageForURL:(NSString*)url
           placeholder:(UIImage*)placeholder
            stillValid:(BOOL(^)())stillValid {
    [self setImageForURL:url placeholder:placeholder crossFadeDuration:0 stillValid:stillValid];
}

- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration {
    [self setImageForURL:url placeholder:placeholder crossFadeDuration:duration stillValid:nil];
}

- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration 
            stillValid:(BOOL(^)())stillValid {
    __weakSelf me = self;
    if (self.image != placeholder) {
         self.image = placeholder;
        [me trigger:SGImageViewImageChanged withContext:placeholder];
    }
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        if (!image) {
            return;
        }
        if (stillValid && !stillValid()) {
            return;
        }
        if (duration > 0 && me.window) {
            [UIView transitionWithView:me.superview
                              duration:duration
                               options:UIViewAnimationOptionTransitionCrossDissolve |
                                       UIViewAnimationOptionAllowAnimatedContent
                            animations:^{
                                me.image = image;
                                [me trigger:SGImageViewImageChanged withContext:image];
                            } completion:nil];
        } else {
            me.image = image;
            [me trigger:SGImageViewImageChanged withContext:image];
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
                            [me trigger:SGImageViewImageChanged withContext:image];
                        } completion:nil];
    } else {
        UIImage *image = [SGImageCache imageNamed:name];
        self.image = image;
        [self trigger:SGImageViewImageChanged withContext:image];
    }
}

@end
