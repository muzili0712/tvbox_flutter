#import "NodeJSManager.h"
#import <NodeMobile/NodeMobile.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataRequest.h>

@interface NodeJSManager ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) int nativeServerPort;
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
    }
    return self;
}

- (void)startNodeJS:(void (^)(BOOL))completion {
    if (self.isRunning) {
        if (completion) completion(YES);
        return;
    }

    [self startLocalWebServer];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"js" inDirectory:@"nodejs-project/dist"];
        if (!scriptPath) {
            scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js" inDirectory:@"nodejs-project/dist"];
        }
        if (!scriptPath) {
            scriptPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"js"];
        }
        if (!scriptPath) {
            scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js"];
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
            return;
        }
    });

    self.isRunning = YES;
    if (completion) completion(YES);
}

- (void)startLocalWebServer {
    self.webServer = [[GCDWebServer alloc] init];

    __weak typeof(self) weakSelf = self;

    [self.webServer addHandlerForMethod:@"GET" path:@"/onCatPawOpenPort" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerDataRequest * _Nonnull request) {
        NSString *portStr = request.query[@"port"];
        if (portStr) {
            int port = [portStr intValue];
            NSLog(@"Node.js server port received: %d", port);

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NodeServerPortReceived"
                                                                    object:nil
                                                                  userInfo:@{@"port": @(port)}];
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
    } else {
        self.nativeServerPort = (int)self.webServer.port;
        NSLog(@"Local notification server started on port: %d", self.nativeServerPort);
    }
}

- (void)stopNodeJS {
    self.isRunning = NO;
    [self.webServer stop];
    self.webServer = nil;
    self.nativeServerPort = 0;
}

- (int)getNativeServerPort {
    return self.nativeServerPort;
}

@end
