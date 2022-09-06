# YZVideoPip

[![CI Status](https://img.shields.io/travis/zone1026/YZVideoPip.svg?style=flat)](https://travis-ci.org/zone1026/YZVideoPip)
[![Version](https://img.shields.io/cocoapods/v/YZVideoPip.svg?style=flat)](https://cocoapods.org/pods/YZVideoPip)
[![License](https://img.shields.io/cocoapods/l/YZVideoPip.svg?style=flat)](https://cocoapods.org/pods/YZVideoPip)
[![Platform](https://img.shields.io/cocoapods/p/YZVideoPip.svg?style=flat)](https://cocoapods.org/pods/YZVideoPip)

介绍
==============
YZVideoPip 是处理可通过AVPlayer播放的视频画中画功能。
<br/>

接入说明
==============

* 在项目中的Podfile文件添加如下引用:

    ``` ruby
    # 依赖的仓库Specs #

    # CocoaPods官网Specs
    source 'https://github.com/CocoaPods/Specs.git'
    # YZSpecs私有Specs
    source 'https://github.com/YZSpace/YZSpecs.git'

    target 'XXXProject' do
     # Comment the next line if you don't want to use dynamic frameworks
     use_frameworks!

     # AVPlayer画中画三方库
     pod 'YZVideoPip', '1.0.0'

    end
    ```
* 执行 ```pod install``` 命令获取YZVideoPip库

使用说明
==============

* 注意:

``` objective-c
1、设备系统需要升级到iOS14及以上。
```
``` objective-c
2、项目需要配置后台播放权限【TARGETS->Capabilities->Background Modes —>Audio】。
```
``` objective-c
3、请使用真机运行。
```

* 检测是否支持画中画功能:

``` objective-c
// 是否支持画中画功能
BOOL supported = [YZVideoPipController checkSupportedPip];
```
``` objective-c
// 检测对画中画支持的错误码，未发现错误时返回NSNotFound
YZVideoPipErrorCode errorCode = [YZVideoPipController checkSupportedPipErrorCode];
```

* 初始化YZVideoPipController画中画控制对象:

``` objective-c
// 初始化画中画对象
self.videoPip = [[YZVideoPipController alloc] initWithContainterLayer:self.playerView.layer withPipDelegate:self];
```
* 预加载方案加速开启画中画:

为了快速开启画中画，可以提前预加载视频资源，在触发开启时，可以缩短等待时间。
``` objective-c
// 视频播放后，触发画中画预加载功能,缩短画中画的开启时间
[self.videoPip preloadVideo:self.videoUrl];
```

* 开启画中画:

``` objective-c
// 开启画中画，可指定开始播放的时间
[self.videoPip startVideoPip:self.videoUrl withSeekTime:CMTimeGetSeconds(seekTime)];
```
* 替换当前画中画中的视频资源:

``` objective-c
// 替换当前画中画中的视频资源，可指定开始播放的时间
[self.videoPip replacePipVideo:self.videoUrl withSeekTime:CMTimeGetSeconds(seekTime)];
```
* 销毁视频画中画对象:

``` objective-c
// 销毁视频画中画
[self.videoPip destroyVideoPip];
```

* 视频画中画代理方法:

``` objective-c
/// 收到开启画中画的请求，准备装载画中画程序
- (void)loadVideoPip:(YZVideoPipController *)pip {
    NSLog(@"收到开启画中画的请求，准备装载画中画程序");
    [self showIndicatorView];
}

```
``` objective-c

/// 即将开启画中画
- (void)videoWillStartPip:(YZVideoPipController *)pip {
    NSLog(@"即将开启画中画");
    self.boolValue = YZVideoBoolValueStartPip;
    [self hideIndicatorView];
    [self.navigationController popViewControllerAnimated:YES];
}

```
``` objective-c

/// 已经开启画中画
- (void)videoDidStartPip:(YZVideoPipController *)pip {
    NSLog(@"已经开启画中画");
}

```
``` objective-c

/// 开启画中画失败
- (void)videoStartPip:(YZVideoPipController *)pip withFailedError:(NSError *)error {
    [self hideIndicatorView];
    NSLog(@"pip开启出错 : %@", error);
    
    if (error == nil) return;
    
    NSInteger errorCode = error.code;
    switch (errorCode) {
        case YZVideoPipErrorCodeDeviceUnSupported: {
            NSLog(@"device unsupported pip");
        }
            break;
        case YZVideoPipErrorCodeBackgroundModesNoConfig: {
            NSLog(@"no config audio modes");
        }
            break;
        default:
            break;
    }
}

/// 即将关闭画中画
- (void)videoWillStopPip:(YZVideoPipController *)pip {
    NSLog(@"即将关闭画中画");
}

/// 已经关闭画中画
- (void)videoDidStopPip:(YZVideoPipController *)pip {
    NSLog(@"已经关闭画中画");
    [self hideIndicatorView];
    if (self.boolValue == YZVideoBoolValueRestoredPip) return;
    
    [self destroyVideoPlayVc:YES];
    if (_pipStopBlock != nil) {
        _pipStopBlock();
    }
}

/// 关闭画中画且恢复播放界面
- (void)videoRestorePip:(YZVideoPipController *)pip withCompletionHandler:(nonnull void (^)(BOOL restored))completionHandler {
    NSLog(@"关闭画中画且恢复播放界面");
    [self showIndicatorView];
    self.boolValue = YZVideoBoolValueRestoredPip;
    
    if ([self.naviController.viewControllers containsObject:self] == NO) {
        // 继续使用页面播放器播放视频
        [self.player seekToTime:(CMTimeMakeWithSeconds(pip.currentTime, 600)) completionHandler:^(BOOL finished) {
            [self didClickPlayBtn:nil];
        }];
        // 将页面push到导航控制视图中
        [self.naviController pushViewController:self animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            completionHandler(YES);
        });
        return;
    }
    
    completionHandler(YES);
}

/// 画中画视频将要开始播放
- (void)videoWillStartPlay:(YZVideoPipController *)pip {
    NSLog(@"画中画视频将要开始播放");
}

/// 画中画视频已经开始播放
- (void)videoDidStartPlay:(YZVideoPipController *)pip {
    NSLog(@"画中画视频已经开始播放");
}

/// 画中画视频已播放结束
- (void)videoPipPlayEnd:(YZVideoPipController *)pip {
    NSLog(@"画中画视频已播放结束");
    [self.videoPip replacePipVideo:self.videoUrl withSeekTime:0.0f];
}

- (void)videoWillPreloadVideo:(YZVideoPipController *)pip {
    NSLog(@"将要启动画中画视频预加载功能");
}

- (void)videoDidPreloadVideo:(YZVideoPipController *)pip {
    NSLog(@"画中画视频已经完成预加载，此时点击开启画中画按钮，可快速开启系统画中画");
}
```

## Author

zone1026, 1024105345@qq.com

## License

YZVideoPip is available under the MIT license. See the LICENSE file for more info.
