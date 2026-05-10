#import "NodeJSManager.h"
#import <NodeMobile/NodeMobile.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <GCDWebServer/GCDWebServerResponse.h>

@interface NodeJSManager ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) GCDWebServer *webServer;
@property (nonatomic, assign) int nodeServerPort;
@property (nonatomic, assign) int nativeServerPort;
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

- (void)startNodeJS:(void (^)(BOOL))completion {
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js" inDirectory:@"nodejs-project/dist"];
    if (!scriptPath) {
        scriptPath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"js"];
    }
    
    if (scriptPath) {
        [self startNodeJSWithScriptPath:scriptPath completion:completion];
    } else {
        NSLog(@"Node.js script not found!");
        if (completion) completion(NO);
    }
}

- (void)startNodeJSWithScriptPath:(NSString *)scriptPath completion:(void (^)(BOOL))completion {
    if (self.isRunning) {
        if (completion) completion(YES);
        return;
    }
    
    [self startLocalWebServer];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *scriptPathCopy = [scriptPath copy];
        int nativePort = self.nativeServerPort;
        
        NSMutableArray *args = [NSMutableArray arrayWithObjects:@"node", scriptPathCopy, @"--native-port", [NSString stringWithFormat:@"%d", nativePort], nil];
        
        int argc = (int)args.count;
        char *argv[argc + 1];
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        NSLog(@"Starting Node.js with script: %@, native-port: %d", scriptPathCopy, nativePort);
        
        int result = node_start(argc, argv);
        NSLog(@"Node.js exited with code %d", result);
        
        for (int i = 0; i < argc; i++) {
            free(argv[i]);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRunning = NO;
        });
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
            weakSelf.nodeServerPort = port;
            NSLog(@"Received Node.js server port: %d", port);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NodeServerPortReceived"
                                                                object:nil
                                                              userInfo:@{@"port": @(port)}];
            });
        }
        return [GCDWebServerDataResponse responseWithText:@"OK"];
    }];
    
    [self.webServer addHandlerForMethod:@"POST" path:@"/msg" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerDataRequest * _Nonnull request) {
        NSData *data = request.data;
        if (data) {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error && json) {
                NSString *action = json[@"action"];
                if ([action isEqualToString:@"ready"]) {
                    if (json[@"port"]) {
                        weakSelf.nodeServerPort = [json[@"port"] intValue];
                        NSLog(@"Node.js ready on port: %d", weakSelf.nodeServerPort);
                    }
                }
                NSLog(@"Message from Node.js: %@", action);
            }
        }
        return [GCDWebServerDataResponse responseWithText:@"OK"];
    }];
    
    NSError *error;
    [self.webServer startWithOptions:@{
        GCDWebServerOption_Port: @0,
        GCDWebServerOption_BindToLocalhost: @YES
    } error:&error];
    
    if (error) {
        NSLog(@"Failed to start web server: %@", error);
    } else {
        self.nativeServerPort = (int)self.webServer.port;
        NSLog(@"Local web server started on port: %d", self.nativeServerPort);
    }
}

- (void)stopNodeJS {
    [self.webServer stop];
    self.webServer = nil;
    self.isRunning = NO;
    self.nodeServerPort = 0;
    self.nativeServerPort = 0;
}

- (void)sendMessage:(NSString *)message completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    if (self.nodeServerPort == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"NodeJS" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Node service port unknown - Node.js may not be ready"}]);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/msg", self.nodeServerPort]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [message dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
    }];
    [task resume];
}

- (void)setNodeServerPort:(int)port {
    self.nodeServerPort = port;
}

- (int)getNativeServerPort {
    return self.nativeServerPort;
}

- (int)getNodeServerPort {
    return self.nodeServerPort;
}

@end
