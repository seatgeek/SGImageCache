//
//  SGJSONSerialization.m
//  Pods
//
//  Created by James Van-As on 15/09/15.
//
//

#import "SGJSONSerialization.h"
#import "SGHTTPRequest.h"
#import "NSObject+SGHTTPRequest.h"

@implementation SGJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data {
    return [SGJSONSerialization JSONObjectWithData:data logURL:nil];
}

+ (id)JSONObjectWithData:(NSData *)data error:(NSError **)error {
    return [SGJSONSerialization JSONObjectWithData:data
                                             error:error
                                       allowNSNull:SGHTTPRequest.allowNSNull
                                            logURL:nil];
}

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data error:(NSError **)error logURL:(NSString *)logURL {
    return [SGJSONSerialization JSONObjectWithData:data
                                             error:error
                                       allowNSNull:SGHTTPRequest.allowNSNull
                                             logURL:logURL];
}

+ (id)JSONObjectWithData:(NSData *)data logURL:(NSString *)logURL {
    return [SGJSONSerialization JSONObjectWithData:data
                                             error:nil
                                       allowNSNull:SGHTTPRequest.allowNSNull
                                            logURL:logURL];
}

+ (nullable id)JSONObjectWithData:(NSData *)data
                      allowNSNull:(BOOL)allowNSNull
                           logURL:(NSString *)logURL {
    return [SGJSONSerialization JSONObjectWithData:data
                                             error:nil
                                       allowNSNull:allowNSNull
                                            logURL:logURL];
}

+ (id)JSONObjectWithData:(NSData *)data
                   error:(NSError **)error
             allowNSNull:(BOOL)allowNSNull
                  logURL:(NSString *)logURL {
    if (!data) {
        return nil;
    }
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!allowNSNull &&
        ([obj isKindOfClass:NSDictionary.class] || [obj isKindOfClass:NSArray.class])) {
        return [obj sghttp_nullCleansedWithLoggingURL:logURL];
    }
    return obj;
}
@end
