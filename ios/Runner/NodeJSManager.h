#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NodeJSManager : NSObject

+ (instancetype)shared;

- (void)startNodeJSWithScriptPath:(NSString *)scriptPath completion:(void (^)(BOOL success))completion;
- (void)stopNodeJS;
- (void)sendMessage:(NSString *)message completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion;

// 用于设置 Node 服务端口（由 HTTP 服务器回调设置）
- (void)setNodeServerPort:(int)port;

@end

NS_ASSUME_NONNULL_END
