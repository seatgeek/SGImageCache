//
//  SGJSONSerialization.h
//  Pods
//
//  Created by James Van-As on 15/09/15.
//
//

#import <Foundation/Foundation.h>

@interface SGJSONSerialization : NSObject

/**
 * SGJSONSerialization JSON object creation which respects the SGHTTPRequest allowNSNull option.
 */

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data;

/**
 * SGJSONSerialization JSON object creation which respects the SGHTTPRequest allowNSNull option.
 */

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data error:(NSError * _Nullable * _Nullable)error;

/**
 * SGJSONSerialization JSON object creation which respects the SGHTTPRequest allowNSNull option.
 */

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data error:(NSError * _Nullable * _Nullable)error logURL:(NSString * _Nullable)logURL;

/**
 * SGJSONSerialization JSON object creation which respects the SGHTTPRequest allowNSNull option.
 * Optional logURL parameter used for logging NSNull stripping to console.
 */

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data logURL:(NSString * _Nullable)logURL;

/**
 * SGJSONSerialization JSON object creation which respects the allowNSNull parameter.
 * Optional logURL parameter used for logging NSNull stripping to console.
 */

+ (nullable id)JSONObjectWithData:(NSData * _Nonnull)data
                      allowNSNull:(BOOL)allowNSNull
                           logURL:(NSString * _Nullable)logURL;

@end
