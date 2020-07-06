## MGEvents

**MGEvents** provides any extremely lightweight API for keypath observing, UIControl event
handling, and observing and triggering custom events.

### CocoaPods Setup

```
pod 'MGEvents'
```

### Examples

```objc
#import <MGEvents/MGEvents.h>
``` 

### Keypath Observing

```objc
[box onChangeOf:@"selected" do:^{
    NSLog(@"the new selected value is: %d", box.selected);
}];
```

### Control Event Observing

```objc
[button onControlEvent:UIControlEventTouchUpInside do:^{
    NSLog(@"i've been touched up inside. golly.");
}];
```

Or in Swift: 

```swift
button.onControlEvent(.TouchUpInside) {
    print("you touched me!")
}
```

### Custom Events and Triggers

```objc
[earth on:@"ChangedShape" do:^{
    NSLog(@"the earth has changed shape");
}];
```

Then trigger the event:

```objc
[earth trigger:@"ChangedShape"];
```

### Further Options

See the [API reference](http://cocoadocs.org/docsets/MGEvents) for more details.
