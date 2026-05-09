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

- (void)startNodeJSWithScriptPath:(NSString *)scriptPath completion:(void (^)(BOOL))completion {
    if (self.isRunning) {
        if (completion) completion(YES);
        return;
    }
    
    // 1. 启动本地 HTTP 服务器，监听 Node.js 的回调
    [self startLocalWebServer];
    
    // 2. 在后台线程启动 Node.js
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *scriptPathCopy = [scriptPath copy];
        int nativePort = self.nativeServerPort;
        
        // 构造参数：node <script> --native-port <port>
        NSMutableArray *args = [NSMutableArray arrayWithObjects:@"node", scriptPathCopy, @"--native-port", [NSString stringWithFormat:@"%d", nativePort], nil];
        
        int argc = (int)args.count;
        char *argv[argc + 1];
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        NSLog(@"🚀 Starting Node.js with script: %@, native-port: %d", scriptPathCopy, nativePort);
        
        int result = node_start(argc, argv);
        NSLog(@"Node.js exited with code %d", result);
        
        // 释放内存
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
    
    // 处理 /onCatPawOpenPort 回调 - Node.js 通知我们它的端口
    [self.webServer addHandlerForMethod:@"GET" path:@"/onCatPawOpenPort" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerDataRequest * _Nonnull request) {
        NSString *portStr = request.query[@"port"];
        if (portStr) {
            int port = [portStr intValue];
            weakSelf.nodeServerPort = port;
            NSLog(@"📡 Received Node.js server port: %d", port);
        }
        return [GCDWebServerDataResponse responseWithText:@"OK"];
    }];
    
    // 处理 /msg 回调 - Node.js 发送的消息
    [self.webServer addHandlerForMethod:@"POST" path:@"/msg" requestClass:[GCDWebServerDataRequest class] processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerDataRequest * _Nonnull request) {
        NSData *data = request.data;
        if (data) {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error && json) {
                NSString *action = json[@"action"];
                if ([action isEqualToString:@"ready"]) {
                    // Node.js 准备就绪
                    if (json[@"port"]) {
                        weakSelf.nodeServerPort = [json[@"port"] intValue];
                        NSLog(@"✅ Node.js ready on port: %d", weakSelf.nodeServerPort);
                    }
                }
                NSLog(@"📨 Message from Node.js: %@", action);
            }
        }
        return [GCDWebServerDataResponse responseWithText:@"OK"];
    }];
    
    // 启动服务器，端口 0 表示自动选择可用端口
    NSError *error;
    [self.webServer startWithOptions:@{
        GCDWebServerOption_Port: @0,
        GCDWebServerOption_BindToLocalhost: @YES
    } error:&error];
    
    if (error) {
        NSLog(@"❌ Failed to start web server: %@", error);
    } else {
        self.nativeServerPort = (int)self.webServer.port;
        NSLog(@"📡 Local web server started on port: %d", self.nativeServerPort);
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

- (int)getNodeServerPort {
    return self.nodeServerPort;
}

@end
