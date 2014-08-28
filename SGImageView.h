//
//  SGImageView.h
//  Pods
//
//  Created by James Van-As on 27/08/14.
//
//

#import <UIKit/UIKit.h>
#import "UIImageView+SGImageCache.h"

@interface SGImageView : UIImageView

/**
 * When assigning an image using one of the UIImage+SGImageCache
 * image setters, the SGImageView will flush it's image contents if not on
 * screen and the app receives a memory warning.  If the image has been
 * flushed, the contents will be reloaded if the image view returns to
 * screen.
 *
 *
 * Image setters that will enable memory flushing:
 *
 * - (void)setImageForURL:(NSString *)url;
 *
 * - (void)setImageForURL:(NSString *)url placeholder:(UIImage *)placeholder;
 *
 * - (void)setImageForURL:(NSString *)url
 *            placeholder:(UIImage *)placeholder
 *      crossFadeDuration:(NSTimeInterval)duration;
 *
 * - (void)setImageWithName:(NSString *)name;
 *
 * - (void)setImageWithName:(NSString *)name
 *        crossFadeDuration:(NSTimeInterval)duration;
 *
 */

@end
