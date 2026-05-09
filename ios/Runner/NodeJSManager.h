#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NodeJSManager : NSObject

+ (instancetype)shared;

- (void)startNodeJSWithScriptPath:(NSString *)scriptPath completion:(void (^)(BOOL success))completion;
- (void)stopNodeJS;
- (void)sendMessage:(NSString *)message completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion;

- (int)getNativeServerPort;
- (int)getNodeServerPort;

@end

NS_ASSUME_NONNULL_END
