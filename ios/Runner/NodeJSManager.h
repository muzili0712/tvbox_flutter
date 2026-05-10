#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NodeJSManager : NSObject

+ (instancetype)shared;

- (void)startNodeJS:(void (^)(BOOL success))completion;
- (void)stopNodeJS;
- (int)getNativeServerPort;

@end

NS_ASSUME_NONNULL_END
