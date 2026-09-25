//
//  CoreData.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2026  Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreData : NSObject
@property (readonly, nonnull, strong, nonatomic) NSManagedObjectContext *mainMOC;
@property (readonly, nonnull, strong, nonatomic) NSManagedObjectContext *queuedMOC;
@property (readonly, nonnull, strong, nonatomic) NSPersistentStoreCoordinator *PSC;

+ (nonnull CoreData *)sharedInstance;
- (void)sync:(nonnull NSManagedObjectContext *)context;
@end
