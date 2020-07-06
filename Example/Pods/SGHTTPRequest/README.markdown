## SGHTTPRequest

A lightweight [AFNetworking](https://github.com/AFNetworking/AFNetworking) wrapper
for making HTTP requests with minimal code, and callback blocks for success,
failure, and retry. Retry blocks are called when a failed request's network resource
becomes available again.

### CocoaPods Setup

```
pod 'SGHTTPRequest'
```

### Example GET Request

##### Objective-C
```objc
NSURL *url = [NSURL URLWithString:@"http://example.com/things"];

// create a GET request
SGHTTPRequest *req = [SGHTTPRequest requestWithURL:url];

// start the request in the background
[req start];
```
##### Swift
```swift
let url = NSURL(string: "http://example.com/things")

// create a GET request
let req = SGHTTPRequest(URL: url)

// start the request in the background
req.start()
```

### Example POST Request

##### Objective-C
```objc
NSURL *url = [NSURL URLWithString:@"http://example.com/things"];

// create a POST request
SGHTTPRequest *req = [SGHTTPRequest postRequestWithURL:url];

// set the POST fields
req.parameters = @{@"field": @"value"};

// start the request in the background
[req start];
```
##### Swift
```swift
let url = NSURL(string: "http://example.com/things")

// create a GET request
let req = SGHTTPRequest.postRequestWithURL(url)

// set the POST fields
req.parameters = ["field": "value"]

// start the request in the background
req.start()
```

### Example with Success and Failure Handlers

If a request succeeds, the optional `onSuccess` block is called. If a request fails for any reason, the optional `onFailure` block is called.

##### Objective-C
```objc
NSURL *url = [NSURL URLWithString:@"http://example.com/things"];
// create a GET request
SGHTTPRequest *req = [SGHTTPRequest requestWithURL:url];

// optional success handler
req.onSuccess = ^(SGHTTPRequest *_req) {
    NSLog(@"response:%@", _req.responseString);
};

// optional failure handler
req.onFailure = ^(SGHTTPRequest *_req) {
    NSLog(@"error:%@", _req.error);
    NSLog(@"status code:%d", _req.statusCode);
};

// start the request in the background
[req start];
```
##### Swift
```swift
let url = NSURL(string: "http://example.com/things")
// create a GET request
let req = SGHTTPRequest(URL: url)

// optional success handler
req.onSuccess = {(request) in
    NSLog("response: %@", request.responseString())
}

// optional failure handler
req.onFailure = {(request) in
    NSLog("error: %@", request.error())
    NSLog("status code: %d", request.statusCode())
}

// start the request in the background
req.start()
```

### Example with Retry Handler

If a request failed and the network resource becomes reachable again later, the optional `onNetworkReachable` block is called.

This is useful for silently retrying on unreliable connections, thus eliminating the need for manual 'Retry' buttons. For example an attempt to fetch an image might fail due to poor wifi signal, but once the signal improves the image fetch can complete without requiring user intervention.

The easiest way to implement this is to contain your request code in a method, and call back to that method in your `onNetworkReachable` block, thus firing off a new identical request.

##### Objective-C
```objc
- (void)requestThings {
    NSURL *url = [NSURL URLWithString:@"http://example.com/things"];

    // create a GET request
    SGHTTPRequest *req = [SGHTTPRequest requestWithURL:url];

    __weak typeof(self) me = self;

    // option retry handler
    req.onNetworkReachable = ^{
        [me requestThings];
    };

    // start the request in the background
    [req start];
}
```
##### Swift
```swift
func requestThings() {
    let url = NSURL(string: "http://example.com/things")
    // create a GET request
    let req = SGHTTPRequest(URL: url)

    // optional success handler
    req.onNetworkReachable = { [weak self] in
        if let strongSelf = self {
            strongSelf.requestThings()
        }
    }

    // start the request in the background
    req.start()
}
```

### Response caching

If your server uses ETag headers then you can cache the responses locally and avoid costly network traffic if the payload hasn't changed since the previous request.  Add the following code to your AppDelegate `didFinishLaunchingWithOptions` method:

##### Objective-C
```objc
[SGHTTPRequest setAllowCacheToDisk:YES];  // allow responses cached by ETag to persist between app sessions
[SGHTTPRequest setMaxDiskCacheSize:30];   // maximum size of the local response cache in MB
```
##### Swift
```swift
SGHTTPRequest.setAllowCacheToDisk(true) // allow responses cached by ETag to persist between app sessions
SGHTTPRequest.setMaxDiskCacheSize(30) // maximum size of the local response cache in MB
```

If an HTTP response has been cached to disk, you can also access the cached copy to allow for viewing data offline or instantaneously:

##### Objective-C
```objc
NSURL *url = [NSURL URLWithString:@"http://example.com/things"];
// create a GET request
SGHTTPRequest *req = [SGHTTPRequest requestWithURL:url];
// read the cached response
NSDictionary *responseDict = req.cachedResponseJSON;
if (responseDict[@"my_data_key"]) {
    // If available you can update your UI
    // immediately with the cached data
}
// optional success handler
req.onSuccess = ^(SGHTTPRequest *_req) {
    // You might want to update your UI with
    // the fresh response data here
};
// start the request in the background
[req start];
```
##### Swift
```swift
let url = NSURL(string: "http://example.com/things")
// create a GET request
let req = SGHTTPRequest(URL: url)
// read the cached response
if let responseDict = req.cachedResponseJSON(), responseValue = responseDict["my_data_key"] {
    // If available you can update your UI
    // immediately with the cached data
}
// optional success handler
req.onSuccess = {(request) in
    // You might want to update your UI with
    // the fresh response data here
}
// start the request in the background
req.start()
```

### NSNull Handling

If you don't want your responses to include NSNull objects (they tend to crash if you try and use them - wheras calling methods on nil is safe and defined behavior) then you can ensure they are cleansed from the responses by putting the following code in your AppDelegate:

##### Objective-C
```objc
[SGHTTPRequest setAllowNSNull:NO];
```
##### Swift
```swift
SGHTTPRequest.setAllowNSNull(false)
```

### Other Options

See `SGHTTPRequest.h` for more.
