//
//  ConnType.m
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016-2026  OwnTracks. All rights reserved.
//

#import "ConnType.h"

#import <Network/Network.h>
#import "OwnTracksLog.h"

@interface ConnType()
@property nw_path_monitor_t pm;
@property (nonatomic, readwrite) ConnectionType connectionType;
@property (strong, nonatomic, readwrite, nullable) NSString* ssid;
@property (strong, nonatomic, readwrite, nullable) NSString* bssid;
@property (nonatomic, readwrite) NEHotspotNetworkSecurityType securityType;

@end

@implementation ConnType


- (instancetype)init {
    self = super.init;
    self.connectionType = ConnectionTypeUnknown;
    self.ssid = NULL;
    self.bssid = NULL;
    self.securityType = NEHotspotNetworkSecurityTypeUnknown;
    self.pm = nw_path_monitor_create();
    nw_path_monitor_set_queue(self.pm, dispatch_get_main_queue());
    nw_path_monitor_set_update_handler(self.pm, ^(nw_path_t  _Nonnull path) {
        nw_path_status_t status = nw_path_get_status(path);
        const char *statusText = "unknown";
        switch (status) {
            case nw_path_status_invalid:
                statusText = "invalid";
                self.connectionType = ConnectionTypeUnknown;
                break;
            case nw_path_status_satisfied:
                statusText = "satisfied";
                self.connectionType = ConnectionTypeUnknown;
                break;
            case nw_path_status_satisfiable:
                statusText = "satisfiable";
                self.connectionType = ConnectionTypeUnknown;
                break;
            case nw_path_status_unsatisfied:
                statusText = "unsatisfied";
                self.connectionType = ConnectionTypeNone;
                break;
        }
        bool ipv4 = nw_path_has_ipv4(path);
        bool ipv6 = nw_path_has_ipv6(path);
        bool dns = nw_path_has_dns(path);
        bool constrained = nw_path_is_constrained(path);
        bool expensive = nw_path_is_expensive(path);
        OwnTracksLogDebug("[ConnType] path status=%s ipv4=%d ipv6=%d dns=%d constrained=%d expensive=%d",
                          statusText, ipv4, ipv6, dns, constrained, expensive);

        nw_path_enumerate_gateways(path, ^bool(nw_endpoint_t  _Nonnull gateway) {
            nw_endpoint_type_t type = nw_endpoint_get_type(gateway);
            const char *typeText = "unknown";
            switch (type) {
                case nw_endpoint_type_url:
                    typeText = "url";
                    break;
                case nw_endpoint_type_host:
                    typeText = "host";
                    break;
                case nw_endpoint_type_address:
                    typeText = "address";
                    break;
                case nw_endpoint_type_invalid:
                    typeText = "invalid";
                    break;
                case nw_endpoint_type_bonjour_service:
                    typeText = "bonjour";
                    break;
            }
            const char *hostname = "unknown";
            hostname = nw_endpoint_get_hostname(gateway);
            OwnTracksLogDebug("[ConnType] gateway type=%s hostname=%s",
                              typeText, hostname);
            return TRUE;
        });
        nw_path_enumerate_interfaces(path, ^bool(nw_interface_t  _Nonnull interface) {
            nw_interface_type_t type =  nw_interface_get_type(interface);
            const char *typeText = "unknown";
            switch (type) {
                case nw_interface_type_wifi:
                    typeText = "wifi";
                    self.connectionType = ConnectionTypeWIFI;
                    break;
                case nw_interface_type_other:
                    typeText = "other";
                    break;
                case nw_interface_type_wired:
                    typeText = "wired";
                    break;
                case nw_interface_type_cellular:
                    typeText = "cellular";
                    if (self.connectionType != ConnectionTypeWIFI) {
                        self.connectionType = ConnectionTypeWWAN;
                    }
                    break;
                case nw_interface_type_loopback:
                    typeText = "loopback";
                    break;
            }
            const char *name = nw_interface_get_name(interface);
            uint32_t index = nw_interface_get_index(interface);
            OwnTracksLogDebug("[ConnType] interface type=%s name=%s index=%d",
                              typeText, name, index);
            return TRUE;
        });
        [self updateWifi];
    });

    nw_path_monitor_start(self.pm);

    return self;
}

- (void)updateWifi {
    [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
        if (currentNetwork != NULL) {
            const char *securityTypeText = "unknown";
            switch (currentNetwork.securityType) {
                case NEHotspotNetworkSecurityTypeOpen:
                    securityTypeText = "open";
                    break;
                case NEHotspotNetworkSecurityTypeWEP:
                    securityTypeText = "WEP";
                    break;
                case NEHotspotNetworkSecurityTypePersonal:
                    securityTypeText = "personal";
                    break;
                case NEHotspotNetworkSecurityTypeEnterprise:
                    securityTypeText = "enterprise";
                    break;
                case NEHotspotNetworkSecurityTypeUnknown:
                    securityTypeText = "unknown";
                    break;
            }
            OwnTracksLogDebug("[ConnType] currentNetwork BSSID=%@ SSID=%@ securityType=%s",
                              currentNetwork.BSSID, currentNetwork.SSID, securityTypeText);
            self.bssid = currentNetwork.BSSID;
            self.ssid = currentNetwork.SSID;
            self.securityType = currentNetwork.securityType;
        } else {
            OwnTracksLogDefault("[ConnType] currentNetwork is NULL");
            self.bssid = nil;
            self.ssid = nil;
            self.securityType = NEHotspotNetworkSecurityTypeUnknown;
        }
    }];
}

@end
