#import "NodeJSManager.h"
#import <NodeMobile/NodeMobile.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <CommonCrypto/CommonDigest.h>

@interface NodeJSManager ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) int nativeServerPort;
@property (nonatomic, assign) int managementPort;
@property (nonatomic, assign) int spiderPort;
@property (nonatomic, strong) GCDWebServer *webServer;
@end

@implementation NodeJSManager

+ (instancetype)shared {
    static NodeJSManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NodeJSManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _nativeServerPort = 0;
        _managementPort = 0;
        _spiderPort = 0;
    }
    return self;
}

- (NSString *)getDocumentsSourcePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    NSString *sourcePath = [documentsDir stringByAppendingPathComponent:@"nodejs-project/src/source"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:sourcePath]) {
        [fm createDirectoryAtPath:sourcePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return sourcePath;
}

- (void)startNodeJS:(void (^)(BOOL))completion {
    if (self.isRunning) {
        if (completion) completion(YES);
        return;
    }

    [self startLocalWebServerWithCompletion:^(BOOL webServerStarted) {
        if (!webServerStarted) {
            if (completion) completion(NO);
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js" inDirectory:@"nodejs-project/dist"];
            if (!scriptPath) {
                scriptPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"js" inDirectory:@"nodejs-project/dist"];
            }
            if (!scriptPath) {
                scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js"];
            }
            if (!scriptPath) {
                scriptPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"js"];
            }

            if (scriptPath) {
                int nativePort = self.nativeServerPort;
                NSLog(@"Starting Node.js with script: %@, native-port: %d", scriptPath, nativePort);

                NSMutableArray *args = [NSMutableArray arrayWithObjects:@"node", scriptPath, nil];
                if (nativePort > 0) {
                    [args addObject:@"--native-port"];
                    [args addObject:[NSString stringWithFormat:@"%d", nativePort]];
                }

                int argc = (int)args.count;
                char *argv[argc + 1];
                for (int i = 0; i < argc; i++) {
                    argv[i] = strdup([args[i] UTF8String]);
                }
                argv[argc] = NULL;

                self.isRunning = YES;

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(YES);
                });

                int result = node_start(argc, argv);
                NSLog(@"Node.js exited with code %d", result);

                for (int i = 0; i < argc; i++) {
                    free(argv[i]);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isRunning = NO;
                    [self.webServer stop];
                });
            } else {
                NSLog(@"Node.js script not found!");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(NO);
                });
            }
        });
    }];
}

- (void)startLocalWebServerWithCompletion:(void (^)(BOOL))completion {
    self.webServer = [[GCDWebServer alloc] init];

    [self.webServer addHandlerForMethod:@"GET" path:@"/onCatPawOpenPort" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerDataRequest * _Nonnull request) {
        NSString *portStr = request.query[@"port"];
        NSString *typeStr = request.query[@"type"] ?: @"spider";
        if (portStr) {
            int port = [portStr intValue];
            NSLog(@"Port received: %d, type: %@", port, typeStr);

            dispatch_async(dispatch_get_main_queue(), ^{
                if ([typeStr isEqualToString:@"management"]) {
                    self.managementPort = port;
                } else {
                    self.spiderPort = port;
                }

                [[NSNotificationCenter defaultCenter] postNotificationName:@"NodeServerPortReceived"
                                                                    object:nil
                                                                  userInfo:@{@"port": @(port), @"type": typeStr}];
            });
        }
        return [GCDWebServerDataResponse responseWithText:@"OK"];
    }];

    NSError *error;
    [self.webServer startWithOptions:@{
        GCDWebServerOption_Port: @0,
        GCDWebServerOption_BindToLocalhost: @YES
    } error:&error];

    if (error) {
        NSLog(@"Local web server error: %@", error);
        if (completion) completion(NO);
    } else {
        self.nativeServerPort = (int)self.webServer.port;
        NSLog(@"Local notification server started on port: %d", self.nativeServerPort);
        if (completion) completion(YES);
    }
}

- (void)loadSourceFromURL:(NSString *)urlString
               completion:(void (^)(BOOL success, NSString * _Nullable message))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *sourcePath = [self getDocumentsSourcePath];
        NSString *indexJSPath = [sourcePath stringByAppendingPathComponent:@"index.js"];
        NSString *indexMd5Path = [sourcePath stringByAppendingPathComponent:@"index.js.md5"];
        NSString *configJSPath = [sourcePath stringByAppendingPathComponent:@"index.config.js"];
        NSString *configMd5Path = [sourcePath stringByAppendingPathComponent:@"index.config.js.md5"];

        NSURLSession *session = [NSURLSession sharedSession];
        dispatch_group_t group = dispatch_group_create();

        __block NSData *jsData = nil;
        __block NSData *md5Data = nil;
        __block NSData *configData = nil;
        __block NSData *configMd5Data = nil;
        __block NSError *jsError = nil;
        __block NSError *configError = nil;

        dispatch_group_enter(group);
        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            jsData = data;
            jsError = error;
            dispatch_group_leave(group);
        }] resume];

        dispatch_group_enter(group);
        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:[urlString stringByAppendingString:@".md5"]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            md5Data = data;
            dispatch_group_leave(group);
        }] resume];

        dispatch_group_enter(group);
        NSString *configUrl = [urlString stringByReplacingOccurrencesOfString:@"/index.js" withString:@"/index.config.js"];
        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:configUrl] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            configData = data;
            configError = error;
            dispatch_group_leave(group);
        }] resume];

        dispatch_group_enter(group);
        [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:[configUrl stringByAppendingString:@".md5"]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            configMd5Data = data;
            dispatch_group_leave(group);
        }] resume];

        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));

        if (jsError || !jsData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, [NSString stringWithFormat:@"Failed to download source: %@", jsError.localizedDescription]);
            });
            return;
        }

        if (md5Data) {
            NSString *expectedMd5 = [[NSString alloc] initWithData:md5Data encoding:NSUTF8StringEncoding];
            expectedMd5 = [expectedMd5 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (expectedMd5.length > 0) {
                unsigned char digest[CC_MD5_DIGEST_LENGTH];
                CC_MD5(jsData.bytes, (CC_LONG)jsData.length, digest);
                NSMutableString *actualMd5 = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
                for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
                    [actualMd5 appendFormat:@"%02x", digest[i]];
                }
                if (![actualMd5 isEqualToString:expectedMd5]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO, @"MD5 verification failed");
                    });
                    return;
                }
            }
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:sourcePath withIntermediateDirectories:YES attributes:nil error:nil];

        [jsData writeToFile:indexJSPath atomically:YES];
        if (md5Data) {
            [md5Data writeToFile:indexMd5Path atomically:YES];
        }

        if (configData && !configError) {
            [configData writeToFile:configJSPath atomically:YES];
            if (configMd5Data) {
                [configMd5Data writeToFile:configMd5Path atomically:YES];
            }
        } else {
            NSString *defaultConfig = @"module.exports = { color: [] };";
            [defaultConfig writeToFile:configJSPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendLoadCommandToNodeJS:sourcePath completion:completion];
        });
    });
}

- (void)sendLoadCommandToNodeJS:(NSString *)path completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (self.managementPort <= 0) {
        if (completion) completion(NO, @"Management server not ready");
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"http://127.0.0.1:%d/source/loadPath", self.managementPort];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{@"path": path};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error.localizedDescription);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, @"Source loaded successfully");
        });
    }] resume];
}

- (void)deleteSourceWithCompletion:(void (^)(BOOL))completion {
    NSString *sourcePath = [self getDocumentsSourcePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fm fileExistsAtPath:sourcePath]) {
        [fm removeItemAtPath:sourcePath error:&error];
    }
    self.spiderPort = 0;
    if (completion) completion(error == nil);
}

- (void)stopNodeJS {
    self.isRunning = NO;
    [self.webServer stop];
    self.webServer = nil;
    self.nativeServerPort = 0;
    self.managementPort = 0;
    self.spiderPort = 0;
}

- (int)getNativeServerPort {
    return self.nativeServerPort;
}

- (int)getManagementPort {
    return self.managementPort;
}

- (int)getSpiderPort {
    return self.spiderPort;
}

@end
