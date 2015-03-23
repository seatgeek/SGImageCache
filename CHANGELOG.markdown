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
