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
@property (nonatomic,assign) BOOL enableMemoryFlushing;
@property (nonatomic,assign) BOOL haveFlushedImage;
@property (nonatomic,assign) BOOL registeredForNotifications;
@property (nonatomic,strong) NSString *cachedImageURL;
@property (nonatomic,strong) NSString *cachedImageName;
@end

@implementation SGImageView

- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration {
    self.enableMemoryFlushing = YES;
    self.cachedImageName = nil;
    self.cachedImageURL = url;
    [super setImageForURL:url placeholder:placeholder crossFadeDuration:duration];
}
- (void)setImageWithName:(NSString *)name
       crossFadeDuration:(NSTimeInterval)duration {
    self.enableMemoryFlushing = YES;
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
    if (!self.enableMemoryFlushing || !self.haveFlushedImage) {
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
    self.haveFlushedImage = NO;
}

- (void)flushIfAble {
    if (!self.enableMemoryFlushing || self.window || !self.image) {
        return;
    }
    if (SGImageCache.logging & SGImageCacheLogMemoryFlushing) {
        if (self.cachedImageURL) {
            NSLog(@"SGImageView flushing image: %@", self.cachedImageURL);
        } else if (self.cachedImageName) {
            NSLog(@"SGImageView flushing image: %@", self.cachedImageName);
        }
    }
    self.image = nil;
    self.haveFlushedImage = YES;
}

- (void)setEnableMemoryFlushing:(BOOL)enableMemoryFlushing {
    if (_enableMemoryFlushing == enableMemoryFlushing) {
        return;
    }
    _enableMemoryFlushing = enableMemoryFlushing;
    if (enableMemoryFlushing) {
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
    [self when:SGImageCache.class does:SGImageCacheFlushed do:^{
        [me flushIfAble];
    }];
}

@end
