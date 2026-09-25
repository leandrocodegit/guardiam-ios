//
//  OwnTracksLog.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.01.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

#import "OwnTracksLog.h"

@interface OwnTracksLog()
@property (nonatomic, nonnull, strong, readwrite) os_log_t os_log;
@end

@implementation OwnTracksLog
+ (OwnTracksLog *)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    self.os_log = os_log_create("org.mqttitude", "MQTTitude");
    return self;
}

@end
