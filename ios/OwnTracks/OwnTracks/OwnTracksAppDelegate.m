
//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright Â© 2014-2026  OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <WebKit/WebKit.h>

#import "CoreData.h"
#import "Setting+CoreDataClass.h"
#import "History+CoreDataClass.h"
#import "Settings.h"
#import "OwnTracking.h"
#import "Tours.h"
#import "ConnType.h"
#import "NSNumber+decimals.h"
#import "Validation.h"

//#import "OwnTracksChangeMonitoringIntent.h"
//#import "OwnTracksTagIntent.h"
//#import "OwnTracksPointOfInterestIntent.h"
#import "OwnTracks-Swift.h"
@import FirebaseCore;
@import FirebaseMessaging;

@interface OwnTracksAppDelegate()

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) NSString *backgroundFetchCheckMessage;

@property (strong, nonatomic) BGTask *bgTask;

@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) CMPedometer *pedometer;

#define BACKGROUND_DISCONNECT_AFTER 25.0
#define BACKGROUND_HOLD_FOR 10.0
@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *holdTimer;
@property (strong, nonatomic) NSTimer *bgTimer;

@property (strong, nonatomic) ConnType *connType;

- (void)connectForcingCleanSession:(BOOL)cleanSession;
- (BOOL)processURIBeacon:(NSURL *)url;
- (BOOL)processURIConfig:(NSURL *)url;
- (BOOL)processFile:(NSURL *)url;
- (void)performReceiveEvent:(NSDictionary *)userInfo;

@end

@implementation OwnTracksAppDelegate

- (instancetype)init {
    self = [super init];
    self.inQueue = @(0);
    self.connType = [[ConnType alloc] init];
    return self;
}

- (void)syncProcessing {
    while ((self.inQueue).unsignedLongValue > 0) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] syncProcessing %lu", [self.inQueue unsignedLongValue]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    };
}

- (void)setShortcutItems {
    UIApplication *application = [UIApplication sharedApplication];
    application.shortcutItems = @[];
}


#pragma ApplicationDelegate

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder  API_AVAILABLE(ios(13.0)){
    [builder removeMenuForIdentifier:UIMenuHelp];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    
    OwnTracksLogDefault("[OwnTracksAppDelegate] OwnTracks starting %@/%@ %@",
                        [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                        [NSLocale currentLocale].localeIdentifier,
                        launchOptions);
    
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    
    [self setShortcutItems];
    
#define TASK_IDENTIFIER @"updateSituation"
    BOOL success = [[BGTaskScheduler sharedScheduler]
                    registerForTaskWithIdentifier:TASK_IDENTIFIER
                    usingQueue:nil
                    launchHandler:^(__kindof BGTask * _Nonnull task) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] launchHandler %@",
                     task.identifier);
        
        task.expirationHandler = ^{
            OwnTracksLogDefault("[OwnTracksAppDelegate] bgTaskExpirationHandler");
            if (self.bgTask) {
                [self.bgTask setTaskCompletedWithSuccess:FALSE];
                self.bgTask = nil;
            }
        };
        self.bgTask = task;
        [self performSelectorOnMainThread:@selector(doRefresh)
                               withObject:nil
                            waitUntilDone:TRUE];
        [self scheduleRefreshTask];
    }];
    OwnTracksLogDefault("[OwnTracksAppDelegate] registerForTaskWithIdentifier %@ %d",
                        TASK_IDENTIFIER, success);
    
    [self scheduleRefreshTask];
    self.backgroundTask = UIBackgroundTaskInvalid;
    
    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            OwnTracksLogDefault("[OwnTracksAppDelegate] UIBackgroundRefreshStatusAvailable");
            break;
        case UIBackgroundRefreshStatusDenied:
            OwnTracksLogDefault("[OwnTracksAppDelegate] UIBackgroundRefreshStatusDenied");
            break;
        case UIBackgroundRefreshStatusRestricted:
            OwnTracksLogDefault("[OwnTracksAppDelegate] UIBackgroundRefreshStatusRestricted");
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You cannot use background fetch",
                                                                 @"You cannot use background fetch");
            break;
    }
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options =
    UNAuthorizationOptionSound |
    UNAuthorizationOptionAlert |
    UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] UNUserNotificationCenter requestAuthorizationWithOptions granted:%d error:%@",
                            granted, error);
    }];
    center.delegate = self;
        
    return YES;
}

- (void)scheduleRefreshTask {
    NSError *error;
    BGAppRefreshTaskRequest *bgAppRefreshTaskRequest =
    [[BGAppRefreshTaskRequest alloc] initWithIdentifier:TASK_IDENTIFIER];
    BOOL success = [[BGTaskScheduler sharedScheduler] submitTaskRequest:bgAppRefreshTaskRequest error:&error];
    OwnTracksLogDebug("[OwnTracksAppDelegate] submitTaskRequest %@ @ %@ %d, %@",
                 bgAppRefreshTaskRequest.identifier,
                 bgAppRefreshTaskRequest.earliestBeginDate,
                 success,
                 error);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    OwnTracksLogDebug("[OwnTracksAppDelegate] didFinishLaunchingWithOptions %@", launchOptions);
    
    [FIRApp configure];
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    [FIRMessaging messaging].delegate = self;
    
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    
    UNNotificationAction *confirmAction = [UNNotificationAction actionWithIdentifier:@"CONFIRM_BIPE_ACTION" title:@"Confirmar" options:UNNotificationActionOptionForeground];
    UNNotificationCategory *bipeCategory = [UNNotificationCategory categoryWithIdentifier:@"BIPE_CATEGORY" actions:@[confirmAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithObject:bipeCategory]];
    
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] Notification authorization granted: %d, error: %@", granted, error);
    }];
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error) {
            OwnTracksLogError("[OwnTracksAppDelegate] Error fetching FCM registration token: %@", error);
        } else if (token) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] FCM direct token: %@", token);
            [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"fcm_token"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            NSDictionary *dataDict = @{@"token" : token};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FCMToken" object:nil userInfo:dataDict];
        }
    }];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
    
    // Inicia listener continuo e forca a sincronizacao imediata dos tokens com o backend
    [SetupService.shared startPushToStartTokenSyncListener];
    [SetupService.shared triggerTokenSyncImmediately];
    
    // Inicia o aplicativo e o monitoramento diretamente (sem necessidade de login)
    [self startOwnTracksMonitoring];
    
    return YES;
}

- (void)startOwnTracksMonitoring {
    OwnTracksLogDefault("[OwnTracksAppDelegate] startOwnTracksMonitoring");
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    [self.connection start];
    
    [self connectForcingCleanSession:FALSE];
    
    LocationManager *locationManager = [LocationManager sharedInstance];
    locationManager.delegate = self;
    
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    locationManager.monitoring = [Settings intForKey:@"monitoring_preference"
                                               inMOC:moc];
    locationManager.ranging = [Settings boolForKey:@"ranging_preference"
                                             inMOC:moc];
    locationManager.minDist = [Settings doubleForKey:@"mindist_preference"
                                               inMOC:moc];
    locationManager.minTime = [Settings doubleForKey:@"mintime_preference"
                                               inMOC:moc];
    [locationManager start];
}

- (void)presentLoginViewController {
    OwnTracksLogDefault("[OwnTracksAppDelegate] presentLoginViewController");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        LoginViewController *loginVC = [[LoginViewController alloc] init];
        loginVC.managedObjectContext = CoreData.sharedInstance.mainMOC;
        loginVC.modalPresentationStyle = UIModalPresentationFullScreen;
        
        // Usa o mÃ©todo @objc wrapper â€” propriedades Swift de closure opcional nÃ£o sÃ£o acessÃ­veis via ObjC.
        // O LoginViewController dispensa a si mesmo antes de chamar este bloco.
        __weak OwnTracksAppDelegate *weakSelf = self;
        [loginVC setCompletionHandler:^{
            OwnTracksLogDefault("[OwnTracksAppDelegate] Setup concluído — iniciando monitoramento");
            [weakSelf startOwnTracksMonitoring];
            UIViewController *rootVC = weakSelf.window.rootViewController;
            if ([rootVC respondsToSelector:@selector(loadAndroidSetupRoute)]) {
                [rootVC performSelector:@selector(loadAndroidSetupRoute)];
            }
        }];
        
        UIViewController *rootVC = self.window.rootViewController;
        [rootVC presentViewController:loginVC animated:YES completion:nil];
    });
}

#pragma mark - openURL (unified handler)
//
// NOTE: Previously this file declared TWO methods with the exact same
// selector `application:openURL:options:` (the generic type of the
// `options` dictionary parameter does not change the selector). Only one
// of them was ever actually invoked at runtime, which meant the Keycloak
// auth-callback handling below was silently dead code. They have been
// merged into a single method.
//
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {

    OwnTracksLogDefault("[OwnTracksAppDelegate] openURL %@ options %@", url, options);

    if (!url) {
        self.processingMessage = NSLocalizedString(@"no url specified",
                                                   @"Display after trying to process a file");
        OwnTracksLogError("[OwnTracksAppDelegate] no url specified");
        return FALSE;
    }

    // Redirecionar para o AuthManager tratar o callback do Keycloak (owntracks://auth ou bipe.me://auth)
    if (([url.scheme isEqualToString:@"owntracks"] || [url.scheme isEqualToString:@"bipe.me"]) && [url.host isEqualToString:@"auth"]) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] openURL auth callback: %@", url);
        return [AuthManager.shared handleRedirectURL:url];
    }

    // Handlers para esquemas de URL do Botão de Ação / Atalhos (ex: bipe.me://emergency, bipe.me://panic, bipe.me://alerta, owntracks://emergency)
    NSString *host = [url.host lowercaseString];
    NSString *path = [url.path lowercaseString];
    if ([host isEqualToString:@"emergency"] || [host isEqualToString:@"panic"] || [host isEqualToString:@"alerta"] ||
        [path isEqualToString:@"/emergency"] || [path isEqualToString:@"/panic"] || [path isEqualToString:@"/alerta"]) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] Trigger de emergência via URL: %@", url);
        [BipeEmergencyHelper sendEmergencyAlert];
        return TRUE;
    }

    // Handler para confirmação de bipe via URL (ex: bipe://confirm?execucaoId=123 ou bipe.me://confirm?execucaoId=123)
    if ([host isEqualToString:@"confirm"] || [path isEqualToString:@"/confirm"] || ([url.scheme isEqualToString:@"bipe"] && [host isEqualToString:@"confirm"])) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *execucaoId = nil;
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"execucaoId"] || [item.name isEqualToString:@"execucao_id"]) {
                execucaoId = item.value;
                break;
            }
        }
        OwnTracksLogDefault("[OwnTracksAppDelegate] Link bipe://confirm recebido com execucaoId: %@", execucaoId);
        return YES;
    }

    if ([host isEqualToString:@"activity-history"] || [path isEqualToString:@"/activity-history"]) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] Link bipe://activity-history recebido");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LoadActivityHistory" object:nil];
        return YES;
    }

    // Handler para Modo Sentinela via URL (ex: bipe://sentinel/start, bipe://sentinel/stop, bipe://sentinel/cancel)
    if ([host isEqualToString:@"sentinel"] || [path hasPrefix:@"/sentinel"]) {
        if ([path isEqualToString:@"/start"] || [url.query containsString:@"action=start"]) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] Ativando Modo Sentinela via URL");
            [SentinelAcousticMonitor startMonitoring];
            return YES;
        } else if ([path isEqualToString:@"/stop"] || [url.query containsString:@"action=stop"]) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] Desativando Modo Sentinela via URL");
            [SentinelAcousticMonitor stopMonitoring];
            return YES;
        } else if ([path isEqualToString:@"/cancel"] || [url.query containsString:@"action=cancel"]) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] Cancelando Grace Period do Modo Sentinela via URL");
            [SentinelAcousticMonitor cancelGracePeriod];
            return YES;
        }
    }


    OwnTracksLogDebug("[OwnTracksAppDelegate] URL scheme %@", url.scheme);

    if ([url.scheme isEqualToString:@"owntracks"]) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] URL path %@ query %@", url.path, url.query);
        if (![Settings theallowConfigurationByURIAndConfigFileInMOC:CoreData.sharedInstance.mainMOC]) {
            self.processingMessage = NSLocalizedString(@"URI or file configuration not allowed",
                                                       @"URI or file configuration not allowed");
            OwnTracksLogError("[OwnTracksAppDelegate] URI or file configuration not allowed");
            return FALSE;
        }
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:TRUE];
        NSArray<NSURLQueryItem *> *items = [components queryItems];
        NSMutableDictionary *queryStrings = [[NSMutableDictionary alloc] init];
        for (NSURLQueryItem *item in items) {
            queryStrings[item.name] = item.value;
        }

        if ([url.path isEqualToString:@"/beacon"]) {
            return [self processURIBeacon:queryStrings];
        } else if ([url.path isEqualToString:@"/config"]) {
            return [self processURIConfig:queryStrings];
        } else {
            self.processingMessage = NSLocalizedString(@"unknown url path",
                                                       @"Display for unknown url path");
            OwnTracksLogError("[OwnTracksAppDelegate] unknown url path %@", url.path);
            return FALSE;
        }
    } else if ([url.scheme isEqualToString:@"file"]) {
        if (![Settings theallowConfigurationByURIAndConfigFileInMOC:CoreData.sharedInstance.mainMOC]) {
            self.processingMessage = NSLocalizedString(@"URI or file configuration not allowed",
                                                       @"URI or file configuration not allowed");
            OwnTracksLogError("[OwnTracksAppDelegate] URI or file configuration not allowed");
            return FALSE;
        }
        [self processFile:url];
        return TRUE;

    } else {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                  NSLocalizedString(@"unknown scheme in url",
                                                    @"Display after entering an unknown scheme in url"),
                                  url.scheme];
        OwnTracksLogError("[OwnTracksAppDelegate] unkonwn scheme in URL %@", url.scheme);
        return FALSE;
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    OwnTracksLogDebug("[OwnTracksAppDelegate] willPresentNotification");
    
    NSDictionary *userInfo = notification.request.content.userInfo;
    NSString *type = nil;
    if (userInfo[@"type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"type"]];
    } else if ([userInfo[@"data"] isKindOfClass:[NSDictionary class]] && userInfo[@"data"][@"type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"data"][@"type"]];
    }
    
    if ([type.lowercaseString isEqualToString:@"vibrate"] || [type.lowercaseString isEqualToString:@"emergency"] || [type.lowercaseString isEqualToString:@"sentinela"] || [type.lowercaseString containsString:@"bipe"]) {
        [BipeHapticsHelper playAttentionVibrationWithDurationSeconds:6.0];
    }

    NSDictionary *apsDict = [userInfo[@"aps"] isKindOfClass:[NSDictionary class]] ? userInfo[@"aps"] : nil;
    BOOL hasLiveActivityPayload = userInfo[@"way"] != nil ||
                                  [type.lowercaseString containsString:@"transition"] ||
                                  [type.lowercaseString containsString:@"emergency"] ||
                                  [type.lowercaseString containsString:@"sentinela"] ||
                                  [type.lowercaseString containsString:@"bipe"] ||
                                  apsDict[@"content-state"] != nil ||
                                  apsDict[@"contentState"] != nil;

    if (hasLiveActivityPayload) {
        // Suprime o banner convencional duplicado para Live Activities
        completionHandler(UNNotificationPresentationOptionSound);
    } else {
        completionHandler(UNNotificationPresentationOptionList |
                          UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionSound);
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    OwnTracksLogDefault("[OwnTracksAppDelegate] didRegisterForRemoteNotificationsWithDeviceToken: %@", deviceToken);
    [FIRMessaging messaging].APNSToken = deviceToken;
    [SetupService.shared triggerTokenSyncImmediately];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    OwnTracksLogError("[OwnTracksAppDelegate] didFailToRegisterForRemoteNotificationsWithError: %@", error);
}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    OwnTracksLogDefault("[OwnTracksAppDelegate] FCM Registration Token: %@", fcmToken);
    if (fcmToken) {
        [[NSUserDefaults standardUserDefaults] setObject:fcmToken forKey:@"fcm_token"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSDictionary *dataDict = @{@"token" : fcmToken};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FCMToken" object:nil userInfo:dataDict];
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    OwnTracksLogDefault("[OwnTracksAppDelegate] didReceiveRemoteNotification: %@", userInfo);
    
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithName:@"BipeLiveActivityPushTask" expirationHandler:^{
        if (bgTask != UIBackgroundTaskInvalid) {
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }
    }];
    
    NSString *type = nil;
    if (userInfo[@"type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"type"]];
    } else if (userInfo[@"_type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"_type"]];
    } else if ([userInfo[@"data"] isKindOfClass:[NSDictionary class]] && userInfo[@"data"][@"type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"data"][@"type"]];
    } else if ([userInfo[@"data"] isKindOfClass:[NSDictionary class]] && userInfo[@"data"][@"_type"]) {
        type = [NSString stringWithFormat:@"%@", userInfo[@"data"][@"_type"]];
    } else if ([userInfo[@"data"] isKindOfClass:[NSString class]]) {
        NSData *data = [(NSString *)userInfo[@"data"] dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([dataDict isKindOfClass:[NSDictionary class]]) {
            if (dataDict[@"type"]) type = [NSString stringWithFormat:@"%@", dataDict[@"type"]];
            else if (dataDict[@"_type"]) type = [NSString stringWithFormat:@"%@", dataDict[@"_type"]];
        }
    }
    
    if ([type.lowercaseString isEqualToString:@"vibrate"] || [type.lowercaseString isEqualToString:@"emergency"] || [type.lowercaseString isEqualToString:@"sentinela"] || [type.lowercaseString containsString:@"bipe"]) {
        [BipeHapticsHelper playAttentionVibrationWithDurationSeconds:6.0];
    }
    
    // Se o payload conter campos de evento do Bipe, processamos via a mesma função do MQTT
    if (userInfo[@"event"] != nil || userInfo[@"desc"] != nil || userInfo[@"text"] != nil || userInfo[@"nickname"] != nil || type != nil) {
        [self performReceiveEvent:userInfo];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completionHandler(UIBackgroundFetchResultNewData);
        if (bgTask != UIBackgroundTaskInvalid) {
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }
    });
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    if ([response.actionIdentifier isEqualToString:@"CONFIRM_BIPE_ACTION"]) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] Ação CONFIRM_BIPE_ACTION disparada pelo usuário");
        
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        json[@"_type"] = @"bipe";
        json[@"status"] = @"COMPLETED";
        json[@"button"] = @"TOUCH";
        
        if (response.notification.request.content.userInfo[@"execucaoId"]) {
            json[@"execucaoId"] = response.notification.request.content.userInfo[@"execucaoId"];
        }
        
        NSString *userName = [Settings stringForKey:@"user_preference" inMOC:moc];
        if (userName && userName.length > 0) {
            json[@"userName"] = userName;
        }
        
        NSString *clienteId = [Settings stringForKey:@"clientid_preference" inMOC:moc];
        if (clienteId && clienteId.length > 0) {
            json[@"clienteId"] = clienteId;
        }
        
        NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:moc];
        if (tid && tid.length > 0) json[@"tid"] = tid;
        
        NSString *deviceId = [Settings stringForKey:@"deviceid_preference" inMOC:moc];
        if (deviceId && deviceId.length > 0) json[@"deviceId"] = deviceId;
        
        NSString *nickname = [Settings stringForKey:@"device_name_preference" inMOC:moc];
        if (!nickname || nickname.length == 0) nickname = [Settings stringForKey:@"nickname_preference" inMOC:moc];
        if (nickname && nickname.length > 0) json[@"nickname"] = nickname;
        
        NSString *face = [Settings stringForKey:@"icon" inMOC:moc];
        if (face && face.length > 0) json[@"face"] = face;
        
        NSString *color = [Settings stringForKey:@"color" inMOC:moc];
        if (color && color.length > 0) json[@"color"] = color;
        
        NSError *error;
        NSData *payload = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
        if (payload && !error) {
            if (!self.connection) {
                self.connection = [[Connection alloc] init];
                self.connection.delegate = self;
                [self.connection start];
            }
            
            NSString *baseTopic = [Settings theGeneralTopicInMOC:moc];
            NSString *topic = baseTopic ? [baseTopic stringByAppendingString:@"/bipe"] : @"";
            
            [self.connection sendData:payload
                                topic:topic
                           topicAlias:nil
                                  qos:[Settings intForKey:@"qos_preference" inMOC:moc]
                               retain:NO];
            OwnTracksLogDefault("[OwnTracksAppDelegate] MQTT Payload bipe_confirm enviado");
        }
    } else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        if ([response.notification.request.content.categoryIdentifier isEqualToString:@"BIPE_CATEGORY"]) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] Ação Padrão no Push BIPE_CATEGORY (App Aberto pelo Push)");
            
            NSDictionary *userInfo = response.notification.request.content.userInfo;
            NSString *title = @"Novo Bipe";
            NSString *body = @"Você recebeu um alerta de Bipe";
            
            NSDictionary *aps = userInfo[@"aps"];
            if (aps && aps[@"alert"]) {
                if ([aps[@"alert"] isKindOfClass:[NSDictionary class]]) {
                    title = aps[@"alert"][@"title"] ? aps[@"alert"][@"title"] : title;
                    body = aps[@"alert"][@"body"] ? aps[@"alert"][@"body"] : body;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                BipeConfirmationViewController *bipeVC = [[BipeConfirmationViewController alloc] init];
                bipeVC.pushTitle = title;
                bipeVC.pushBody = body;
                if (userInfo[@"execucaoId"]) {
                    bipeVC.execucaoId = userInfo[@"execucaoId"];
                }
                bipeVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
                
                UIViewController *rootVC = self.window.rootViewController;
                if (rootVC) {
                    [rootVC presentViewController:bipeVC animated:YES completion:nil];
                }
            });
        }
    }
    
    completionHandler();
}



- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && userActivity.webpageURL) {
        NSURL *url = userActivity.webpageURL;
        if ([url.scheme isEqualToString:@"bipe"] || [url.host isEqualToString:@"confirm"] || [url.path containsString:@"confirm"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *execucaoId = nil;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"execucaoId"] || [item.name isEqualToString:@"execucao_id"]) {
                    execucaoId = item.value;
                    break;
                }
            }
            return YES;
        }
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    OwnTracksLogDefault("[OwnTracksAppDelegate] applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    OwnTracksLogDefault("[OwnTracksAppDelegate] applicationDidEnterBackground");
    
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    int opMode = [Settings intForKey:@"custom_opmode" inMOC:moc];
    if (opMode == 3) {
        // Modo Privado: Mantém desativado (Quiet)
        [LocationManager sharedInstance].monitoring = LocationMonitoringQuiet;
        [Settings setInt:LocationMonitoringQuiet forKey:@"monitoring_preference" inMOC:moc];
    } else {
        // Altera para modo Significant em segundo plano (economia de bateria)
        [LocationManager sharedInstance].monitoring = LocationMonitoringSignificant;
        [Settings setInt:LocationMonitoringSignificant forKey:@"monitoring_preference" inMOC:moc];
    }
    [CoreData.sharedInstance sync:moc];
    [self background];
    if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        [self.connection disconnect];
    }
    [self scheduleRefreshTask];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    OwnTracksLogDefault("[OwnTracksAppDelegate] applicationWillTerminate");
    [self background];
    [self.connection disconnect];
    
    NSString *notificationMessage = NSLocalizedString(@"Please keep Bipe.me running to ensure the desired functionality",
                                                      @"Please keep Bipe.me running to ensure the desired functionality");
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.body = notificationMessage;
    content.sound = [UNNotificationSound defaultSound];
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
                                                  triggerWithTimeInterval:1.0
                                                  repeats:NO];
    NSString *notificationIdentifier = [NSString stringWithFormat:@"terminate%f",
                                        [NSDate date].timeIntervalSince1970];
    
    UNNotificationRequest* request =
    [UNNotificationRequest requestWithIdentifier:notificationIdentifier
                                         content:content
                                         trigger:trigger];
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        //
    }];
}

- (BOOL)processURIConfig:(NSDictionary *)queryStrings {
    NSString *base64String = queryStrings[@"inline"];
    if (base64String) {
        NSData *jsonData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
        if (jsonData) {
            NSDictionary *dict = nil;
            id json = [[Validation sharedInstance] validateMessageData:jsonData];
            if (json &&
                [json isKindOfClass:[NSDictionary class]]) {
                dict = json;
            }
            if (dict) {
                [self performSelectorOnMainThread:@selector(configFromDictionary:)
                                       withObject:dict
                                    waitUntilDone:TRUE];
                
                self.processingMessage = NSLocalizedString(@"Configuration successfully processed",
                                                           @"Display after processing config");
                OwnTracksLogDefault("[OwnTracksAppDelegate] Configuration successfully processed");
                return TRUE;
            } else {
                self.processingMessage = NSLocalizedString(@"Configuration incorrect",
                                                           @"Display for incorrect config");
                OwnTracksLogError("[OwnTracksAppDelegate] Configuration incorrect");
                return FALSE;
            }
        } else {
            self.processingMessage = NSLocalizedString(@"Inline Configuration incorrect",
                                                       @"Display for incorrect inline config");
            OwnTracksLogError("[OwnTracksAppDelegate] Inline Configuration incorrect");
            return FALSE;
        }
    } else {
        self.processingMessage = NSLocalizedString(@"missing config components",
                                                   @"Display for missing components");
        OwnTracksLogError("[OwnTracksAppDelegate] missing config components %@", queryStrings);
        return FALSE;
    }
}

- (BOOL)processURIBeacon:(NSDictionary *)queryStrings {
    NSString *rid = queryStrings[@"rid"];
    NSString *name = queryStrings[@"name"];
    NSString *uuid = queryStrings[@"uuid"];
    int major = [queryStrings[@"major"] intValue];
    int minor = [queryStrings[@"minor"] intValue];
    
    if (name == nil || uuid == nil) {
        self.processingMessage = NSLocalizedString(@"Beacon QR incomplete",
                                                   @"Beacon QR code incomplete");
        OwnTracksLogError("[OwnTracksAppDelegate] Beacon QR incomplete");
        return FALSE;
    }
    
    if (!rid) {
        rid = Region.newRid;
    }
    
    [NavigationController alertWithTitle:NSLocalizedString(@"Process Configuration?",
                                                           @"Process Configuration?")
                                 message:[NSString stringWithFormat:@"Beacon name: %@\nuuid: %@\nmajor: %d minor %d",
                                          name, uuid, major, minor]
                               operation:^{
        NSString *desc = [NSString stringWithFormat:@"%@:%@%@%@",
                          name,
                          uuid,
                          major ? [NSString stringWithFormat:@":%d", major] : @"",
                          minor ? [NSString stringWithFormat:@":%d", minor] : @""
        ];
        
        [Settings waypointsFromDictionary:
         @{@"_type":@"waypoints",
           @"waypoints":@[@{@"_type":@"waypoint",
                            @"rid":rid,
                            @"desc":desc,
                            @"tst":@((int)round(([NSDate date].timeIntervalSince1970))),
                            @"lat":@([LocationManager sharedInstance].location.coordinate.latitude),
                            @"lon":@([LocationManager sharedInstance].location.coordinate.longitude),
                            @"rad":@(-1)
           }]
         } inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
        self.processingMessage = NSLocalizedString(@"Beacon QR successfully processed",
                                                   @"Display after processing beacon QR code");
        OwnTracksLogDefault("[OwnTracksAppDelegate] Beacon QR successfully processed");
    }];
    
    return TRUE;
}

- (void)configFromDictionary:(NSDictionary *)json {
    NSString *changes = [Settings changesFromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];

    if (changes.length == 0) {
        [NavigationController alertWithTitle:NSLocalizedString(@"Process Configuration",
                                                               @"Process Configuration")
                                     message:NSLocalizedString(@"No changes!", @"No changes!")];
    } else {
        [NavigationController alertWithTitle:NSLocalizedString(@"Process Configuration",
                                                               @"Process Configuration")
                                     message:[NSString stringWithFormat:@"%@%@",
                                              NSLocalizedString(@"Configuration changes:\n", @"Configuration changes;\n"),
                                              changes]
                                   operation:^{
            [self terminateSession];
            NSError *error = [Settings fromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
            [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
            self.configLoad = [NSDate date];
            [self reconnect];
            
            if (error) {
                [NavigationController alertWithTitle:@"processNSURL"
                                             message:
                     [NSString stringWithFormat:@"configFromDictionary %@ %@",
                      error,
                      json]
                ];
            } else {
                self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                          NSLocalizedString(@"File",
                                                            @"Display when file processing succeeds (filename follows)"),
                                          NSLocalizedString(@"successfully processed",
                                                            @"Display when file processing succeeds")];
                OwnTracksLogDefault("[OwnTracksAppDelegate] configFromDictionary ok");
                
            }
        }];
    }
}

- (void)waypointsFromDictionary:(NSDictionary *)json {
    NSString *changes = [Settings changesWaypointsFromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    if (changes.length == 0) {
        [NavigationController alertWithTitle:NSLocalizedString(@"Process Waypoints",
                                                               @"Process Waypoints")
                                     message:NSLocalizedString(@"No changes!", @"No changes!")];
    } else {
        [NavigationController alertWithTitle:NSLocalizedString(@"Process Waypoints",
                                                               @"Process Waypoints")
                                     message:[NSString stringWithFormat:@"%@%@",
                                              NSLocalizedString(@"Waypoint changes:\n", @"Waypoint changes;\n"),
                                              changes]
                                   operation:^{
            
            NSError *error = [Settings waypointsFromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
            [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
            if (error) {
                [NavigationController alertWithTitle:@"processNSURL"
                                             message:
                     [NSString stringWithFormat:@"waypointsFromDictionary %@ %@",
                      error,
                      json]
                ];
            } else {
                self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                          NSLocalizedString(@"File",
                                                            @"Display when file processing succeeds (filename follows)"),
                                          NSLocalizedString(@"successfully processed",
                                                            @"Display when file processing succeeds")];
                OwnTracksLogDefault("[OwnTracksAppDelegate] waypointsFromDictionary ok");
            }
        }];
    }
}

- (void)copyOTRPFile:(NSURL *)url {
    NSError *error;
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = url.lastPathComponent;
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:fileURL error:nil];
}

- (BOOL)processFile:(NSURL *)url {
    OwnTracksLogDefault("[OwnTracksAppDelegate] processFile %@", url);
    NSError *error;
    NSString *extension = url.pathExtension;
    if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
        NSData *data = [NSData dataWithContentsOfFile:[url path] options:0 error:&error];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        if (data) {
            NSDictionary *dict = nil;
            id json = [[Validation sharedInstance] validateMessageData:data];
            if (json &&
                [json isKindOfClass:[NSDictionary class]]) {
                dict = json;
            }
            if (dict) {
                [self configFromDictionary:dict];
            }
        }
    } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
        NSData *data = [NSData dataWithContentsOfFile:[url path] options:0 error:&error];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        if (data) {
            NSDictionary *dict = nil;
            id json = [[Validation sharedInstance] validateMessageData:data];
            if (json &&
                [json isKindOfClass:[NSDictionary class]]) {
                dict = json;
            }
            if (dict) {
                [self waypointsFromDictionary:dict];
            }
        }
    } else if ([extension isEqualToString:@"otrp"]) {
        [self copyOTRPFile:url];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                                  NSLocalizedString(@"File",
                                                    @"Display when file processing succeeds (filename follows)"),
                                  url.lastPathComponent,
                                  NSLocalizedString(@"successfully processed",
                                                    @"Display when file processing succeeds")];
        OwnTracksLogDefault("[OwnTracksAppDelegate] processFile ok %@", url.lastPathComponent);

    } else {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        error = [NSError errorWithDomain:@"OwnTracks"
                                    code:2
                                userInfo:@{@"extension":extension ? extension : @"(null)"}];
    }
    
    
    if (error) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@: %@ %@",
                                  NSLocalizedString(@"Error processing file",
                                                    @"Display when file processing fails"),
                                  url.lastPathComponent,
                                  error.localizedDescription,
                                  error.userInfo];
        OwnTracksLogError("[OwnTracksAppDelegate] processFile problem %@ %{public}@", url.lastPathComponent, error);
        return FALSE;
    }
    return TRUE;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    OwnTracksLogDefault("[OwnTracksAppDelegate] applicationDidBecomeActive");
    
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    int opMode = [Settings intForKey:@"custom_opmode" inMOC:moc];
    if (opMode == 3) {
        // Modo Privado: Mantém desativado (Quiet)
        [LocationManager sharedInstance].monitoring = LocationMonitoringQuiet;
        [Settings setInt:LocationMonitoringQuiet forKey:@"monitoring_preference" inMOC:moc];
    } else {
        // Altera para modo Move em primeiro plano (alta precisão / tempo real)
        [LocationManager sharedInstance].monitoring = LocationMonitoringMove;
        [Settings setInt:LocationMonitoringMove forKey:@"monitoring_preference" inMOC:moc];
    }
    [CoreData.sharedInstance sync:moc];
    
    [self.connection connectToLast];
    
    if (self.disconnectTimer && self.disconnectTimer.isValid) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] disconnectTimer invalidate %@",
                     self.disconnectTimer.fireDate);
        [self.disconnectTimer invalidate];
    }
    
    if (self.backgroundFetchCheckMessage) {
        [NavigationController alertWithTitle:@"Background Fetch"
                            message:self.backgroundFetchCheckMessage];
        self.backgroundFetchCheckMessage = nil;
    }
    
    if (self.processingMessage) {
        [NavigationController alertWithTitle:@"openURL"
                            message:self.processingMessage];
        self.processingMessage = nil;
        [self reconnect];
    }
    
    if (![Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");
        
        [NavigationController alertWithTitle:@"Settings" message:message];
    }
}

- (void)doRefresh {
    OwnTracksLogDefault("[OwnTracksAppDelegate] doRefresh");
    self.inRefresh = TRUE;
    [self background];
    
    [[LocationManager sharedInstance] wakeup];
    [self.connection connectToLast];
}

- (void)background {
#ifdef VERBOSE
    NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    OwnTracksLogDefault("[OwnTracksAppDelegate] background backgroundTimeRemaining: %@",
                 backgroundTimeRemaining > 24 * 3600 ? @"âˆž": @(floor(backgroundTimeRemaining)).stringValue);
#endif
    
    [self startBackgroundTimer];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        self.backgroundTask == UIBackgroundTaskInvalid) {
        self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            OwnTracksLogDebug("[OwnTracksAppDelegate] BackgroundTaskExpirationHandler");
            if (self.backgroundTask) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
                self.backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
        OwnTracksLogDebug("[OwnTracksAppDelegate] beginBackgroundTaskWithExpirationHandler %lu",
                     (unsigned long)self.backgroundTask);
    }
}

- (void)startBackgroundTimer {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        [LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            OwnTracksLogDebug("[OwnTracksAppDelegate] disconnectTimer.isValid %@",
                         self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil
                                                          repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer forMode:NSDefaultRunLoopMode];
            OwnTracksLogDebug("[OwnTracksAppDelegate] disconnectTimer %@",
                         self.disconnectTimer.fireDate);
            
            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            self.holdTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_HOLD_FOR
                                                             repeats:FALSE
                                                               block:^(NSTimer * _Nonnull timer) {
                OwnTracksLogDebug("[OwnTracksAppDelegate] holdTimer");
                if (self.bgTimer) {
                    if (self.bgTimer.isValid) {
                        [self.bgTimer invalidate];
                    }
                    self.bgTimer = nil;
                }
                self.bgTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               repeats:TRUE
                                                                 block:^(NSTimer * _Nonnull timer) {
                    OwnTracksLogDebug("[OwnTracksAppDelegate] bgTimer %@ %@",
                                 self.connectionState,
                                 self.connectionBuffered);
                    if (!self.connectionBuffered || !self.connectionBuffered.intValue) {
                        if (self.connectionState.intValue == state_connected) {
                            [self disconnectInBackground];
                        }
                    }
                }];
            }];
        }
    }
}

- (void)disconnectInBackground {
    OwnTracksLogDefault("[OwnTracksAppDelegate] disconnectInBackground");
    [self.connection disconnect];
}

- (void)application:(UIApplication *)application
performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    OwnTracksLogDefault("[OwnTracksAppDelegate] performActionForShortcutItem %{public}@", shortcutItem.type);
    if ([shortcutItem.type isEqualToString:@"br.guardiam.com.movemode"]) {
        LocationMonitoring monitoring = LocationMonitoringMove;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"br.guardiam.com.significantmode"]) {
        LocationMonitoring monitoring = LocationMonitoringSignificant;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"br.guardiam.com.manualmode"]) {
        LocationMonitoring monitoring = LocationMonitoringManual;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"br.guardiam.com.quietmode"]) {
        LocationMonitoring monitoring = LocationMonitoringQuiet;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
        
    } else {
        completionHandler(FALSE);
    }
}

/*
 *
 * LocationManagerDelegate
 *
 */

- (void)newLocation:(CLLocation *)location {
    [self background];
    if (self.inRefresh) {
        self.inRefresh = FALSE;
        [self publishLocation:location trigger:@"p" withPOI:nil withImage:nil withImageName:nil];
    } else {
        [self publishLocation:location trigger:nil withPOI:nil withImage:nil withImageName:nil];
    }
}

- (void)timerLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"t" withPOI:nil withImage:nil withImageName:nil];
}

- (void)visitLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"v" withPOI:nil withImage:nil withImageName:nil];
}

- (BOOL)isRegionInsecure:(NSString *)identifier {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *myselfForLookup = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:moc] inManagedObjectContext:moc];
    if (myselfForLookup) {
        for (Region *anyRegion in myselfForLookup.hasRegions) {
            if ([identifier isEqualToString:anyRegion.CLregion.identifier]) {
                if (anyRegion.uuid && anyRegion.uuid.length > 0) {
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"insecure_wp_%@", anyRegion.uuid]]) {
                        return YES;
                    }
                }
                if (anyRegion.andFillRid && anyRegion.andFillRid.length > 0) {
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"insecure_wp_%@", anyRegion.andFillRid]]) {
                        return YES;
                    }
                }
                break;
            }
        }
    }
    return NO;
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    [self background];
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    if (!self.lastRegionStates) {
        self.lastRegionStates = [[NSMutableDictionary alloc] init];
    }
    
    NSNumber *lastState = self.lastRegionStates[region.identifier];
    if (lastState && lastState.boolValue == enter) {
        OwnTracksLogDefault("[OwnTracksAppDelegate] Ignorando evento duplicado para a mesma regiao (%@, enter=%d)", region.identifier, enter);
        return;
    }
    self.lastRegionStates[region.identifier] = @(enter);
    
    BOOL insecure = [self isRegionInsecure:region.identifier];
    
    NSArray <NSString *> *initialComponents = [region.identifier componentsSeparatedByString:@"|"];
    
    BOOL mute = [Settings boolForKey:@"mute" inMOC:moc];
    BOOL soundWaypoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"soundWaypoint"] == nil ? YES : [Settings boolForKey:@"soundWaypoint" inMOC:moc];
    
    if (!mute && soundWaypoint) {
        [BipeAudioHelper playSoundNamed:@"bipe_routine_ok.mp3"];
    }
    
    if ([LocationManager sharedInstance].monitoring != LocationMonitoringQuiet &&
        [Settings validIdsInMOC:moc]) {
        
        if (!region.isFollow) {
            NSArray <NSString *> *components = [region.identifier componentsSeparatedByString:@"|"];
            NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@",
                                             (enter ?
                                              NSLocalizedString(@"Entering",
                                                                @"Display when entering region (region name follows)"):
                                              NSLocalizedString(@"Leaving",
                                                                @"Display when leaving region (region name follows)")
                                              ),
                                             components[0]];
            
            // O próprio aparelho não exibe mais notificação local de geofence.
            // Apenas registra no histórico e manda para o servidor (linha 929+).
            [History historyInGroup:NSLocalizedString(@"Region",
                                                      @"Header of an alert message regarding circular region")
                           withText:notificationMessage
                                 at:nil
                              inMOC:moc
                            maximum:[Settings theMaximumHistoryInMOC:moc]];
            
            Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:moc]
                                    inManagedObjectContext:moc];
            
            CLLocation *location = [LocationManager sharedInstance].location;
            
            NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
            json[@"_type"] = @"transition";
            
            NSString *userName = [Settings stringForKey:@"user_preference" inMOC:moc];
            if (userName && userName.length > 0) {
                json[@"userName"] = userName;
            }
            
            NSString *clienteId = [Settings stringForKey:@"clientid_preference" inMOC:moc];
            if (clienteId && clienteId.length > 0) {
                json[@"clienteId"] = clienteId;
            }
            
            NSString *nickname = [Settings stringForKey:@"device_name_preference" inMOC:moc];
            if (!nickname || nickname.length == 0) {
                nickname = [Settings stringForKey:@"nickname_preference" inMOC:moc];
            }
            if (nickname && nickname.length > 0) {
                json[@"nickname"] = nickname;
            }
            
            NSNumber *opModeNum = @([Settings intForKey:@"custom_opmode" inMOC:moc]);
            json[@"opMode"] = [opModeNum stringValue];
            
            NSString *icon = [Settings stringForKey:@"icon" inMOC:moc];
            if (icon && icon.length > 0) {
                json[@"icon"] = icon;
            }
            
            NSString *color = [Settings stringForKey:@"color" inMOC:moc];
            if (color && color.length > 0) {
                json[@"color"] = color;
            }
            
            NSString *langId = [[NSLocale preferredLanguages] firstObject];
            if (langId && langId.length > 0) {
                if ([langId hasPrefix:@"pt"]) {
                    json[@"lang"] = @"pt-br";
                } else if ([langId hasPrefix:@"es"]) {
                    json[@"lang"] = @"es";
                } else {
                    json[@"lang"] = @"en";
                }
            }
            
            json[@"lat"] = [NSNumber doubleValueWithSixDecimals:location.coordinate.latitude];
            
            json[@"lon"] = [NSNumber doubleValueWithSixDecimals:location.coordinate.longitude];
            
            json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:location.timestamp.timeIntervalSince1970];
            
            if (location.horizontalAccuracy >= 0.0) {
                json[@"acc"] = [NSNumber doubleValueWithZeroDecimals:location.horizontalAccuracy];
            }
            json[@"tid"] = myself.effectiveTid;
            json[@"event"] = enter ? @"enter" : @"leave";
            json[@"t"] =  [region isKindOfClass:[CLBeaconRegion class]] ? @"b" : @"c";
            
            if (fabs(location.timestamp.timeIntervalSince1970 -
                     [NSDate date].timeIntervalSince1970) > 1.0) {
                json[@"created_at"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
            }
            
            for (Region *anyRegion in myself.hasRegions) {
                if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
                    anyRegion.name = anyRegion.name;
                    json[@"desc"] = components[0];
                    json[@"wtst"] = [NSNumber doubleValueWithZeroDecimals:anyRegion.tst.timeIntervalSince1970];
                    json[@"rid"] = anyRegion.andFillRid;
                    NSString *wpId = (anyRegion.uuid && anyRegion.uuid.length > 0) ? anyRegion.uuid : anyRegion.andFillRid;
                    if (wpId && wpId.length > 0) {
                        json[@"waypointId"] = wpId;
                        BOOL insecureWp = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"insecure_wp_%@", wpId]];
                        json[@"insecure"] = @(insecureWp);
                    }
                    
                    [self.connection sendData:[self jsonToData:json]
                                        topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/event/send"]
                                   topicAlias:@(2)
                                          qos:[Settings theQosInMOC:moc]
                                       retain:NO];
                    if ([region isKindOfClass:[CLBeaconRegion class]]) {
                        if ((anyRegion.radius).doubleValue < 0) {
                            anyRegion.lat = @(location.coordinate.latitude);
                            anyRegion.lon = @(location.coordinate.longitude);
                            [self sendRegion:anyRegion];
                        }
                    }
                    
                    // NOTE: previously this inner scope re-declared a local
                    // named `components`, shadowing the outer `components`
                    // array declared above (same name, different array).
                    // Renamed to `identifierComponents` to remove the
                    // shadowing/confusion; behavior is unchanged.
                    NSArray <NSString *> *identifierComponents = [region.identifier componentsSeparatedByString:@"|"];
                    if (identifierComponents.count == 3) {
                        LocationMonitoring newMonitoring;
                        if (enter) {
                            newMonitoring = identifierComponents[1].integerValue;
                        } else {
                            newMonitoring = identifierComponents[2].integerValue;
                        }
                        LocationManager.sharedInstance.monitoring = newMonitoring;
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
                        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                                  forKey:@"monitoring_preference" inMOC:moc];
                        [CoreData.sharedInstance sync:moc];
                        [self background];
                    }
                }
            }
            
            if ([region isKindOfClass:[CLBeaconRegion class]]) {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"b" withPOI:nil withImage:nil withImageName:nil];
            } else {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"c" withPOI:nil withImage:nil withImageName:nil];
            }
        } else {
            if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"C" withPOI:nil withImage:nil withImageName:nil];
            }
        }
    }
}

- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    OwnTracksLogDebug("[OwnTracksAppDelegate] regionState %@ i:%d", region.identifier, inside);
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                            inManagedObjectContext:CoreData.sharedInstance.mainMOC];
    
    for (Region *anyRegion in myself.hasRegions) {
        if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
            anyRegion.name = anyRegion.name;
        }
    }
}

-(void)beaconInRange:(CLBeacon *)beacon
    beaconConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    [self background];
    if ([Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                                inManagedObjectContext:CoreData.sharedInstance.mainMOC];
        
        Region *myRegion;
        for (Region *anyRegion in myself.hasRegions) {
            if ([beaconConstraint.UUID.UUIDString isEqualToString:anyRegion.uuid]) {
                if ((!anyRegion.major &&
                     !beaconConstraint.major
                     ) ||
                    (anyRegion.major &&
                     beaconConstraint.major &&
                     anyRegion.major.intValue == beaconConstraint.major.intValue &&
                     ((!anyRegion.minor &&
                       !beaconConstraint.minor
                       ) ||
                      (anyRegion.minor &&
                       beaconConstraint.minor &&
                       anyRegion.minor.intValue == beaconConstraint.minor.intValue
                       )
                      )
                     )
                    ) {
                    myRegion = anyRegion;
                    break;
                }
            }
        }
        
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        json[@"_type"] = @"beacon";
        json[@"tid"] = myself.effectiveTid;
        json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[LocationManager sharedInstance].location.timestamp.timeIntervalSince1970];
        
        json[@"uuid"] = (beacon.UUID).UUIDString;
        json[@"major"] = beacon.major;
        json[@"minor"] = beacon.minor;
        json[@"prox"] = @(beacon.proximity);
        json[@"acc"] = [NSNumber doubleValueWithZeroDecimals:beacon.accuracy];
        json[@"rssi"] = @(beacon.rssi);
        if (myRegion) {
            json[@"desc"] = myRegion.name;
        }
        [self.connection sendData:[self jsonToData:json]
                            topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/beacon"]
                       topicAlias:@(3)
                              qos:[Settings theQosInMOC:CoreData.sharedInstance.mainMOC]
                           retain:NO];
    }
}

#pragma ConnectionDelegate

- (void)showState:(Connection *)connection
            state:(NSInteger)state {
    OwnTracksLogDebug("[OwnTracksAppDelegate] showState: %ld", (long)state);
    
    self.connectionState = @(state);
    [self performSelectorOnMainThread:@selector(checkState:) withObject:@(state) waitUntilDone:NO];
}

- (void)checkState:(NSNumber *)state {
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/
#ifdef VERBOSE
    NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    OwnTracksLogDebug("[OwnTracksAppDelegate] checkState: %@, backgroundTimeRemaining: %@",
                 state,
                 backgroundTimeRemaining > 24 * 3600 ? @"âˆž": @(floor(backgroundTimeRemaining)).stringValue);
#endif
    
    if (state.intValue == state_starting) {
        if (self.backgroundTask) {
            if (self.bgTimer) {
                if (self.bgTimer.isValid) {
                    [self.bgTimer invalidate];
                }
                self.bgTimer = nil;
            }
            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            if (self.disconnectTimer) {
                if (self.disconnectTimer.isValid) {
                    [self.disconnectTimer invalidate];
                }
                self.disconnectTimer = nil;
            }
            
            OwnTracksLogDefault("[OwnTracksAppDelegate] endBackGroundTask %lu",
                         (unsigned long)self.backgroundTask);
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.bgTask) {
            OwnTracksLogDefault("[OwnTracksAppDelegate] setTaskCompletedWithSuccess");
            [self.bgTask setTaskCompletedWithSuccess:TRUE];
            self.bgTask = nil;
        }
    }
}

- (BOOL)handleMessage:(Connection *)connection
                 data:(NSData *)data
              onTopic:(NSString *)topic
             retained:(BOOL)retained {
    @synchronized (self.inQueue) {
        self.inQueue = @((self.inQueue).unsignedLongValue + 1);
    }

#ifdef VERBOSE
#define LEN2PRINT 256
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    OwnTracksLogDebug("[OwnTracksAppDelegate] handleMessage queueing inQueue=%@ topic=%@ data(%lu)=%@",
                 self.inQueue,
                 topic,
                 (unsigned long)dataString.length,
                 dataString.length <= LEN2PRINT ?
                 dataString :
                 [NSString stringWithFormat:@"%@...", [dataString substringToIndex:LEN2PRINT]]);
#endif
    
    [CoreData.sharedInstance.queuedMOC performBlock:^{
        (void)[[OwnTracking sharedInstance] processMessage:topic
                                                      data:data
                                                  retained:retained
                                                   context:CoreData.sharedInstance.queuedMOC];
        NSArray *baseComponents = [[Settings theGeneralTopicInMOC:CoreData.sharedInstance.queuedMOC] componentsSeparatedByString:@"/"];
        NSArray *topicComponents = [topic componentsSeparatedByString:@"/"];
        
        NSString *device = @"";
        BOOL ownDevice = true;
        
        for (int i = 0; i < baseComponents.count; i++) {
            if (i > 0) {
                device = [device stringByAppendingString:@"/"];
            }
            if (i < topicComponents.count) {
                device = [device stringByAppendingString:topicComponents[i]];
                if (![baseComponents[i] isEqualToString:topicComponents [i]]) {
                    ownDevice = false;
                }
            } else {
                ownDevice = false;
            }
        }
        
        OwnTracksLogDebug("[OwnTracksAppDelegate] device %@ owndevice %d", device, ownDevice);
        
        BOOL isCmdTopic = [topic hasSuffix:@"/cmd"];
        BOOL isCallTopic = [topic hasSuffix:@"/call"];
        BOOL isEventReceiveTopic = [topic hasSuffix:@"/event/receive"] || [topic containsString:@"/event/"];
        if (ownDevice || isCmdTopic || isCallTopic || isEventReceiveTopic) {
            
            id json = [[Validation sharedInstance] validateMessageData:data];
            
            if (json && [json isKindOfClass:[NSArray class]]) {
                // Array direto de waypoints [ {...}, {...} ]
                NSDictionary *wrapped = @{@"_type": @"cmd", @"action": @"setWaypoints", @"waypoints": json};
                [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                       withObject:wrapped
                                    waitUntilDone:NO];
            } else if (json && [json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = (NSDictionary *)json;
                NSString *type = dictionary[@"_type"];
                
                if ([type isEqualToString:@"transition"] || [type isEqualToString:@"event"] || isEventReceiveTopic) {
                    [self performSelectorOnMainThread:@selector(performReceiveEvent:)
                                           withObject:dictionary
                                        waitUntilDone:NO];
                } else if ([type isEqualToString:@"waypoints"] || [type isEqualToString:@"waypoint"]) {
                    [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                           withObject:dictionary
                                        waitUntilDone:NO];
                } else if (!type || [type isEqualToString:@"cmd"]) {
                    NSString *action = dictionary[@"action"];
                    if ([action isEqualToString:@"setWaypoints"]) {
                        [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                               withObject:dictionary
                                            waitUntilDone:NO];
                    } else if ([action isEqualToString:@"dump"]) {
                        [self dump];
                    } else if ([action isEqualToString:@"status"]) {
                        [self status];
                    } else if ([action isEqualToString:@"reportLocation"]) {
                        [self performSelectorOnMainThread:@selector(reportLocation) withObject:nil waitUntilDone:NO];
                    } else if ([action isEqualToString:@"waypoints"]) {
                        [self performSelectorOnMainThread:@selector(waypoints) withObject:nil waitUntilDone:NO];
                    } else if ([action isEqualToString:@"clearWaypoints"]) {
                        [self performSelectorOnMainThread:@selector(performClearWaypoints:) withObject:dictionary waitUntilDone:NO];
                    } else if ([action isEqualToString:@"setConfiguration"]) {
                        [self performSelectorOnMainThread:@selector(performSetConfiguration:) withObject:dictionary waitUntilDone:NO];
                    } else if ([action isEqualToString:@"response"]) {
                        [self performSelectorOnMainThread:@selector(performResponse:) withObject:dictionary waitUntilDone:NO];
                    } else {
                        // Se não tem action mas tem waypoints no dicionário
                        if (dictionary[@"waypoints"]) {
                            [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                                   withObject:dictionary
                                                waitUntilDone:NO];
                        } else {
                            OwnTracksLogError("[OwnTracksAppDelegate] unknown action in JSON");
                        }
                    }
                } else {
                    OwnTracksLogError("[OwnTracksAppDelegate] unhandled _type (%{public}@) in JSON", type);
                }
            } else {
                OwnTracksLogError("[OwnTracksAppDelegate] JSON is not valid object or array");
            }
        }
        @synchronized (self.inQueue) {
            self.inQueue = @((self.inQueue).unsignedLongValue - 1);
            if (self.inQueue.intValue == 0) {
                [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
            }
        }
        OwnTracksLogDebug("[OwnTracksAppDelegate] handleMessage done inQueue=%@",
                     self.inQueue);
    }];
    
    return true;
}

- (void)messageDelivered:(Connection *)connection msgID:(UInt16)msgID {
    // noop
}

- (void)totalBuffered:(Connection *)connection count:(NSUInteger)count {
    self.connectionBuffered = @(count);
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    [[UNUserNotificationCenter currentNotificationCenter]
     setBadgeCount:self.connectionBuffered.intValue
     withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            OwnTracksLogError("[OwnTracksAppDelegate setBadgeCount] error %@", error);
        }
    }];
}

- (void)dump {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"_type"] = @"dump";
    json[@"configuration"] = [Settings toDictionaryInMOC:CoreData.sharedInstance.mainMOC];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/dump"]
                   topicAlias:@(4)
                          qos:[Settings theQosInMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)status {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"_type"] = @"status";

    NSMutableDictionary *iOS = [NSMutableDictionary dictionary];
    
    iOS[@"version"] = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    iOS[@"locale"] = [NSLocale currentLocale].localeIdentifier;
    iOS[@"localeUsesMetricSystem"] = [NSNumber numberWithBool:[NSLocale currentLocale].usesMetricSystem];

    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusAvailable";
            break;
        case UIBackgroundRefreshStatusDenied:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusDenied";
            break;
        case UIBackgroundRefreshStatusRestricted:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusRestricted";
            break;
    }
    
    switch([LocationManager sharedInstance].locationManagerAuthorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusNotDetermined";
            break;
        case kCLAuthorizationStatusRestricted:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusRestricted";
            break;
        case kCLAuthorizationStatusDenied:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusDenied";
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusAuthorizedAlways";
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusAuthorizedWhenInUse";
            break;
    }
    
    switch([LocationManager sharedInstance].altimeterAuthorizationStatus) {
        case CMAuthorizationStatusDenied:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusDenied";
            break;
        case CMAuthorizationStatusAuthorized:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusAuthorized";
            break;
        case CMAuthorizationStatusRestricted:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusRestricted";
            break;
        case CMAuthorizationStatusNotDetermined:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusNotDetermined";
            break;
    }
    iOS[@"altimeterIsRelativeAltitudeAvailable"] = [NSNumber numberWithBool:[LocationManager sharedInstance].altimeterIsRelativeAltitudeAvailable];
    
    switch([LocationManager sharedInstance].motionActivityManagerAuthorizationStatus) {
        case CMAuthorizationStatusDenied:
            iOS[@"motionActivityManagerAuthorizationStatus"] = @"CMAuthorizationStatusDenied";
            break;
        case CMAuthorizationStatusAuthorized:
            iOS[@"motionActivityManagerAuthorizationStatus"] = @"CMAuthorizationStatusAuthorized";
            break;
        case CMAuthorizationStatusRestricted:
            iOS[@"motionActivityManagerAuthorizationStatus"] = @"CMAuthorizationStatusRestricted";
            break;
        case CMAuthorizationStatusNotDetermined:
            iOS[@"motionActivityManagerAuthorizationStatus"] = @"CMAuthorizationStatusNotDetermined";
            break;
    }
    iOS[@"motionActivityManagerIsActivityAvailable"] = [NSNumber numberWithBool:[LocationManager sharedInstance].motionActivityManagerIsActivityAvailable];

    iOS[@"pedometerIsStepCountingAvailable"] = [NSNumber numberWithBool:[CMPedometer isStepCountingAvailable]];
    iOS[@"pedometerIsFloorCountingAvailable"] = [NSNumber numberWithBool:[CMPedometer isFloorCountingAvailable]];
    iOS[@"pedometerIsDistanceAvailable"] = [NSNumber numberWithBool:[CMPedometer isDistanceAvailable]];

    UIDevice *device = [UIDevice currentDevice];
    //iOS[@"deviceName"] = device.name;
    iOS[@"deviceSystemName"] = device.systemName;
    iOS[@"deviceSystemVersion"] = device.systemVersion;
    iOS[@"deviceModel"] = device.model;
    //iOS[@"deviceLocalizedModel"] = device.localizedModel;
    iOS[@"deviceIdentifierForVendor"] = device.identifierForVendor.UUIDString;
    switch (device.userInterfaceIdiom) {
        case UIUserInterfaceIdiomUnspecified:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomUnspecified";
            break;
        case UIUserInterfaceIdiomPhone:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomPhone";
            break;
        case UIUserInterfaceIdiomPad:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomPad";
            break;
        case UIUserInterfaceIdiomTV:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomTV";
            break;
        case UIUserInterfaceIdiomCarPlay:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomCarPlay";
            break;
        case UIUserInterfaceIdiomMac:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomMac";
            break;
        case UIUserInterfaceIdiomVision:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomVision";
            break;
    }
    
    iOS[@"noMap"] = [NSNumber numberWithInteger:
                     [[NSUserDefaults standardUserDefaults] integerForKey:@"noMap"]];
    iOS[@"noRevgeo"] = [NSNumber numberWithInteger:
                        [[NSUserDefaults standardUserDefaults] integerForKey:@"noRevgeo"]];
    
    json[@"iOS"] = iOS;
    
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/status"]
                   topicAlias:@(8)
                          qos:[Settings theQosInMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)performResponse:(NSDictionary *)dictionary {
    if ([[Tours sharedInstance] processResponse:dictionary]) {
    } else {
    }
}

- (void)performSetConfiguration:(NSDictionary *)dictionary {
    NSDictionary *configuration = dictionary[@"configuration"];
    if (configuration && [configuration isKindOfClass:[NSDictionary class]]) {
        NSError *error = [Settings fromDictionary:configuration
                                            inMOC:CoreData.sharedInstance.mainMOC];

        if (error) {
            OwnTracksLogError("[OwnTracksAppDelegate performSetConfiguration] error %@", error);
        }
    } else {
        OwnTracksLogError("[OwnTracksAppDelegate performSetConfiguration] no valid configuration");
    }
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    self.configLoad = [NSDate date];
    [self reconnect];
}

- (void)performSetWaypoints:(NSDictionary *)dictionary {
    // Limpa todos os waypoints anteriores para evitar acúmulo de sujeira
    [Settings clearWaypoints:CoreData.sharedInstance.mainMOC];

    id waypoints = dictionary[@"waypoints"];
    if ([waypoints isKindOfClass:[NSDictionary class]] && waypoints[@"waypoints"] && [waypoints[@"waypoints"] isKindOfClass:[NSArray class]]) {
        waypoints = waypoints[@"waypoints"];
    }
    
    if ([waypoints isKindOfClass:[NSArray class]]) {
        [Settings setWaypoints:(NSArray *)waypoints
                          inMOC:CoreData.sharedInstance.mainMOC];
    } else if ([waypoints isKindOfClass:[NSDictionary class]]) {
        [Settings waypointsFromDictionary:(NSDictionary *)waypoints
                                    inMOC:CoreData.sharedInstance.mainMOC];
    } else if ([dictionary[@"_type"] isEqualToString:@"waypoints"]) {
        [Settings waypointsFromDictionary:dictionary
                                    inMOC:CoreData.sharedInstance.mainMOC];
    } else {
        OwnTracksLogError("[OwnTracksAppDelegate performSetWaypoints] no valid waypoints");
    }
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    [[LocationManager sharedInstance] resetRegions];
}

- (void)performClearWaypoints:(NSDictionary *)dictionary {
    [Settings clearWaypoints:CoreData.sharedInstance.mainMOC];
}

static NSString * _Nullable safeEventString(id _Nullable obj) {
    if (obj && [obj isKindOfClass:[NSString class]]) {
        NSString *str = (NSString *)obj;
        if (str.length > 0) {
            return str;
        }
    }
    return nil;
}

- (void)renderSVGData:(NSData *)svgData completion:(void (^)(NSData * _Nullable pngData))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 200, 200) configuration:config];
            webView.opaque = NO;
            webView.backgroundColor = [UIColor clearColor];
            
            NSString *svgString = [[NSString alloc] initWithData:svgData encoding:NSUTF8StringEncoding];
            if (!svgString || svgString.length == 0) {
                completion(nil);
                return;
            }
            
            NSString *html = [NSString stringWithFormat:
                @"<!DOCTYPE html><html><head><style>html,body{margin:0;padding:0;background:transparent;width:100%%;height:100%%;display:flex;align-items:center;justify-content:center;} svg{width:100%%;height:100%%;}</style></head><body>%@</body></html>", svgString];
            
            [webView loadHTMLString:html baseURL:nil];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                WKSnapshotConfiguration *snapConfig = [[WKSnapshotConfiguration alloc] init];
                snapConfig.rect = CGRectMake(0, 0, 200, 200);
                
                [webView takeSnapshotWithConfiguration:snapConfig completionHandler:^(UIImage * _Nullable snapshotImage, NSError * _Nullable error) {
                    if (snapshotImage) {
                        NSData *pngData = UIImagePNGRepresentation(snapshotImage);
                        completion(pngData);
                    } else {
                        completion(nil);
                    }
                }];
            });
        } @catch (NSException *ex) {
            completion(nil);
        }
    });
}

- (void)performReceiveEvent:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        OwnTracksLogError("[OwnTracksAppDelegate] performReceiveEvent dictionary is invalid");
        return;
    }
    OwnTracksLogDefault("[OwnTracksAppDelegate] performReceiveEvent %@", dictionary);
    
    NSString *nickname = safeEventString(dictionary[@"nickname"]);
    if (!nickname) nickname = safeEventString(dictionary[@"name"]);
    if (!nickname) nickname = safeEventString(dictionary[@"userName"]);
    
    NSString *notificationTitle = nickname ? nickname : NSLocalizedString(@"Região", @"Header of an alert message regarding circular region");
    
    NSString *event = safeEventString(dictionary[@"event"]);
    NSString *desc = safeEventString(dictionary[@"desc"]);
    if (!desc) desc = safeEventString(dictionary[@"description"]);
    
    NSString *text = safeEventString(dictionary[@"text"]);
    if (!text) text = safeEventString(dictionary[@"msg"]);
    if (!text) text = safeEventString(dictionary[@"title"]);
    
    NSString *messageText = text;
    if (!messageText) {
        if (desc) {
            if ([event isEqualToString:@"enter"]) {
                messageText = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Entering", @""), desc];
            } else if ([event isEqualToString:@"leave"]) {
                messageText = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Leaving", @""), desc];
            } else {
                messageText = desc;
            }
        } else if (event) {
            messageText = event;
        } else {
            messageText = NSLocalizedString(@"Evento recebido", @"Evento recebido");
        }
    }
    
    // Salva no Histórico do App
    @try {
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [History historyInGroup:notificationTitle
                       withText:messageText
                             at:nil
                          inMOC:moc
                        maximum:[Settings theMaximumHistoryInMOC:moc]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    } @catch (NSException *exception) {
        OwnTracksLogError("[OwnTracksAppDelegate] History exception: %@", exception);
    }
    
    // Checa por URL de imagem/ícone no payload
    NSString *iconUrlString = safeEventString(dictionary[@"icon"]);
    if (!iconUrlString) iconUrlString = safeEventString(dictionary[@"iconUrl"]);
    if (!iconUrlString) iconUrlString = safeEventString(dictionary[@"image"]);
    if (!iconUrlString) iconUrlString = safeEventString(dictionary[@"imageUrl"]);
    if (!iconUrlString) iconUrlString = safeEventString(dictionary[@"avatar"]);
    NSString *soundName = safeEventString(dictionary[@"sound"]);
    if (!soundName) soundName = safeEventString(dictionary[@"soundName"]);
    if (!soundName && [dictionary[@"data"] isKindOfClass:[NSDictionary class]]) {
        soundName = safeEventString(dictionary[@"data"][@"sound"]);
    }
    NSString *resolvedSoundName = [BipeAudioHelper resolveSoundNameFrom:soundName];

    void (^scheduleNotification)(UNNotificationAttachment *) = ^(UNNotificationAttachment *attachment) {
        @try {
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = notificationTitle;
            content.body = messageText;
            
            if (resolvedSoundName && resolvedSoundName.length > 0) {
                content.sound = [UNNotificationSound soundNamed:resolvedSoundName];
                [BipeAudioHelper playSoundNamed:soundName];
            } else {
                content.sound = [UNNotificationSound defaultSound];
            }
            
            if (attachment) {
                content.attachments = @[attachment];
            }
            
            content.categoryIdentifier = @"BIPE_CATEGORY";
            
            UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO];
            NSString *identifier = [NSString stringWithFormat:@"event_rx_%f", [NSDate date].timeIntervalSince1970];
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
            
            BOOL isFromPush = (dictionary[@"aps"] != nil);
            if (!isFromPush) {
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        OwnTracksLogError("[OwnTracksAppDelegate] performReceiveEvent notification error %@", error);
                    }
                }];
            }
        } @catch (NSException *ex) {
            OwnTracksLogError("[OwnTracksAppDelegate] Notification exception: %@", ex);
        }
    };

    if (iconUrlString && ([iconUrlString hasPrefix:@"http://"] || [iconUrlString hasPrefix:@"https://"])) {
        NSURL *iconURL = [NSURL URLWithString:iconUrlString];
        if (iconURL) {
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:iconURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (data && data.length > 0 && !error) {
                    NSString *ext = iconURL.pathExtension.lowercaseString;
                    BOOL isSVG = [ext isEqualToString:@"svg"];
                    if (!isSVG && data.length > 5) {
                        NSString *header = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, 120))] encoding:NSUTF8StringEncoding];
                        if ([header containsString:@"<svg"] || [header containsString:@"<?xml"]) {
                            isSVG = YES;
                        }
                    }
                    
                    void (^writeAndAttach)(NSData *, NSString *) = ^(NSData *imgData, NSString *imgExt) {
                        UNNotificationAttachment *attachment = nil;
                        @try {
                            NSString *tempFilename = [NSString stringWithFormat:@"notif_icon_%f.%@", [NSDate date].timeIntervalSince1970, imgExt];
                            NSURL *tempFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename]];
                            if ([imgData writeToURL:tempFileURL atomically:YES]) {
                                NSError *attErr = nil;
                                attachment = [UNNotificationAttachment attachmentWithIdentifier:@"icon" URL:tempFileURL options:nil error:&attErr];
                            }
                        } @catch (NSException *e) {
                            OwnTracksLogError("[OwnTracksAppDelegate] Attachment exception: %@", e);
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            scheduleNotification(attachment);
                        });
                    };

                    if (isSVG) {
                        [self renderSVGData:data completion:^(NSData * _Nullable pngData) {
                            if (pngData && pngData.length > 0) {
                                writeAndAttach(pngData, @"png");
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    scheduleNotification(nil);
                                });
                            }
                        }];
                        return;
                    } else {
                        writeAndAttach(data, ext.length > 0 ? ext : @"png");
                        return;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    scheduleNotification(nil);
                });
            }];
            [task resume];
            return;
        }
    }
    
    scheduleNotification(nil);
}

- (void)waypoints {
    NSDictionary *json = [Settings waypointsToDictionaryInMOC:CoreData.sharedInstance.mainMOC];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/waypoints"]
                   topicAlias:@(5)
                          qos:[Settings theQosInMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)sendCard {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    Friend *myself = [Friend existsFriendWithTopic:topic inManagedObjectContext:moc];
    
    NSMutableDictionary *json = [@{
        @"_type": @"card"
    } mutableCopy];
    
    if (myself) {
        if (myself.cardName && myself.cardName.length > 0) {
            json[@"name"] = myself.cardName;
        }
        if (myself.cardImage) {
            json[@"face"] = [myself.cardImage base64EncodedStringWithOptions:0];
        }
    }
    
    NSString *nickname = [Settings stringForKey:@"device_name_preference" inMOC:moc];
    if (!nickname || nickname.length == 0) {
        nickname = [Settings stringForKey:@"nickname_preference" inMOC:moc];
    }
    if (nickname && nickname.length > 0) {
        json[@"nickname"] = nickname;
    }
    
    NSNumber *opModeNum = @([Settings intForKey:@"custom_opmode" inMOC:moc]);
    json[@"opMode"] = [opModeNum stringValue];
    
    NSString *icon = [Settings stringForKey:@"icon" inMOC:moc];
    if (icon && icon.length > 0) {
        json[@"icon"] = icon;
        json[@"face"] = icon; // App usa a mesma string do icon ("polvo", etc)
    }
    
    NSString *color = [Settings stringForKey:@"color" inMOC:moc];
    if (color && color.length > 0) {
        json[@"color"] = color;
    }
    
    NSString *deviceId = [Settings stringForKey:@"deviceid_preference" inMOC:moc];
    if (deviceId && deviceId.length > 0) {
        json[@"name"] = deviceId; // "name" agora mapeia para o deviceId no Card
    }
    
    NSString *userId = [[AuthManager shared] getUserId];
    if (userId && userId.length > 0) {
        json[@"userId"] = userId;
    }
    
    NSString *userName = [Settings stringForKey:@"user_preference" inMOC:moc];
    if (userName && userName.length > 0) {
        json[@"userName"] = userName;
    }
    
    NSString *clienteId = [Settings stringForKey:@"clientid_preference" inMOC:moc];
    if (clienteId && clienteId.length > 0) {
        json[@"clienteId"] = clienteId;
    }
    
    [self.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                        topic:[topic stringByAppendingString:@"/info"]
                   topicAlias:@(0)
                          qos:[Settings intForKey:@"qos_preference" inMOC:moc]
                       retain:YES];
}

- (void)stepsFrom:(NSNumber *)from to:(NSNumber *)to {
    NSDate *toDate;
    NSDate *fromDate;
    if (to && [to isKindOfClass:[NSNumber class]]) {
        toDate = [NSDate dateWithTimeIntervalSince1970:to.doubleValue];
    } else {
        toDate = [NSDate date];
    }
    if (from && [from isKindOfClass:[NSNumber class]]) {
        fromDate = [NSDate dateWithTimeIntervalSince1970:from.doubleValue];
    } else {
        NSDateComponents *components = [[NSCalendar currentCalendar]
                                        components: NSCalendarUnitDay |
                                        NSCalendarUnitHour |
                                        NSCalendarUnitMinute |
                                        NSCalendarUnitSecond |
                                        NSCalendarUnitMonth |
                                        NSCalendarUnitYear
                                        fromDate:toDate];
        components.hour = 0;
        components.minute = 0;
        components.second = 0;
        
        fromDate = [[NSCalendar currentCalendar] dateFromComponents:components];
    }
        
    if (!self.pedometer) {
        self.pedometer = [[CMPedometer alloc] init];
    }
    [self.pedometer queryPedometerDataFromDate:fromDate
                                        toDate:toDate
                                   withHandler:
     ^(CMPedometerData *pedometerData, NSError *error) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] StepCounter queryPedometerDataFromDate %ld %ld %ld %ld %@",
                     [pedometerData.numberOfSteps longValue],
                     [pedometerData.floorsAscended longValue],
                     [pedometerData.floorsDescended longValue],
                     [pedometerData.distance longValue],
                     error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
            json[@"_type"] = @"steps";
            json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
            json[@"from"] = [NSNumber doubleValueWithZeroDecimals:fromDate.timeIntervalSince1970];
            json[@"to"] = [NSNumber doubleValueWithZeroDecimals:toDate.timeIntervalSince1970];
            
            if (pedometerData) {
                json[@"steps"] = pedometerData.numberOfSteps;
                if (pedometerData.floorsAscended) {
                    json[@"floorsup"] = pedometerData.floorsAscended;
                }
                if (pedometerData.floorsDescended) {
                    json[@"floorsdown"] = pedometerData.floorsDescended;
                }
                if (pedometerData.distance) {
                    json[@"distance"] = pedometerData.distance.zeroDecimals;
                }
            } else {
                json[@"steps"] = @(-1);
            }
            
            NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
            [self.connection sendData:[self jsonToData:json]
                                topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/step"]
                           topicAlias:@(6)
                                  qos:[Settings theQosInMOC:moc]
                               retain:NO];
        });
    }];
}

#pragma actions

- (BOOL)sendNow:(CLLocation *)location
        withPOI:(NSString *)poi
      withImage:(nullable NSData *)image
  withImageName:(nullable NSString *)imageName {
    OwnTracksLogDebug("[OwnTracksAppDelegate] sendNow %@ withPOI %@ %@ %@", location, poi, image, imageName);
    return [self publishLocation:location trigger:@"u"
                         withPOI:poi
                       withImage:image
                   withImageName:imageName];
}

- (void)reportLocation {
    OwnTracksLogDefault("[OwnTracksAppDelegate] reportLocation");
    CLLocation *location = [LocationManager sharedInstance].location;
    [self publishLocation:location trigger:@"r" withPOI:nil withImage:nil withImageName:nil];
}

- (void)connectionOff {
    OwnTracksLogDefault("[OwnTracksAppDelegate] connectionOff");
    [self.connection disconnect];
}

- (void)terminateSession {
    OwnTracksLogDefault("[OwnTracksAppDelegate] terminateSession");
    
    [self connectionOff];
    [self syncProcessing];
    [[LocationManager sharedInstance] resetRegions];
    [self.connection reset];
    [Friend deleteAllFriendsInManagedObjectContext:CoreData.sharedInstance.mainMOC];
    [[CoreData sharedInstance] sync:CoreData.sharedInstance.mainMOC];
}

- (void)reconnect {
    OwnTracksLogDefault("[OwnTracksAppDelegate] reconnect");
    [self.connection disconnect];
    [self connectForcingCleanSession:TRUE];
}

- (BOOL)publishLocation:(CLLocation *)location
                trigger:(NSString *)trigger
                withPOI:(NSString *)poi
              withImage:(NSData *)image
          withImageName:(NSString *)imageName {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        
    if (!location) {
        OwnTracksLogError("[OwnTracksAppDelegate] location is nil");
        return FALSE;
    }
    
    if (!CLLocationCoordinate2DIsValid(location.coordinate) ||
        location.coordinate.latitude == 0.0 ||
        location.coordinate.longitude == 0.0 ||
        // horizontalAccuracy: A negative value indicates that the latitude and longitude are invalid.
        location.horizontalAccuracy < 0.0) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] isValid:%d lat:%f lon:%f acc:%f",
                     CLLocationCoordinate2DIsValid(location.coordinate),
                     location.coordinate.latitude,
                     location.coordinate.longitude,
                     location.horizontalAccuracy);
        return FALSE;
    }

    
    if (![Settings validIdsInMOC:moc]) {
        OwnTracksLogError("[OwnTracksAppDelegate] settings not valid (yet)");
        return FALSE;
    }
        
    int ignoreInaccurateLocations =
    [Settings intForKey:@"ignoreinaccuratelocations_preference"
                  inMOC:moc];
        
    if (ignoreInaccurateLocations > 0 &&
        location.horizontalAccuracy > 0.0 &&
        location.horizontalAccuracy > ignoreInaccurateLocations) {
        OwnTracksLogDebug("[OwnTracksAppDelegate] location accuracy:%fm, ignoreIncacurationLocations:%dm",
                     location.horizontalAccuracy, ignoreInaccurateLocations);
        return FALSE;
    }
    
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    if (!friend) {
        OwnTracksLogError("[OwnTracksAppDelegate] no friend found");
        return FALSE;
    }
    
    // Update +follow region
    for (Region *anyRegion in friend.hasRegions) {
        if (anyRegion.CLregion.isFollow) {
            if ((anyRegion.radius).doubleValue > 0) {
                anyRegion.lat = @(location.coordinate.latitude);
                anyRegion.lon = @(location.coordinate.longitude);
                double time = [anyRegion.CLregion.identifier substringFromIndex:1].doubleValue;
                if (time == HUGE_VAL || time == -HUGE_VAL || time == 0.0) {
                    time = 30.0;
                }
                if (location.speed >= 0.0) {
                    anyRegion.radius = @(MAX(location.speed * time, 50.0));
                } else {
                    anyRegion.radius = @(MAX(location.horizontalAccuracy, 50.0));
                }
                [[LocationManager sharedInstance] startRegion:anyRegion.CLregion];
            }
        }
    }
              
    friend.tid = [Settings stringForKey:@"trackerid_preference"
                                  inMOC:moc];
    
    NSDate *createdAt = location.timestamp;
    if (fabs(location.timestamp.timeIntervalSince1970 -
             [NSDate date].timeIntervalSince1970) > 1.0) {
        createdAt = [NSDate date];
    }
    
    NSNumber *batteryLevel = [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];
    
    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
    NSNumber *bs = [NSNumber numberWithInteger:batteryState];

    NSString *tag = [[NSUserDefaults standardUserDefaults] stringForKey:@"tag"];
    
    NSMutableArray <NSString *> *inRegions = [[NSMutableArray alloc] init];
    NSMutableArray <NSString *> *inRids = [[NSMutableArray alloc] init];
    for (Region *region in friend.hasRegions) {
        if (!region.CLregion.isFollow) {
            if ([LocationManager sharedInstance].insideCircularRegions[region.name] ||
                [LocationManager sharedInstance].insideBeaconRegions[region.name]) {
                [inRegions addObject:region.name];
                [inRids addObject:region.getAndFillRid];
            }
        }
    }

    NSString *conn = nil;
    NSString *ssid = nil;
    NSString *bssid = nil;
    ConnectionType newConnectionType = self.connType.connectionType;

    switch (newConnectionType) {
        case ConnectionTypeNone:
            conn = @"o";
            break;

        case ConnectionTypeWIFI:
        {
            conn = @"w";
            ssid = self.connType.ssid;
            bssid = self.connType.bssid;
            break;
        }
            
        case ConnectionTypeWWAN:
            conn = @"m";
            break;

        case ConnectionTypeUnknown:
        default:
            break;
    }

    NSNumber *m = [NSNumber numberWithInteger:[LocationManager sharedInstance].monitoring];

    NSNumber *p = nil;
    CMAltitudeData *altitudeData = [LocationManager sharedInstance].altitudeData;
    if (altitudeData) {
        p = altitudeData.pressure;
    }

    NSMutableArray <NSString *> *motionActivities = nil;
    CMMotionActivity *motionActivity = [LocationManager sharedInstance].motionActivity;
    if (motionActivity) {
        NSMutableArray <NSString *> *ma = [[NSMutableArray alloc] init];
        if (motionActivity.stationary) {
            [ma addObject:@"stationary"];
        }
        if (motionActivity.walking) {
            [ma addObject:@"walking"];
        }
        if (motionActivity.running) {
            [ma addObject:@"running"];
        }
        if (motionActivity.automotive) {
            [ma addObject:@"automotive"];
        }
        if (motionActivity.cycling) {
            [ma addObject:@"cycling"];
        }
        if (motionActivity.unknown) {
            [ma addObject:@"unknown"];
        }
        
        if (ma.count > 0) {
            motionActivities = ma;
        }
    }

    Waypoint *waypoint = [friend addWaypoint:location
                                   createdAt:createdAt
                                     trigger:trigger
                                         poi:poi
                                         tag:tag
                                     battery:batteryLevel
                                       image:image
                                   imageName:imageName
                                   inRegions:inRegions
                                      inRids:inRids
                                       bssid:bssid
                                        ssid:ssid
                                           m:m
                                        conn:conn
                                          bs:bs
                                    pressure:p
                            motionActivities:motionActivities];
    if (waypoint) {
        NSDictionary *json = [[OwnTracking sharedInstance] waypointAsJSON:waypoint];
        if (json) {
            NSData *data = [self jsonToData:json];
            [self.connection sendData:data
                                topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/info"]
                           topicAlias:@(1)
                                  qos:[Settings theQosInMOC:moc]
                               retain:[Settings boolForKey:@"retain_preference"
                                                     inMOC:moc]];
        } else {
            OwnTracksLogError("[OwnTracksAppDelegate] no JSON created from waypoint %@", waypoint);
            return FALSE;
        }
        
        int days = [Settings intForKey:@"days_preference" inMOC:moc];
        NSInteger remainingPositions = -1;
        if (days >= 0) {
            remainingPositions = [friend limitWaypointsToMaximumDays:days];
        } else {
            int positions = [Settings intForKey:@"positions_preference" inMOC:moc];
            remainingPositions = [friend limitWaypointsToMaximum:positions];
        }
        [CoreData.sharedInstance sync:moc];
        OwnTracksLogDebug("[OwnTracksAppDelegate] stored location @%@ (%ld)",
                  createdAt, remainingPositions);
        
    } else {
        OwnTracksLogError("[OwnTracksAppDelegate] waypoint creation failed from friend %@, location %@",
                   friend,
                   location);
        return FALSE;
    }
    
    if ([trigger isEqualToString:@"p"]) {
        return TRUE;
    }
    
    if ([UIDevice currentDevice].isBatteryMonitoringEnabled) {
        UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
        float batteryLevel = [UIDevice currentDevice].batteryLevel;
        int downgrade = [Settings intForKey:@"downgrade_preference"
                                      inMOC:moc];
        if ([LocationManager sharedInstance].monitoring == LocationMonitoringMove) {
            if (batteryState != UIDeviceBatteryStateFull &&
                batteryState != UIDeviceBatteryStateCharging &&
                batteryLevel < downgrade / 100.0) {
                // Move Mode, but battery is not full, not charging and less than downgrade%
                [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"downgraded"];
                OwnTracksLogDebug("[OwnTracksAppDelegate] downgraded TRUE");
                LocationManager.sharedInstance.monitoring = LocationMonitoringSignificant;
                [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                          forKey:@"monitoring_preference" inMOC:moc];
                [CoreData.sharedInstance sync:moc];
                [self background];
            } else {
                // Move Mode, battery is full, charging or has more than downgrade%
            }
        } else {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"downgraded"]) {
                if (batteryState == UIDeviceBatteryStateFull
                    || batteryState == UIDeviceBatteryStateCharging ||
                    batteryLevel >= downgrade / 100.0) {
                    // not Move Mode, previously downgraded and battery is charging or full or more than downgrade%
                    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                    OwnTracksLogDebug("[OwnTracksAppDelegate] downgraded FALSE");
                    LocationManager.sharedInstance.monitoring = LocationMonitoringMove;
                    [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                              forKey:@"monitoring_preference" inMOC:moc];
                    [CoreData.sharedInstance sync:moc];
                    [self background];
                } else {
                    // not Move Mode, previously downgraded but battery is not charging nor full
                }
            } else {
                // not Move Mode, but not previously downgraded
            }
        }
    }
    
    if ([LocationManager sharedInstance].monitoring == LocationMonitoringMove) {
        CLLocation *lastLocationWithMovement = [LocationManager sharedInstance].lastLocationWithMovement;
        NSInteger adapt = [Settings intForKey:@"adapt_preference"
                                        inMOC:moc];
        
        if (adapt > 0) {
            if (lastLocationWithMovement && [lastLocationWithMovement.timestamp timeIntervalSinceNow] < -adapt * 60.0) {
                BOOL insideFollowRegion = FALSE;
                for (Region *region in friend.hasRegions) {
                    if (region.CLregion.isFollow) {
                        if ([LocationManager sharedInstance].insideCircularRegions[region.name]) {
                            insideFollowRegion = TRUE;
                            break;
                        }
                    }
                }
                
                if (insideFollowRegion) {
                    // Move Mode, but not moving, in a follow Region, and adapt is on
                    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"adapted"];
                    OwnTracksLogDebug("[OwnTracksAppDelegate] adapted TRUE");
                    LocationManager.sharedInstance.monitoring = LocationMonitoringSignificant;
                    [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                              forKey:@"monitoring_preference" inMOC:moc];
                    [CoreData.sharedInstance sync:moc];
                    [self background];
                }
            }
        }
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"adapted"]) {
            // not Move Mode, previously adapted
            
            [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
            OwnTracksLogDebug("[OwnTracksAppDelegate] adapted FALSE");
            LocationManager.sharedInstance.monitoring = LocationMonitoringMove;
            [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                      forKey:@"monitoring_preference" inMOC:moc];
            [CoreData.sharedInstance sync:moc];
            [self background];
        }
    }

    return TRUE;
}

- (void)sendEmpty:(NSString *)topic {
    OwnTracksLogDebug("[OwnTracksAppDelegate] sendEmpty");
    [self.connection sendData:nil
                        topic:topic
                   topicAlias:nil
                          qos:[Settings theQosInMOC:CoreData.sharedInstance.mainMOC]
                       retain:YES];
}

- (void)sendRegion:(Region *)region {
    OwnTracksLogDebug("[OwnTracksAppDelegate] sendRegion %@", region);
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    if ([Settings validIdsInMOC:moc]) {
        NSMutableDictionary *json = [[[OwnTracking sharedInstance] regionAsJSON:region] mutableCopy];
        NSData *data = [self jsonToData:json];
        [self.connection sendData:data
                            topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/waypoint"]
                       topicAlias:@(7)
                              qos:[Settings theQosInMOC:moc]
                           retain:NO];
    }
}

#pragma internal helpers

- (void)connectForcingCleanSession:(BOOL)force {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    BOOL usePassword = [Settings theMqttUsePasswordInMOC:moc];
    NSString *password = nil;
    if (usePassword) {
        password = [Settings theMqttPassInMOC:moc];
    }
    if ([Settings intForKey:@"mode" inMOC:moc] == CONNECTION_MODE_HTTP) {
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:moc];
        [self.connection connectHTTP:[Settings stringForKey:@"url_preference"
                                                      inMOC:moc]
                                auth:[Settings theMqttAuthInMOC:moc]
                                user:[Settings theMqttUserInMOC:moc]
                                pass:password
                              device:[Settings theDeviceIdInMOC:moc]
                         httpHeaders:[Settings stringForKey:@"httpheaders_preference"
                                                      inMOC:moc]];
    } else {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:nil];
        NSArray *certificates = nil;
        NSString *fileName = [Settings stringForKey:@"clientpkcs" inMOC:moc];
        NSString *passPhrase = [Settings stringForKey:@"passphrase" inMOC:moc];
        if (fileName && fileName.length) {
            OwnTracksLogDebug("[OwnTracksAppDelegate] getting p12 filename:%@ passphrase:%@",
                      fileName, passPhrase);
            NSString *clientPKCSPath = [directoryURL.path stringByAppendingPathComponent:fileName];
            certificates = [MQTTTransport clientCertsFromP12:clientPKCSPath
                                                  passphrase:passPhrase];
            if (!certificates) {
                OwnTracksLogDefault("[OwnTracksAppDelegate] TLS Client Certificate incorrect file or passphrase");
                [NavigationController alertWithTitle:
                     NSLocalizedString(@"TLS Client Certificate",
                                       @"Heading for certificate error message")
                                    message:
                     NSLocalizedString(@"incorrect file or passphrase",
                                       @"certificate error message")
                ];
            }
        }
        
        MQTTQosLevel subscriptionQos =[Settings intForKey:@"subscriptionqos_preference"
                                                    inMOC:moc];
        NSArray *subscriptions = [[NSArray alloc] init];
        if ([Settings boolForKey:@"sub_preference" inMOC:moc]) {
            subscriptions = [[Settings theSubscriptionsInMOC:moc] componentsSeparatedByCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        }
        
        self.connection.subscriptions = subscriptions;
        OwnTracksLogDefault("[OwnTracksAppDelegate] Subscriptions: %@", subscriptions);
        self.connection.subscriptionQos = subscriptionQos;
        
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        json[@"_type"] = @"lwt";
        json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
        
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:moc];
        
        [self.connection connectTo:[Settings theHostInMOC:moc]
                              port:[Settings intForKey:@"port_preference" inMOC:moc]
                                ws:[Settings boolForKey:@"ws_preference" inMOC:moc]
                               tls:[Settings boolForKey:@"tls_preference" inMOC:moc]
                   protocolVersion:[Settings intForKey:@"mqttProtocolLevel" inMOC:moc]
                         keepalive:[Settings intForKey:@"keepalive_preference" inMOC:moc]
                             clean:[Settings intForKey:@"clean_preference" inMOC:moc]
                             force:force
                              auth:[Settings theMqttAuthInMOC:moc]
                              user:[Settings theMqttUserInMOC:moc]
                              pass:password
                         willTopic:[Settings theWillTopicInMOC:moc]
                              will:[self jsonToData:json]
                           willQos:[Settings theWillQosInMOC:moc]
                    willRetainFlag:[Settings theWillRetainFlagInMOC:moc]
                      withClientId:[Settings theClientIdInMOC:moc]
        allowUntrustedCertificates:[Settings boolForKey:@"allowinvalidcerts" inMOC:moc]
                      certificates:certificates];
    }
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject {
    NSData *data;
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject
                                               options:NSJSONWritingSortedKeys
                                                 error:&error];
        if (!data) {
            OwnTracksLogError("[OwnTracksAppDelegate] dataWithJSONObject failed: %@ %@ %@",
                       error.localizedDescription,
                       error.userInfo,
                       [jsonObject description]);
        }
    } else {
        OwnTracksLogError("[OwnTracksAppDelegate] isValidJSONObject failed %@", [jsonObject description]);
    }
    return data;
}

@end
