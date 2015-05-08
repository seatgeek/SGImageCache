//
//  SGImageView.m
//  Pods
//
//  Created by James Van-As on 27/08/14.
//
//

#import "SGImageView.h"
#import "SGImageCache.h"
#import <MGEvents/MGEvents.h>

@interface SGImageView ()
@property (nonatomic,assign) BOOL imageReleasingEnabled;
@property (nonatomic,assign) BOOL haveReleasedImage;
@property (nonatomic,assign) BOOL registeredForNotifications;
@property (nonatomic,strong) NSString *cachedImageURL;
@property (nonatomic,strong) NSString *cachedImageName;
@end

@implementation SGImageView

- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration {
    self.imageReleasingEnabled = YES;
    self.cachedImageName = nil;
    self.cachedImageURL = url;
    [super setImageForURL:url placeholder:placeholder crossFadeDuration:duration];
}
- (void)setImageWithName:(NSString *)name
       crossFadeDuration:(NSTimeInterval)duration {
    self.imageReleasingEnabled = YES;
    self.cachedImageURL = nil;
    self.cachedImageName = name;
    [super setImageWithName:name crossFadeDuration:duration];
}

#pragma mark - Image Flushing

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow) {
        [self restoreImageIfAble];
    }
}

- (void)restoreImageIfAble {
    if (!self.imageReleasingEnabled || !self.haveReleasedImage) {
        return;
    }
    if (self.cachedImageName) {
        self.image = [SGImageCache imageNamed:self.cachedImageName];
        if (SGImageCache.logging & SGImageCacheLogMemoryFlushing) {
            NSLog(@"Restoring image: %@", self.cachedImageName);
        }
    } else if (self.cachedImageURL) {
        self.image = [SGImageCache imageForURL:self.cachedImageURL];
        if (SGImageCache.logging & SGImageCacheLogMemoryFlushing) {
            NSLog(@"Restoring image: %@", self.cachedImageURL);
        }
    }
    self.haveReleasedImage = NO;
}

- (void)releaseImageIfAble {
    if (!self.imageReleasingEnabled || self.window || !self.image) {
        return;
    }
    if (SGImageCache.logging & SGImageCacheLogMemoryFlushing) {
        if (self.cachedImageURL) {
            NSLog(@"SGImageView releasing image: %@", self.cachedImageURL);
        } else if (self.cachedImageName) {
            NSLog(@"SGImageView releasing image: %@", self.cachedImageName);
        }
    }
    self.image = nil;
    self.haveReleasedImage = YES;
}

- (void)setImageReleasingEnabled:(BOOL)imageReleasingEnabled {
    if (_imageReleasingEnabled == imageReleasingEnabled) {
        return;
    }
    _imageReleasingEnabled = imageReleasingEnabled;
    if (imageReleasingEnabled) {
        [self registerForFlushingNotifications];
    }
}


#pragma mark - Notifications

- (void)registerForFlushingNotifications {
    if (self.registeredForNotifications) {
        return;
    }
    self.registeredForNotifications = YES;
    __weakSelf me = self;
    [self when:SGImageCache.class does:SGCacheFlushed do:^{
        [me releaseImageIfAble];
    }];
}

@end
