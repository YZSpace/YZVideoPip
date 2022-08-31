//
//  YZVideoPipController.h
//  YZVideoPip
//
//  Created by hyz on 2022/8/29.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import "YZVideoPipControllerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/// 画中画错误code值
typedef NS_ENUM(NSInteger, YZVideoPipErrorCode) {
    /// 设备系统低于iOS14
    YZVideoPipErrorCodeDeviceSystemVersionLow = 60001,
    /// 设备不支持画中画功能
    YZVideoPipErrorCodeDeviceUnSupported,
    /// 项目未配置后台播放权限【TARGETS->Capabilities->Background Modes —>Audio】
    YZVideoPipErrorCodeBackgroundModesNoConfig,
    /// 画中画功能已激活（已开启）
    YZVideoPipErrorCodePipHasActive,
    /// 视频播放失败
    YZVideoPipErrorCodePlayFailed,
    /// 画中画开启失败
    YZVideoPipErrorCodePipStartFailed
};

/**
 * @abstract
 * 处理视频画中画功能业务控制器。
 *
 * @description
 * 1、COVideoPipController 是NSObject的子类，用于处理AVPlayer支持播放的视频画中画功能。
 *
 * 2、画中画的开启需在AVPlayerItem状态变为AVPlayerItemStatusReadyToPlay是后处理才可成功。
 *
 * @warning
 * 只能处理AVPlayer支持播放的视频资源。
 *
 */
@interface YZVideoPipController : NSObject

/// 画中画视频当前已播放时长
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;

/// 检测是否支持画中画功能
+ (BOOL)checkSupportedPip;

/// @abstract 检测对画中画支持的错误码
/// @warning 如果没有发现错误时返回NSNotFound
+ (YZVideoPipErrorCode)checkSupportedPipErrorCode;

/// 通过视频URL初始化视频画中画开启对象
/// @param layer 画中画依赖的播放容器层
/// @param delegate 画中画代理
- (instancetype)initWithContainterLayer:(CALayer *)layer withPipDelegate:(id <YZVideoPipControllerDelegate>)delegate;

/// 开启视频画中画
/// @param videoUrl 视频URL
/// @param time 需要定位的播放时间，单位秒。如果大于视频总时长时不起作用
- (void)startVideoPip:(NSURL *)videoUrl withSeekTime:(CGFloat)time;

/// 停止视频画中画
- (void)stopVideoPip;

/// 销毁视频画中画
- (void)destroyVideoPip;

/// 替换当前画中画中的视频资源
/// @param videoUrl 视频URL
/// @param time 需要定位的播放时间，单位秒。如果大于视频总时长时不起作用
- (void)replacePipVideo:(NSURL *)videoUrl withSeekTime:(CGFloat)time;

/// 画中画延迟开启时间，默认0.25
/// @warning 画中画的开启需要做延迟操作，否则无法开启成功
/// @param delayTime 延迟时间，单位秒
- (void)updataPipStartDelayTime:(CGFloat)delayTime;

@end

NS_ASSUME_NONNULL_END
