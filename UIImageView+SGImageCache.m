//
//  Created by matt on 22/05/14.
//

#import "UIImageView+SGImageCache.h"
#import "SGImageCache.h"
#import <MGEvents/MGEvents.h>
#import <objc/runtime.h>

@interface UIImageView (SGImageCache_Private)
@property (nonatomic,strong) NSString *cachedImageURL;
@end

@implementation UIImageView (SGImageCache_Private)

@dynamic cachedImageURL;

- (void)setCachedImageURL:(NSString*)object {
     objc_setAssociatedObject(self, @selector(cachedImageURL), object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString*)cachedImageURL {
    return objc_getAssociatedObject(self, @selector(cachedImageURL));
}

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

    self.cachedImageURL = url;

    if ([SGImageCache haveImageForURL:url]) {
        UIImage *image = [SGImageCache imageForURL:url];
        if (duration > 0 && me.window) {
            [UIView transitionWithView:self.superview
                              duration:duration
                               options:UIViewAnimationOptionTransitionCrossDissolve |
             UIViewAnimationOptionAllowAnimatedContent
                            animations:^{
                                self.image = image;
                                [self trigger:SGImageViewImageChanged withContext:image];
                            } completion:nil];
        } else {
            self.image = image;
            [self trigger:SGImageViewImageChanged withContext:image];
        }
    } else {
        if (self.image != placeholder) {
            self.image = placeholder;
            [me trigger:SGImageViewImageChanged withContext:placeholder];
        }
        [SGImageCache getImageForURL:url].then(^(UIImage *image) {
            if (!image) {
                return;
            }
            if (url != me.cachedImageURL) {
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
        });
    }
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
