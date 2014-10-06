//
//  Created by matt on 22/05/14.
//

/**
* A `UIImageView` category with convenience setters for loading images from
* <SGImageCache>.
*/

#define SGImageViewImageChanged     @"SGImageViewImageChanged"

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

/**
 * Assigns a placeholder image to the image view's `image`, then fetches an
 * image from <SGImageCache> to replace the placeholder. If the image is not
 * available in cache it will be fetched from the given URL asynchronously.
 * The image will crossfade in from the placeholder with the given duration.
 */
- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration;

/**
 * Assigns a placeholder image to the image view's `image`, then fetches an
 * image from <SGImageCache> to replace the placeholder. If the image is not
 * available in cache it will be fetched from the given URL asynchronously.
 * Since image fetching is asynchornous, we might NOT want to set the imageview's
 * image when the download completes. The `stillValid` block will be executed
 * after the image request completes to check if the image should be set on the
 * imageview. Return YES in the block to update the imageview's image. 
 */
- (void)setImageForURL:(NSString*)url
           placeholder:(UIImage*)placeholder
            stillValid:(BOOL(^)())stillValid;

/**
 * Assigns a placeholder image to the image view's `image`, then fetches an
 * image from <SGImageCache> to replace the placeholder. If the image is not
 * available in cache it will be fetched from the given URL asynchronously.
 * The image will crossfade in from the placeholder with the given duration.
 * Since image fetching is asynchornous, we might NOT want to set the imageview's
 * image when the download completes. The `stillValid` block will be executed
 * after the image request completes to check if the image should be set on the
 * imageview. Return YES in the block to update the imageview's image. 
 */
- (void)setImageForURL:(NSString *)url
           placeholder:(UIImage *)placeholder
     crossFadeDuration:(NSTimeInterval)duration 
            stillValid:(BOOL(^)())stillValid;

/**
 * Fetches an image from <SGImageCache> and assigns it to the image view's
 * `image`. If the image is not available in cache it will be fetched from
 * the asset bundle with the given name.
 */
- (void)setImageWithName:(NSString *)name;

/**
 * Assigns a placeholder image to the image view's `image`, then fetches an
 * image from <SGImageCache> to replace the placeholder. If the image is not 
 * available in cache it will be fetched from the asset bundle with the given 
 * name.
 */
- (void)setImageWithName:(NSString *)name
       crossFadeDuration:(NSTimeInterval)duration;

@end
