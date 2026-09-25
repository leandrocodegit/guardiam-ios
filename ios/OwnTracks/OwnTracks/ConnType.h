//
//  ConnType.h
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016-2026  OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NEHotspotNetwork.h>

/**
 Enumeration of MQTTSession states
 */
typedef NS_ENUM(NSInteger, ConnectionType) {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionTypeWWAN,
    ConnectionTypeWIFI
};

@interface ConnType : NSObject
@property (nonatomic, readonly) ConnectionType connectionType;
@property (strong, nonatomic, readonly, nullable) NSString* ssid;
@property (strong, nonatomic, readonly, nullable) NSString* bssid;
@property (nonatomic, readonly) NEHotspotNetworkSecurityType securityType;

@end
