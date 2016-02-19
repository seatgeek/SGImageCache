//
//  SGImageView.h
//  Pods
//
//  Created by James Van-As on 27/08/14.
//
//

#if !TARGET_OS_WATCH

#import "UIImageView+SGImageCache.h"

/**
* Use `SGImageView` in place of `UIImageView` to get intelligent memory
* management of the `image` property.
*
* When assigning an image using one of the `setImageForURL:` methods
* from `UIImage+SGImageCache`, the `SGImageView` will flush its image
* if not on screen and the app receives a memory warning. If the image has
* been flushed, the contents will be reloaded from cache if the image view
* returns to screen.
*/

@interface SGImageView : UIImageView

@end

#endif