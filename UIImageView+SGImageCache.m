//
//  Created by matt on 22/05/14.
//

#import "UIImageView+SGImageCache.h"
#import "SGImageCache.h"

@implementation UIImageView (SGImageCache)

- (void)setImageForURL:(NSString *)url {
    [self setImageForURL:url placeholder:nil];
}

- (void)setImageForURL:(NSString *)url placeholder:(UIImage *)placeholder {
    __weakSelf me = self;
    if (placeholder) {
        self.image = placeholder;
    }
    [SGImageCache getImageForURL:url thenDo:^(UIImage *image) {
        if (image) {
            me.image = image;
        }
    }];
}

@end
