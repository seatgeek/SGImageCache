//
//  SGFileCache.m
//  Pods
//
//  Created by James Van-As on 2/02/16.
//
//

#import "SGFileCache.h"
#import <SGHTTPRequest/NSString+SGHTTPRequest.h>
#import <SGHTTPRequest/SGHTTPRequestDebug.h>
#import <UIKit/UIKit.h>

#define SGDataPath          @"dataPath"
#define SGExpiryDate        @"expires"
#define SGDontPurge         @"dontPurge"

@interface SGFileCache ()
@property (nonatomic, strong) NSString *cacheFolder;
@property (nonatomic, strong) NSString *dataFolder;
@end

@implementation SGFileCache

#pragma mark Cache Instances

- (id)init {
    self = [super init];
    self.defaultCacheMaxAge = 2592000;
    self.maxDiskCacheSizeMB = 20;
    return self;
}

+ (instancetype)cache {
    return [self cacheFor:nil];
}

+ (instancetype)cacheFor:(NSString *)cacheName {
    cacheName = cacheName ?: @"DefaultCache";

    static NSMutableDictionary *caches;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        caches = NSMutableDictionary.new;
    });

    NSCharacterSet *illegalFileNameChars = [NSCharacterSet characterSetWithCharactersInString:@":/"];
    cacheName = [[cacheName componentsSeparatedByCharactersInSet:illegalFileNameChars] componentsJoinedByString:@"-"];
    if (!cacheName.length) {
        return nil;
    }

    @synchronized(cacheName) {
        SGFileCache *cache = caches[cacheName];
        if (!cache) {
            cache = SGFileCache.new;

            NSString *cacheFolder = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
            cacheFolder = [cacheFolder stringByAppendingFormat:@"/com.seatgeek.sgfilecache/%@", cacheName];
            BOOL isDir;
            NSString *dataFolder = [cacheFolder stringByAppendingString:@"/Data"];
            if (![NSFileManager.defaultManager fileExistsAtPath:dataFolder isDirectory:&isDir]) {
                [NSFileManager.defaultManager createDirectoryAtPath:dataFolder withIntermediateDirectories:YES
                                                         attributes:nil error:nil];
            }
            cache.cacheFolder = cacheFolder;
            cache.dataFolder = dataFolder;
            caches[cacheName] = cache;
        }
        return cache;
    }
}

#pragma mark Cache Size

- (NSInteger)maxDiskCacheSizeBytes {
    return self.maxDiskCacheSizeMB * 1024 * 1024;
}

#pragma mark Paths

- (NSString *)indexPathForPrimaryKey:(NSString *)primaryKey {
    SGHTTPAssert(primaryKey.length, @"Primary Key must be valid");
    return [NSString stringWithFormat:@"%@/%@", self.cacheFolder, [self indexFileNameForPrimaryKey:primaryKey]];
}

- (NSString *)indexFileNameForPrimaryKey:(NSString *)primaryKey {
    return primaryKey.sgHTTPRequestHash;
}

- (NSString *)fullDataPathFromIndex:(NSDictionary *)index {
    if (!index) {
        return nil;
    }
    NSString *fullDataPath = [NSString stringWithFormat:@"%@/Data/%@", self.cacheFolder, index[SGDataPath]];
    return fullDataPath;
}

#pragma mark Key Handling

- (NSString *)secondaryKeyValueNamed:(NSString *)secondaryKey forPrimaryKey:(NSString *)primaryKey {
    SGHTTPAssert(secondaryKey.length && primaryKey.length, @"Secondary and primary keys must be valid");

    NSString *indexPath = [self indexPathForPrimaryKey:primaryKey];
    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:indexPath];
    if (index) {
        // sanity check that the data file exists.
        NSString *fullDataPath = [self fullDataPathFromIndex:index];
        if ([NSFileManager.defaultManager fileExistsAtPath:fullDataPath]) {
            return index[secondaryKey];
        } else {
#ifdef DEBUG
            NSLog(@"SGHTTPRequest could not find secondary key data for primary key: %@", index[secondaryKey]);
#endif
        }
    }
    return nil;
}

#pragma mark Data File Handling

- (BOOL)hasCachedDataFor:(NSString *)primaryKey {
    return [self hasCachedDataFor:primaryKey secondaryKeys:nil];
}

- (BOOL)hasCachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys {
    return [self hasCachedDataFor:primaryKey secondaryKeys:secondaryKeys indexRef:nil indexPath:nil dataFilePath:nil];
}

- (BOOL)hasCachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys
                indexRef:(NSDictionary **)indexRef indexPath:(NSString **)indexPathRef dataFilePath:(NSString **)dataFilePathRef {
    if (!primaryKey.length) {
        return NO;
    }
    NSString *indexPath = [self indexPathForPrimaryKey:primaryKey];
    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:indexPath];

    for (NSString *key in secondaryKeys) {
        if (![index[key] isEqualToString:secondaryKeys[key]]) {
            return NO;     // keys to the data don't match.
        }
    }
    if (!index[SGDataPath]) {
        return NO;
    }

    NSString *fullDataPath = [self fullDataPathFromIndex:index];
    if (![NSFileManager.defaultManager fileExistsAtPath:fullDataPath]) {
        return NO;
    }

    if (indexRef) {
        *indexRef = index;
    }
    if (indexPathRef) {
        *indexPathRef = indexPath;
    }
    if (dataFilePathRef) {
        *dataFilePathRef = fullDataPath;
    }

    return YES;
}

- (NSData *)cachedDataFor:(NSString *)primaryKey {
    return [self cachedDataFor:primaryKey secondaryKeys:nil];
}

- (NSData *)cachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys {
    return [self cachedDataFor:primaryKey secondaryKeys:secondaryKeys newExpiryDate:nil updateExpiry:NO];
}

- (NSData *)cachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys newExpiryDate:(NSDate *)newExpiryDate {
    return [self cachedDataFor:primaryKey secondaryKeys:secondaryKeys newExpiryDate:newExpiryDate updateExpiry:YES];
}

- (void)getCachedDataAsyncFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys
                newExpiryDate:(NSDate *)newExpiryDate dataCompletion:(void (^)(NSData *))dataCompletion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // todo: use a readers-writer lock on this
        NSData *cachedData = [self cachedDataFor:primaryKey
                                   secondaryKeys:secondaryKeys
                                   newExpiryDate:newExpiryDate];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (dataCompletion) {
                dataCompletion(cachedData);
            }
        });
    });
}

- (NSData *)cachedDataFor:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys newExpiryDate:(NSDate *)newExpiryDate updateExpiry:(BOOL)updateExpiry {
    NSDictionary *index;
    NSString *indexPath;
    NSString *fullDataPath;

    if (![self hasCachedDataFor:primaryKey secondaryKeys:secondaryKeys
                       indexRef:&index indexPath:&indexPath dataFilePath:&fullDataPath]) {
        return nil;
    }

    if (!index || !indexPath || !fullDataPath) {
        SGHTTPAssert(NO, @"This shouldn't happen");
        return nil;
    }

    if (updateExpiry) {
        if ((index[SGExpiryDate] && !newExpiryDate) ||
            (newExpiryDate && !index[SGExpiryDate]) ||
            (newExpiryDate && index[SGExpiryDate] && ![newExpiryDate isEqualToDate:index[SGExpiryDate]])) {
            NSMutableDictionary *newIndex = index.mutableCopy;
            if (newExpiryDate) {
                newIndex[SGExpiryDate] = newExpiryDate;
            } else {
                [newIndex removeObjectForKey:SGExpiryDate];
            }
            [newIndex writeToFile:indexPath atomically:YES];
        }
    }

    // touch the date modified timestamp
    [NSFileManager.defaultManager setAttributes:@{NSFileModificationDate:NSDate.date}
                                   ofItemAtPath:fullDataPath
                                          error:nil];
    return [NSData dataWithContentsOfFile:fullDataPath];
}

- (void)cacheData:(NSData *)data for:(NSString *)primaryKey {
    [self cacheData:data for:primaryKey secondaryKeys:nil expiryDate:nil];
}

- (void)cacheData:(NSData *)data for:(NSString *)primaryKey expiryDate:(NSDate *)expiryDate {
    [self cacheData:data for:primaryKey secondaryKeys:nil expiryDate:expiryDate];
}

- (void)cacheData:(NSData *)data for:(NSString *)primaryKey secondaryKeys:(NSDictionary *)secondaryKeys expiryDate:(NSDate *)expiryDate {
    SGHTTPAssert([NSThread isMainThread], @"This must be run from the main thread");
    if (!primaryKey) {
        SGHTTPAssert(NO, @"Missing primary key");
        return;
    }

    if (!data.length) {
        return;
    }

    if (self.maxDiskCacheSizeMB) {
        if (data.length  > self.maxDiskCacheSizeBytes) {
            return;
        }
        [self purgeOldestCacheFilesLeaving:MAX(self.maxDiskCacheSizeBytes / 4, data.length * 2)];
    }

    NSString *indexPath = [self indexPathForPrimaryKey:primaryKey];
    NSString *fullDataPath = nil;

    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:indexPath];
    if (index[SGDataPath]) {
        fullDataPath = [self fullDataPathFromIndex:index];
    }
    // delete the index file before the data file.  Noone should reference the data file without the index file.
    if ([NSFileManager.defaultManager fileExistsAtPath:indexPath]) {
        [NSFileManager.defaultManager removeItemAtPath:indexPath error:nil];
    }
    if (fullDataPath && [NSFileManager.defaultManager fileExistsAtPath:fullDataPath]) {
        [NSFileManager.defaultManager removeItemAtPath:fullDataPath error:nil];
    }

    NSString *indexFileName = [self indexFileNameForPrimaryKey:primaryKey];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // We write the index file last, because noone will try to access the data file unless the
        // index file exists.  The index file gets written last atomically.
        // data file name format is [indexFileName].[SecondaryKey1].[SecondaryKey2] etc so we can fast map back to the index file
        NSString *dataFileName = [NSString stringWithFormat:@"%@",
                                   indexFileName];
        for (NSString *secondaryKey in secondaryKeys) {
            dataFileName = [dataFileName stringByAppendingFormat:@".%@-%@", secondaryKey, secondaryKeys[secondaryKey]];
        }

        NSCharacterSet *illegalFileNameChars = [NSCharacterSet characterSetWithCharactersInString:@":/"];
        NSString *safeFileName = [[dataFileName componentsSeparatedByCharactersInSet:illegalFileNameChars] componentsJoinedByString:@"-"];
        if (!safeFileName.length) {
            return;
        }

        NSString *fullDataPath = [NSString stringWithFormat:@"%@/Data/%@", self.cacheFolder, safeFileName];
        if (![data writeToFile:fullDataPath atomically:YES]) {
            return;
        }

        NSMutableDictionary *newIndex = @{SGDataPath : safeFileName}.mutableCopy;
        [newIndex addEntriesFromDictionary:secondaryKeys];
        if (expiryDate) {
            newIndex[SGExpiryDate] = expiryDate;
        }
        [newIndex writeToFile:indexPath atomically:YES];
    });
}

#pragma mark Purging

- (void)purgeOldestCacheFilesLeaving:(NSInteger)bytesFree {
    SGHTTPAssert([NSThread isMainThread], @"This must be run from the main thread");

    NSString *dataFolder = [self.cacheFolder stringByAppendingString:@"/Data"];
    NSURL *dataFolderURL = [NSURL URLWithString:dataFolder];
    if (!dataFolderURL) {
        return;
    }
    NSArray *dataFilesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:dataFolderURL
                                                            includingPropertiesForKeys:@[NSURLContentModificationDateKey,
                                                                                         NSURLFileSizeKey]
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                 error:nil];
    NSInteger existingCacheSize = 0;
    for (NSURL *fileURL in dataFilesArray) {
        NSNumber *fileSize;
        [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        existingCacheSize += fileSize.longLongValue;
    }

    if (existingCacheSize + bytesFree < self.maxDiskCacheSizeBytes) {
        return;     // we already have enough space thanks.
    }

    dataFilesArray = [dataFilesArray sortedArrayUsingComparator:^(NSURL *file1, NSURL *file2) {
        NSDate *file1Date;
        [file1 getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:nil];
        NSDate *file2Date;
        [file2 getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:nil];
        return [file1Date compare:file2Date];
    }];

    NSInteger bytesToDelete = bytesFree - (self.maxDiskCacheSizeBytes - existingCacheSize);
    if (bytesToDelete <= 0) {
        return;
    }
    NSInteger bytesDeleted = 0;
    NSMutableArray *filesToDelete = NSMutableArray.new;

    for (NSURL *fileURL in dataFilesArray) {
        if (bytesToDelete <= 0) {
            break;
        }
        NSError *error;

        NSNumber *fileSize;
        [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&error];
        if (error) {
#ifdef DEBUG
            NSLog(@"Error trying to get fileSize from eTag cache file: %@", error);
#endif
        }
        [filesToDelete addObject:fileURL];
        bytesToDelete -= fileSize.longLongValue;
        bytesDeleted += fileSize.longLongValue;
    }

    if (!filesToDelete.count) {
        return;
    }

    if (self.logCache) {
        if (bytesDeleted) {
            NSLog(@"Flushing %.1fMB from %@ cache", (CGFloat)bytesDeleted / 1024.0 / 1024.0, self.cacheFolder);
        }
    }


    NSMutableArray *searchIndexFiles = nil;
    for (NSURL *dataFileURL in filesToDelete) {
        // index path filename should match the data filename.  If not we do the brute force approach.
        NSURL *indexPathToDelete = [self cacheIndexPathFromDataFile:dataFileURL searchIndexFiles:&searchIndexFiles];
        if (indexPathToDelete && [NSFileManager.defaultManager fileExistsAtPath:indexPathToDelete.path]) {
            [searchIndexFiles removeObject:indexPathToDelete];
            if ([NSFileManager.defaultManager fileExistsAtPath:indexPathToDelete.path]) {
                [NSFileManager.defaultManager removeItemAtPath:indexPathToDelete.path error:nil];
            }
        } else {
#ifdef DEBUG
            NSLog(@"Could not find index file for old data file in SGHTTPRequest cache.  Removing orphaned data file.");
#endif
        }
        if ([NSFileManager.defaultManager fileExistsAtPath:dataFileURL.path]) {
            [NSFileManager.defaultManager removeItemAtPath:dataFileURL.path error:nil];
        }
    }
}

- (NSURL *)cacheIndexPathFromDataFile:(NSURL *)dataFileURL searchIndexFiles:(NSMutableArray **)searchIndexFiles {
    NSString *fileNameForCacheIndex = dataFileURL.path.lastPathComponent;

    NSArray *components = [fileNameForCacheIndex componentsSeparatedByString:@"."];
    // data file name format is [indexFileName].[SecondaryKey1].[SecondaryKey2] etc so we can fast map back to the index file

    fileNameForCacheIndex = components.firstObject;
    NSString *indexPath = [NSString stringWithFormat:@"%@/%@", self.cacheFolder, fileNameForCacheIndex];
    if ([NSFileManager.defaultManager fileExistsAtPath:indexPath]) {
        return [NSURL URLWithString:indexPath];
    }

    // below is a brute force approach for legacy purposes
    // where the data filename might not map back to the index filename.
    // Grabbing the contents of the directory is only done once and only if necessary
    // because it's slow.

    if (!*searchIndexFiles) {
        // sort the index files by date modified too for fast search.  Should be almost identical to the data order
        NSString *indexFolder = self.cacheFolder;
        NSArray *indexFilesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:indexFolder]
                                                                 includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                      error:nil];
        indexFilesArray = [indexFilesArray sortedArrayUsingComparator:^(NSURL *file1, NSURL *file2) {
            NSDate *file1Date;
            [file1 getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:nil];
            NSDate *file2Date;
            [file2 getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:nil];
            return [file1Date compare:file2Date];
        }];
        *searchIndexFiles = indexFilesArray.mutableCopy;
    }
    for (NSURL *indexFileURL in *searchIndexFiles) {
        NSDictionary *index = [NSDictionary dictionaryWithContentsOfURL:indexFileURL];
        if (index[SGDataPath]) {
            NSString *fullDataPath = [self fullDataPathFromIndex:index];
            NSURL *fullDataURL = [NSURL fileURLWithPath:fullDataPath];
            if ([fullDataURL isEqual:dataFileURL.URLByResolvingSymlinksInPath]) {
                return indexFileURL;
            }
        }
    }
#ifdef DEBUG
    NSLog(@"Couldn't find index file for cached SGHTTPRequest data file.");
#endif
    return nil;
}

- (void)removeCacheFilesForIndexPath:(NSString *)indexPath index:(NSDictionary *)index {
    // delete the index file before the data to maintain data link integrity
    if ([NSFileManager.defaultManager fileExistsAtPath:indexPath]) {
        [NSFileManager.defaultManager removeItemAtPath:indexPath error:nil];
    }
    if (index[SGDataPath]) {
        NSString *fullDataPath = [self fullDataPathFromIndex:index];
        if ([NSFileManager.defaultManager fileExistsAtPath:fullDataPath]) {
            [NSFileManager.defaultManager removeItemAtPath:fullDataPath error:nil];
        }
    }
}

- (void)removeCacheFilesForPrimaryKey:(NSString *)key {
    [self removeCacheFilesForIndexPath:[self indexPathForPrimaryKey:key]];
}

- (void)removeCacheFilesForPrimaryKeys:(NSArray *)keys {
    for (NSString *key in keys) {
        [self removeCacheFilesForPrimaryKey:key];
    }
}

- (void)removeCacheFilesNotMatchingPrimaryKeys:(NSArray *)keys {
    if (!keys.count) {
        return;
    }

    SGHTTPAssert([NSThread isMainThread], @"This must be run from the main thread");

    NSMutableArray *remainingIndexPathsToCheck = NSMutableArray.new;
    for (NSString *key in keys) {
        NSString *indexFileName = [NSURL fileURLWithPath:[self indexPathForPrimaryKey:key]].absoluteString.lastPathComponent;
        if (indexFileName) {
            [remainingIndexPathsToCheck addObject:indexFileName];
        }
    }

    NSString *indexFolder = self.cacheFolder;
    NSArray *indexFilesArray = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL URLWithString:indexFolder]
                                                           includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                              options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                                error:nil];
    NSMutableArray *filesToDelete = NSMutableArray.new;

    for (NSURL *fileURL in indexFilesArray) {
        NSError *error;
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        if (error || isDirectory.boolValue) {
            continue;
        }

        NSString *fileName;
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:&error];
        if (error) {
            continue;
        }

        BOOL found = NO;
        for (NSString *fileToKeep in remainingIndexPathsToCheck) {
            if ([fileToKeep isEqualToString:fileName]) {
                found = YES;
                [remainingIndexPathsToCheck removeObject:fileToKeep];
                break;
            }
        }
        if (!found) {
            [filesToDelete addObject:fileURL];
        }
    }

    if (!filesToDelete.count) {
        return;
    }

    if (self.logCache) {
        NSLog(@"Flushing %@ files not matching primary keys from %@ cache", @(filesToDelete.count), self.cacheFolder);
    }

    for (NSURL *indexFileURL in filesToDelete) {
        [self removeCacheFilesForIndexPath:indexFileURL.path];
    }
}

- (BOOL)removeCacheFilesIfExpiredForPrimaryKey:(NSString *)key {
    return [self removeCacheFilesIfExpiredForIndexPath:[self indexPathForPrimaryKey:key]];
}

- (void)removeCacheFilesForIndexPath:(NSString *)indexPath {
    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:indexPath];
    [self removeCacheFilesForIndexPath:indexPath index:index];
}

- (BOOL)removeCacheFilesIfExpiredForIndexPath:(NSString *)indexPath {
    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:indexPath];

    BOOL dataFileMissing = NO;
    if (index[SGDataPath]) {
        NSString *fullDataPath = [self fullDataPathFromIndex:index];
        if (![NSFileManager.defaultManager fileExistsAtPath:fullDataPath]) {
            dataFileMissing = YES;
        }
    }

    if (dataFileMissing ||
        (index[SGExpiryDate] && [(NSDate *)index[SGExpiryDate] compare:NSDate.date] == NSOrderedAscending)) {
        [self removeCacheFilesForIndexPath:indexPath index:index];
        return YES;
    }
    return NO;
}

- (void)clearCache {
    SGHTTPAssert([NSThread isMainThread], @"This must be run from the main thread");

    NSString *indexFolder = self.cacheFolder;
    NSMutableArray *indexFileNamesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:indexFolder error:nil].mutableCopy;
    NSMutableArray *indexFilesArray = NSMutableArray.new;
    for (NSString *indexFileName in indexFileNamesArray) {
        [indexFilesArray addObject:[indexFolder stringByAppendingPathComponent:indexFileName]];
    }

    for (NSString *filePath in indexFilesArray) {
        BOOL isDirectory = NO;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:filePath isDirectory:&isDirectory];
        if (exists && !isDirectory) {
            [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
        }
    }

    NSString *dataFolder = [self.cacheFolder stringByAppendingString:@"/Data"];
    NSArray *dataFilesNamesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dataFolder error:nil];
    NSMutableArray *dataFilesArray = NSMutableArray.new;
    for (NSString *dataFileName in dataFilesNamesArray) {
        [dataFilesArray addObject:[dataFolder stringByAppendingPathComponent:dataFileName]];
    }

    for (NSString *filePath in dataFilesArray) {
        if ([NSFileManager.defaultManager fileExistsAtPath:filePath]) {
            [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
        }
    }
}

- (void)clearExpiredFiles {
    NSString *cacheFolder = self.cacheFolder;
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:cacheFolder error:nil];

    for (NSString *file in files) {
        if ([file isEqualToString:@"."] || [file isEqualToString:@".."]) {
            continue;
        }
        NSString *indexFile = [cacheFolder stringByAppendingPathComponent:file];
        [self removeCacheFilesIfExpiredForIndexPath:indexFile];
    }
}

@end
