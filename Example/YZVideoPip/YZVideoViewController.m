//
//  YZVideoViewController.m
//  YZVideoPip
//
//  Created by zone1026 on 08/29/2022.
//  Copyright (c) 2022 zone1026. All rights reserved.
//

#import "YZVideoViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "YZVideoPipController.h"

/// bool枚举值
typedef NS_ENUM(NSInteger, YZVideoBoolValue) {
    /// bool初始值
    YZVideoBoolValueNormal = 1 << 0,
    /// 关闭画中画且恢复播放界面操作
    YZVideoBoolValueRestoredPip = 1 << 1,
    /// 开启画中画操作
    YZVideoBoolValueStartPip = 1 << 2,
};

@interface YZVideoViewController () <YZVideoPipControllerDelegate>

/// 视频视图
@property (weak, nonatomic) IBOutlet UIView *playerView;
/// 播放进度视图
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

/// 播放器层
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
/// 播放器
@property (nonatomic, strong) AVPlayer *player;

/// 计时器
@property (nonatomic, strong) NSTimer *timer;
/// 视频时长
@property (nonatomic, assign) NSTimeInterval duration;
/// 画中画开启对象
@property (nonatomic, strong) YZVideoPipController *videoPip;
///
@property (nonatomic, assign) YZVideoBoolValue boolValue;

/// 指示视图
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

/// 视图所在导航器视图
@property (nonatomic, weak) UINavigationController *naviController;


@end

@implementation YZVideoViewController

#pragma mark - Init

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    self.progressView.progress = 0.0f;
    self.boolValue = YZVideoBoolValueNormal;
    // 开启远程控制
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [self showIndicatorView];
    // 创建视频播放器
    self.player = [AVPlayer playerWithURL:self.videoUrl];
    if (@available(iOS 10.0, *)) { //当播放基于文件的媒体时, 逐渐下载的内容
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer.player = self.player;
    
    // 添加播放状态的监听
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
    // 计时器监听播放进度
    self.timer = [NSTimer timerWithTimeInterval:0.5f target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    // 注册消息通知
    [self registerMessageNotification];
    
    // 初始化画中画对象
    self.videoPip = [[YZVideoPipController alloc] initWithContainterLayer:self.playerView.layer withPipDelegate:self];
    
    // 记录当前视图的导航控制器
    self.naviController = self.navigationController;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.playerLayer.frame = self.playerView.bounds;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
    [self removeMessageNotification];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Configure

#pragma mark - Network

#pragma mark - Event Response

- (IBAction)didClickPlayBtn:(UIButton *)sender {
    [self.player play];
}

- (IBAction)didClickPauseBtn:(UIButton *)sender {
    [self.player pause];
}

- (IBAction)didClickPipBtn:(UIButton *)sender {
    [self didClickPauseBtn:nil];
    // 开启画中画
    self.boolValue = YZVideoBoolValueNormal;
    [self.videoPip startVideoPip:self.videoUrl withSeekTime:CMTimeGetSeconds(self.player.currentTime)];
}

- (void)timerAction {
    self.progressView.progress = 0.0f;
    if (self.duration <= 0.0f) return;
    
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    self.progressView.progress = currentTime / self.duration;
    // 设置锁屏状态下屏幕显示的播放信息
    [self configVideoPlayingCenterInfo:currentTime];
}

#pragma mark - Public Methods

- (void)destroyVideoPlayVc:(BOOL)forced {
    if (forced == NO && self.boolValue == YZVideoBoolValueStartPip) return;
    
    [self.timer invalidate];
    self.timer = nil;
    
    [self.videoPip destroyVideoPip];
    self.videoPip = nil;
    
    [self.player pause];
    self.player = nil;
    
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
}

#pragma mark - Private Methods

/// 显示指示视图
- (void)showIndicatorView {
    [self hideIndicatorView];
    self.indicatorView.center = self.view.center;
    [self.view addSubview:self.indicatorView];
    [self.indicatorView startAnimating];
}

/// 隐藏指示视图
- (void)hideIndicatorView {
    if (_indicatorView == nil) return;
    
    if (_indicatorView.isAnimating == NO) return;
    
    [self.indicatorView stopAnimating];
    [self.indicatorView removeFromSuperview];
}

/// 设置锁屏状态下屏幕显示的播放信息
- (void)configVideoPlayingCenterInfo:(NSTimeInterval)currentTime {
    if (self.boolValue == YZVideoBoolValueStartPip) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
        return;
    }
    
    // 播放信息字典
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    // 标题
    [info setObject:self.videoUrl.lastPathComponent forKey:MPMediaItemPropertyTitle];
    // 视频作者
    [info setObject:([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]) forKey:MPMediaItemPropertyArtist];
    // 播放倍速
    [info setObject:@(self.player.rate) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    // 播放时长
    [info setObject:@(currentTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    // 总时长
    [info setObject:@(self.duration) forKey:MPMediaItemPropertyPlaybackDuration];
    
    // 设置正在播放的信息
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
}

#pragma mark - YZVideoPipControllerDelegate

/// 收到开启画中画的请求，准备装载画中画程序
- (void)loadVideoPip:(YZVideoPipController *)pip {
    NSLog(@"收到开启画中画的请求，准备装载画中画程序");
    [self showIndicatorView];
}

/// 即将开启画中画
- (void)videoWillStartPip:(YZVideoPipController *)pip {
    NSLog(@"即将开启画中画");
    self.boolValue = YZVideoBoolValueStartPip;
    [self hideIndicatorView];
    [self.navigationController popViewControllerAnimated:YES];
}

/// 已经开启画中画
- (void)videoDidStartPip:(YZVideoPipController *)pip {
    NSLog(@"已经开启画中画");
}

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

#pragma mark - Notification

- (void)registerMessageNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playEndNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    // 进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotify:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    // 程序激活
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActiveNotify:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)removeMessageNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)playEndNotification:(NSNotification *)notif {
    // 非播放资源item
    if (notif.object == nil || [notif.object isKindOfClass:[AVPlayerItem class]] == NO) return;
    // 非当前播放资源item
    if (notif.object != self.player.currentItem) return;
    
    // 重新开启播放
    [self.player seekToTime:(CMTimeMake(0.0f, self.player.currentItem.asset.duration.timescale)) completionHandler:^(BOOL finished) {
        [self didClickPlayBtn:nil];
    }];
}

/// 进入后台
- (void)didEnterBackgroundNotify:(NSNotification *)notify {
    /// @warning AVPlayer 在播放视频时，会将图像渲染在 layer 上，因此只要取消图像的渲染，只播放音频，就可以实现后台播放。
    self.playerLayer.player = nil;
}

/// 程序激活
- (void)appDidBecomeActiveNotify:(NSNotification *)notify {
    // 将player绑定在图像渲染layer上
    self.playerLayer.player = self.player;
}

#pragma mark - Setter & Getter

#pragma mark - Lazy Loading

- (AVPlayerLayer *)playerLayer {
    if (_playerLayer == nil) {
        _playerLayer = [AVPlayerLayer layer];
        _playerLayer.frame = self.playerView.bounds;
        _playerLayer.backgroundColor = [UIColor blackColor].CGColor;
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        [self.playerView.layer addSublayer:_playerLayer];
    }
    
    return _playerLayer;
}

- (UIActivityIndicatorView *)indicatorView {
    if (_indicatorView == nil) {
        _indicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 64.0f, 64.0f)];
        _indicatorView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        _indicatorView.layer.masksToBounds = YES;
        _indicatorView.layer.cornerRadius = 5.0f;
        _indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        _indicatorView.hidesWhenStopped = YES;
    }
    
    return _indicatorView;
}

#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    AVPlayerItem *videoItem = object;
    if ([keyPath isEqualToString:@"status"] == YES) {
        switch (videoItem.status) {
            case AVPlayerItemStatusUnknown: {
                
            }
                break;
            case AVPlayerItemStatusReadyToPlay: {
                self.duration = CMTimeGetSeconds(videoItem.duration);
                NSLog(@"video duration = %f", self.duration);
                // 播放视频
                [self didClickPlayBtn:nil];
                // 视频播放后，触发画中画预加载功能,缩短画中画的开启时间
                [self.videoPip preloadVideo:self.videoUrl];
            }
                break;
            case AVPlayerItemStatusFailed: {
                NSLog(@"error : %@", videoItem.error.description);
            }
                break;
            default:
                break;
        }
        [self hideIndicatorView];
    }
}

@end
