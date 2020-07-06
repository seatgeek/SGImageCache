//
//  NSObject+SGHTTPRequest.m
//  Pods
//
//  Created by James Van-As on 15/09/15.
//
//

#import "NSObject+SGHTTPRequest.h"
#import <SGHTTPRequest/SGHTTPRequest.h>

@implementation NSObject (SGHTTPRequest)

- (id)sghttp_nullCleansedWithLoggingURL:(NSString *)loggingURL {
    return [NSDictionary sghttp_nullCleanse:self loggingURL:loggingURL logString:NSMutableString.new nullPath:nil];
}

+ (id)sghttp_nullCleanse:(id)obj
              loggingURL:(NSString *)loggingURL
               logString:(NSMutableString *)logString
                nullPath:(NSString *)nullPath {
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = obj;
        NSMutableDictionary *cleansed = NSMutableDictionary.new;
        for (id key in dict) {
            if ([dict[key] isKindOfClass:NSNull.class]) {
                if (SGHTTPRequest.logging & SGHTTPLogNullCleanses) {
                    if (!logString.length) {
                        if (loggingURL.length) {
                            [logString appendFormat:@"SGHTTPRequest stripped NSNull from JSON response for:\n"];
                            [logString appendFormat:@"%@\n", loggingURL];
                        } else {
                            [logString appendString:@"SGHTTPRequest stripped NSNull from JSON response:\n"];
                        }
                    }
                    [logString appendFormat:@"%@[@\"%@\"] = NSNull\n", nullPath, key];
                }
            } else if ([dict[key] isKindOfClass:NSDictionary.class] ||
                       [dict[key] isKindOfClass:NSArray.class]) {
                cleansed[key] = [NSObject sghttp_nullCleanse:dict[key]
                                                  loggingURL:loggingURL
                                                   logString:logString
                                                    nullPath:nullPath ? [nullPath stringByAppendingFormat:@"[@\"%@\"]", key] :
                                 [NSString stringWithFormat:@"[@\"%@\"]", key]];
            } else {
                cleansed[key] = dict[key];
            }
        }
        if (!nullPath && [logString length]) {
            // We've finished cleaning the dict.  Let's log anything we stripped.
            NSLog(@"%@", logString);
        }
        return cleansed;
    } else if ([obj isKindOfClass:NSArray.class]) {
        NSArray *array = obj;
        NSMutableArray *cleansed = NSMutableArray.new;

        for (NSUInteger i = 0; i < array.count; i++) {
            id item = array[i];
            if ([item isKindOfClass:NSNull.class]) {
                if (SGHTTPRequest.logging & SGHTTPLogNullCleanses) {
                    if (![logString length]) {
                        if (loggingURL.length) {
                            [logString appendFormat:@"SGHTTPRequest stripped NSNull from JSON response for:\n"];
                            [logString appendFormat:@"%@\n", loggingURL];
                        } else {
                            [logString appendString:@"SGHTTPRequest stripped NSNull from JSON response:\n"];
                        }
                    }
                    [logString appendFormat:@"%@{ NSNull }\n", nullPath];
                }
            } else if ([item isKindOfClass:NSDictionary.class] ||
                       [item isKindOfClass:NSArray.class]) {
                id cleansedItem = [NSObject sghttp_nullCleanse:item
                                                    loggingURL:loggingURL
                                                     logString:logString
                                                      nullPath:nullPath ? [nullPath stringByAppendingString:@"{}"] :
                                   @"{}"];
                [cleansed addObject:cleansedItem];
            } else {
                [cleansed addObject:item];
            }
        }
        if (!nullPath && [logString length]) {
            // We've finished cleaning the dict.  Let's log anything we stripped.
            NSLog(@"%@", logString);
        }
        return cleansed;
    } else {
        return obj;
    }
}

@end
