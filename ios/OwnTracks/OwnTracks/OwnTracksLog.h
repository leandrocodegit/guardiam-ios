//
//  OwnTracksLog.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.01.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OSLog/OSLog.h>

NS_ASSUME_NONNULL_BEGIN

@interface OwnTracksLog : NSObject
 
+ (OwnTracksLog * _Nonnull )sharedInstance;
@property (nonatomic, nonnull, strong, readonly) os_log_t os_log;

#ifdef DEBUG
#define OwnTracksLogDebug(format, ...) os_log_debug(OwnTracksLog.sharedInstance.os_log, format, ##__VA_ARGS__)
#else
#define OwnTracksLogDebug(format, ...)
#endif
#define OwnTracksLogInfo(format, ...) os_log_info(OwnTracksLog.sharedInstance.os_log, format, ##__VA_ARGS__)
#define OwnTracksLogDefault(format, ...) os_log(OwnTracksLog.sharedInstance.os_log, format, ##__VA_ARGS__)
#define OwnTracksLogError(format, ...) os_log_error(OwnTracksLog.sharedInstance.os_log, format, ##__VA_ARGS__)
#define OwnTracksLogFault(format, ...) os_log_fault(OwnTracksLog.sharedInstance.os_log, format, ##__VA_ARGS__)

@end

NS_ASSUME_NONNULL_END
