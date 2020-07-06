//
//  SGFileCache.h
//  Pods
//
//  Created by James Van-As on 2/02/16.
//
//

#import <Foundation/Foundation.h>

@interface SGFileCache : NSObject

/**
 * Returns the singleton of the genric file cache.
 * Use cacheFor:(NSString *)cacheName if you want to
 * utilize multiple walled caches.
 */

+ (instancetype)cache;

/**
 * Returns the instance of the file cache for the given cache name.
 */

+ (instancetype)cacheFor:(NSString *)cacheName;

/**
 * Sets the default max-age of cached items.
 * Defaults to 30 days (2592000 seconds)
 */
@property (nonatomic, assign) NSUInteger defaultCacheMaxAge;

/**
 * Sets the maximum size for the disk cache data.  Defaults to 20MB.  For unlimited,
 * set to zero.
 */
@property (nonatomic, assign) NSUInteger maxDiskCacheSizeMB;

/**
 * Clears the disk cache completely.
 */
- (void)clearCache;

/**
 * Clears expired cache items from the disk cache.
 */
- (void)clearExpiredFiles;

/**
 * Remove the cached data for the given key if it exists.
 */
- (void)removeCacheFilesForPrimaryKey:(NSString *)key;

/**
 * Remove all cached data that does not match the given primary keys.
 */
- (void)removeCacheFilesNotMatchingPrimaryKeys:(NSArray *)keys;

/**
 * Remove the cached data for the given keys if they exist.
 */
- (void)removeCacheFilesForPrimaryKeys:(NSArray *)keys;

/**
 * Remove the cached data for the given key if it has expired.
 * Returns YES if files are removed.
 */
- (BOOL)removeCacheFilesIfExpiredForPrimaryKey:(NSString *)key;

/**
 * Whether cached data exist for the given primary key
 * returns YES if there is cached data matching the primary key
 */
- (BOOL)hasCachedDataFor:(NSString *)primaryKey;

/**
 * Whether cached data exist for the given primary and seconday keys.
 * returns YES if there is cached data matching the primary and secondary key.
 */
- (BOOL)hasCachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys;

/**
 * The cached raw data for the given primary key. nil if no cached data.
 * returns nil if no cached data matching the primary and secondary key.
 */
- (NSData *)cachedDataFor:(NSString *)primaryKey;
/**
 * The cached raw data for the given primary and secondary keys. nil if no cached data.
 * secondaryKeys is an optional dict of key -> value mappings (must match to return cache data)
 * returns nil if no cached data matching the primary and secondary key.
 */
- (NSData *)cachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys;

/**
 * The cached raw data for the given primary and secondary keys, and update the expiry date
 * returns nil if no cached data matching the primary and secondary key.
 */

- (NSData *)cachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys newExpiryDate:(NSDate *)newExpiryDate;

/**
 * Get the cached raw data asyncronously for the given primary and secondary keys, and update the expiry date
 */
- (void)getCachedDataAsyncFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys
                newExpiryDate:(NSDate *)newExpiryDate dataCompletion:(void (^)(NSData *))dataCompletion;

/**
 * Cache the raw data for the given primary key, with no expiry date
 */
- (void)cacheData:(NSData *)data for:(NSString *)primaryKey;

/**
 * Cache the raw data for the given primary key, and update the expiry date
 */
- (void)cacheData:(NSData *)data for:(NSString *)primaryKey expiryDate:(NSDate *)expiryDate;

/**
 * Cache the raw data for the given primary and secondary keys, and update the expiry date
 */
- (void)cacheData:(NSData *)data for:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys expiryDate:(NSDate *)expiryDate;

/**
 * Returns the secondary key associated with the given primary key.
 * Can return nil.
 */

- (NSString *)secondaryKeyValueNamed:(NSString *)secondaryKey forPrimaryKey:(NSString *)primaryKey;

/**
 * Optional property to log some cache operations to the console
 */
@property (nonatomic, assign) BOOL logCache;

@end
