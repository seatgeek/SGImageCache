//
//  NSString+SGHTTPRequest.m
//  Pods
//
//  Created by James Van-As on 29/06/15.
//
//

#import "NSString+SGHTTPRequest.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (SGHTTPRequest)

- (NSString *)sgHTTPRequestHash {
    if (!self.length) {
        return @"";
    }
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

#pragma clang diagnostic push
#pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
- (BOOL)containsSubstring:(NSString *)substring {
    if ([self respondsToSelector:@selector(containsString:)]) {
        return [self containsString:substring];
    }
    return [self rangeOfString:substring].location != NSNotFound;
}
#pragma clang diagnostic pop

@end
