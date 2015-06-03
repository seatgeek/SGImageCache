## SGImageCache

A lightweight iOS image and data cache with built in queue management.

### CocoaPods Setup

```
pod 'SGImageCache'
```

### Get an image urgently

```objc
// Objective-C
[SGImageCache getImageForURL:url].then(^(UIImage *image) {
    if (image) {
        self.imageView.image = image;
    }
});
```

```swift
// Swift
SGImageCache.getImageForURL(url) { image in
    if image {
        self.imageView.image = image
    }
}
SGImageCache.getImageForURL(url).swiftThen({object in
    if let image = object as? UIImage {
        self.imageView.image = image
    }
    return nil
})

```

This will add the fetch request to `fastQueue` (a parellel queue). All image fetching (either
from memory, disk, or remote) is performed off the main thread. 

### Queue a fetch for an image that you'll need later

```objc
// Objective-C
[SGImageCache slowGetImageForURL:url];
```

```swift
// Swift
SGImageCache.slowGetImageForURL(url)
```

This will add the fetch request to `slowQueue` (a serial queue). All image fetching (either
from memory, disk, or remote) is performed off the main thread.

Adding image fetch tasks to `slowQueue` is useful for prefetching images for off screen
content. For example if you have data for 100 table rows, but only 3 are on screen at a time,
you would request the images for on screen rows from `fastQueue` with `getImageForURL:` and
add the rest to `slowQueue` with `slowGetImageForURL:`.

### Inform the cache that an urgent image fetch is no longer urgent

```objc
// Objective-C
[SGImageCache moveTaskToSlowQueueForURL:url];
```

```swift
// Swift
SGImageCache.moveTaskToSlowQueueForURL(url)
```

This is useful for deprioritising image fetches for content that has scrolled off screen. The
content may scroll back on screen later, so you still want the fetch to happen, but it is no
longer urgently required.

### Perform actions on remote fetch, fail or retry

```objc
// Objective-C
SGCachePromise *promise = [SGImageCache getImageForURL:url];
promise.then(^(UIImage *image) {
  self.imageView.image = image;
});
promise.onRetry = ^{
  // Called when SGImageCache automatically retries
  // fetching the image due to a reachability change.
  [self showLoadingSpinner];
};
promise.onFail = ^(NSError *error, BOOL fatal) {
  // If the failure was fatal, SGImageCache will not
  // automatically retry (eg. from a 404)
  [self displayError:error];
};
```

```swift
// Swift
let promise = SGImageCache.getImageForURL(url)
promise.swiftThen({object in
  if let image = object as? UIImage {
      self.imageView.image = image
  }
  return nil
})
promise.onRetry = {
  self.showLoadingSpinner()
}
promise.onFail = { (error: NSError?, wasFatal: Bool) -> () in
  self.displayError(error)
}

```

This is useful for displaying states of network failure, loading spinners on reachability change, or any other functionality that might need to be notified that an image could not be fetched.

### fastQueue

`fastQueue` is a parallel queue, used for urgently required images. The `getImageForURL:`
method adds tasks to this queue. The maximum number of parallel tasks is managed by iOS, based on the device's number of processors, [and other factors](https://developer.apple.com/library/ios/documentation/cocoa/reference/NSOperationQueue_class/Reference/Reference.html#//apple_ref/doc/uid/TP40004592-RH2-borderType). 

### slowQueue

`slowQueue` is a serial queue, used for prefetching images that might be required later (eg
for currently off screen content). The `slowGetImageForURL:` method adds tasks to this queue.

`slowQueue` is automatically suspended while `fastQueue` is active, to avoid consuming network bandwidth while urgent image fetches are in progress. Once all `fastQueue` tasks are completed
`slowQueue` will be resumed.

### Task Deduplication

If an image is requested for a URL that is already queued or in progress, `SGImageCache` 
reuses the existing task, and if necessary will move it from `slowQueue` to `fastQueue`, 
depending on which image fetch method was used. This ensures that there will be only one 
network request per URL, regardless of how many times it's been asked for.

### Intelligent image releasing on memory warning

If you use `SGImageView` instead of `UIImageView`, and load the image via one of the
`setImageForURL:` methods, off screen image views will release their `image` on memory
warning, and subsequently restore them from cache if the image view returns to screen.
This allows off screen but still existing view controllers (eg a previous controller in a
nav controller's stack) to free up memory that would otherwise be unnecessarily retained, 
and reduce the chances of your app being terminated by iOS in limited memory situations.

### Generic caching of NSData

You can use SGImageCache for caching of generic data in the form of an NSData object (eg. PDFs, JSON payloads).  Just use the equivalent `SGCache` class method instead of the `SGImageCache` one:

```objc
// Objective-C
[SGCache getFileForURL:url].then(^(NSData *data) {
  // do something with data
});

```

```swift
// Swift
SGCache.getFileForURL(url).swiftThen({object in
  if let data = object as? NSData {
    // do something with data
  }
  return nil
})
```
