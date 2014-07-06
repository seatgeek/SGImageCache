//
//  Created by matt on 22/05/14.
//

/**
* A `UIImageView` category with convenience setters for loading images from
* <SGImageCache>.
*/

@interface UIImageView (SGImageCache)

/**
* Fetches an image from <SGImageCache> and assigns it to the image view's
* `image`. If the image is not available in cache it will be fetched from
* the given URL asynchronously.
*/
- (void)setImageForURL:(NSString *)url;

/**
* Assigns a placeholder image to the image view's `image`, then fetches an
* image from <SGImageCache> to replace the placeholder. If the image is not
* available in cache it will be fetched from the given URL asynchronously.
*/
- (void)setImageForURL:(NSString *)url placeholder:(UIImage *)placeholder;

@end
