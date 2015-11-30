## 2.2.1

- Added a way to remove images from the cache manually
- Fixed caching bug to do with hash collisions
- Use Framework style import statements for pod Framework compatibility

## 2.2.0

- Added the ability to handle remote fetch failures and perform actions on fetch
  retry attempts (eg. show fail screens, retry loading spinners).
- Added an addImage:forURL method for adding images to the cache locally

## 2.1.0

- Added an addData: method for adding cache data locally

## 2.1.0

- Added SGCache, a generic NSData cacher
- Added the ability to use custom HTTP headers
- Allow providing custom cache keys
- Added the ability to force a remote fetch

## 2.1.0

- Added SGCache, a generic NSData cacher
- Added the ability to use custom HTTP headers
- Allow providing custom cache keys
- Added the ability to force a remote fetch

## 2.0.1

- Allow SGImageCache to work with projects using Alamofire and use_frameworks!
- Fixed a race condition bug
- Specified a PromiseKit dependency of 1.5.x

## 2.0.0

- PromiseKit is now compulsory, and non PromiseKit based methods have been
  removed
- Fixed auto retrying of image fetches on return of network connectivity

## 1.2.0

- Added optional PromiseKit based completions, courtesy of @dbachrach.

## 1.1.0

- No longer uses `imageNamed:` for memory caching, due to nasty performance
  degredation on iOS 8, and imageNamed's questionable memory management.
- A new `SGImageView` class which can automatically release its `image`
  property on memory warning if possible (ie if not on screen). The image
  will be automatically reloaded from cache if the image view returns to
  screen. (Note that this functionality is only enabled if one of the
  `setImageForURL:` methods was used).

## 1.0.1

Added console logging option

## 1.0.0

Initial release
