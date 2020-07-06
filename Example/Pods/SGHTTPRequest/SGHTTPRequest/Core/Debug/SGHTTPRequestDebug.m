//
//  SGHTTPRequestDebug.m
//  Pods
//
//  Created by James Van-As on 22/06/15.
//
//

#import "SGHTTPRequestDebug.h"
#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/sysctl.h>

@implementation SGHTTPRequestDebug

+ (BOOL)isRunningInTest {
    static BOOL isTest;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isTest = [NSProcessInfo.processInfo.environment[@"SG_IS_TESTING"] boolValue];   // declared in the test environment var
    });
    return isTest;
}

// AmIBeingDebugged code from apple: https://developer.apple.com/library/mac/qa/qa1361/_index.html
// NOTE: it says you must wrap this code in #ifdef DEBUG otherwise bad things will happen for release builds

+ (BOOL)runningInDebugger {
#ifdef DEBUG
    static BOOL isDebug;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int                 junk;
        int                 mib[4];
        struct kinfo_proc   info;
        size_t              size;
        info.kp_proc.p_flag = 0;

        mib[0] = CTL_KERN;
        mib[1] = KERN_PROC;
        mib[2] = KERN_PROC_PID;
        mib[3] = getpid();

        size = sizeof(info);
        junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
        assert(junk == 0);
        isDebug = ( (info.kp_proc.p_flag & P_TRACED) != 0 );
    });
    return isDebug;
#else
    return NO;
#endif
}



@end
