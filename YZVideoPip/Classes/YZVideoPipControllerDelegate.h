//
//  YZVideoPipControllerDelegate.h
//  YZVideoPip
//
//  Created by zone1026 on 2022/8/30.
//  Copyright © 2022 zone1026. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YZVideoPipController;

@protocol YZVideoPipControllerDelegate <NSObject>

@optional

/// @abstract 收到开启画中画的请求，准备装载画中画程序
/// @param pip 画中画控制对象
- (void)loadVideoPip:(YZVideoPipController *)pip;

/// @abstract 即将开启画中画
/// @param pip 画中画控制对象
- (void)videoWillStartPip:(YZVideoPipController *)pip;

/// @abstract 已经开启画中画
/// @param pip 画中画控制对象
- (void)videoDidStartPip:(YZVideoPipController *)pip;

/// @abstract 开启画中画失败
/// @param pip 画中画控制对象
/// @param error 失败原因
- (void)videoStartPip:(YZVideoPipController *)pip withFailedError:(NSError *)error;

/// @abstract 即将关闭画中画
/// @param pip 画中画控制对象
- (void)videoWillStopPip:(YZVideoPipController *)pip;

/// @abstract 已经关闭画中画
/// @param pip 画中画控制对象
- (void)videoDidStopPip:(YZVideoPipController *)pip;

/// @abstract 关闭画中画且恢复播放界面
/// @param pip 画中画控制对象
/// @param completionHandler 是否处理完成
- (void)videoRestorePip:(YZVideoPipController *)pip withCompletionHandler:(void (^)(BOOL restored))completionHandler;

/// @abstract 画中画视频将要开始播放
/// @param pip 画中画控制对象
- (void)videoWillStartPlay:(YZVideoPipController *)pip;

/// @abstract 画中画视频已经开始播放
/// @param pip 画中画控制对象
- (void)videoDidStartPlay:(YZVideoPipController *)pip;

/// @abstract 画中画视频已播放结束
/// @param pip 画中画控制对象
- (void)videoPipPlayEnd:(YZVideoPipController *)pip;

/// @abstract 画中画视频将要开启预加载
/// @param pip 画中画控制对象
- (void)videoWillPreloadVideo:(YZVideoPipController *)pip;

/// @abstract 画中画视频已经完成预加载
/// @param pip 画中画控制对象
- (void)videoDidPreloadVideo:(YZVideoPipController *)pip;

@end

NS_ASSUME_NONNULL_END
