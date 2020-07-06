//
//  NSString+SGHTTPRequest.h
//  Pods
//
//  Created by James Van-As on 29/06/15.
//
//

#import <Foundation/Foundation.h>

@interface NSString (SGHTTPRequest)
- (BOOL)containsSubstring:(NSString *)substring;
- (NSString *)sgHTTPRequestHash;
@end
