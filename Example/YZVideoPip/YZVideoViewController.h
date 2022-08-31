//
//  YZVideoViewController.h
//  YZVideoPip
//
//  Created by zone1026 on 08/29/2022.
//  Copyright (c) 2022 zone1026. All rights reserved.
//

@import UIKit;

@interface YZVideoViewController : UIViewController

/// 视频URL
@property (nonatomic, strong) NSURL *videoUrl;
/// 画中画已停止
@property (nonatomic, copy) void (^pipStopBlock)(void);

/// 销毁视频播放页面
/// @param forced 是否强制销毁
- (void)destroyVideoPlayVc:(BOOL)forced;

@end
