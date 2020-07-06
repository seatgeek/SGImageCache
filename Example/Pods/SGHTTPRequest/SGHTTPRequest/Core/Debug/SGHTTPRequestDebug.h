//
//  SGHTTPRequestDebug.h
//  Pods
//
//  Created by James Van-As on 22/06/15.
//
//

#import <Foundation/Foundation.h>

#define SGHTTPAssert(condition, desc, ...) \
    if (!(condition)) { \
        if (SGHTTPRequestDebug.isRunningInTest) { \
        } else { \
            NSLog(@"%@",[NSString stringWithFormat:(desc), ##__VA_ARGS__]); \
            if (SGHTTPRequestDebug.runningInDebugger) \
                kill (getpid(), SIGSTOP); \
        } \
    }

@interface SGHTTPRequestDebug : NSObject
+ (BOOL)runningInDebugger;
+ (BOOL)isRunningInTest;
@end
