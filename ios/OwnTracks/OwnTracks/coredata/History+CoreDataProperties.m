//
//  History+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2026 OwnTracks. All rights reserved.
//
//

#import "History+CoreDataProperties.h"

@implementation History (CoreDataProperties)

+ (NSFetchRequest<History *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"History"];
}

@dynamic timestamp;
@dynamic text;
@dynamic group;
@dynamic seen;

@end
