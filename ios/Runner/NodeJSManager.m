#import "NodeJSManager.h"
#import <NodeMobile/NodeMobile.h>

@interface NodeJSManager ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) int nodeServerPort;
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
    
    // 在 block 外部复制需要的数据,避免在 block 内引用数组类型
    NSString *scriptPathCopy = [scriptPath copy];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const char *argv[] = {"node", [scriptPathCopy UTF8String], NULL};
        int argc = 2;
        
        NSLog(@"🚀 Starting Node.js with script: %@", scriptPathCopy);
        int result = node_start(argc, (char **)argv);
        NSLog(@"Node.js exited with code %d", result);
        
        // Node.js 进程结束后更新状态
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRunning = NO;
        });
    });
    
    // 立即返回,不等待 Node.js 启动
    // Node.js 会在后台线程中异步启动
    self.isRunning = YES;
    if (completion) completion(YES);
}

- (void)stopNodeJS {
    // NodeMobile 无 node_stop 函数，仅标记
    self.isRunning = NO;
}

- (void)sendMessage:(NSString *)message completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    if (self.nodeServerPort == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"NodeJS" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Node service port unknown"}]);
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

@end
