//
//  YZVideoPipController.m
//  YZVideoPip
//
//  Created by zone1026 on 2022/8/29.
//  Copyright © 2022 zone1026. All rights reserved.
//

#import "YZVideoPipController.h"

@interface YZVideoPipController () <AVPictureInPictureControllerDelegate>
/// 视频播放器
@property (nonatomic, strong) AVPlayer *player;
/// 视频播放器视图层
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
/// 画中画控制器
@property (nonatomic, strong) AVPictureInPictureController *pipController;

/// 画中画状态值
@property (nonatomic, assign) YZVideoPipStatus pipStatus;
/// 画中画代理
@property (nonatomic, weak) id <YZVideoPipControllerDelegate> delegate;
/// 是否需要开启画中画功能
@property (nonatomic, assign) BOOL startPip;
/// 视频需要seek的时间
@property (nonatomic, assign) CGFloat seekTime;
/// 画中画延迟开启时间，默认0.25
/// @warning 画中画的开启需要做延迟操作，否则无法开启成功
@property (nonatomic, assign) CGFloat delayStartPipTime;

@end

@implementation YZVideoPipController

#pragma mark - Init

- (instancetype)initWithContainterLayer:(CALayer *)layer withPipDelegate:(id <YZVideoPipControllerDelegate>)delegate {
    if (self = [super init]) {
        _delayStartPipTime = 0.25f;
        _delegate = delegate;
        // 将要添加播放器
        [self updateVideoPipStatus:YZVideoPipStatusWillCommitPlayer];
        // 设置播放器
        [self commitPlayer:layer];
        // 注册通知消息
        [self registerMessageNotification];
    }
    
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

#pragma mark - Public Methods

+ (BOOL)checkSupportedPip {
    return [self checkSupportedPipErrorCode] == NSNotFound;
}

+ (YZVideoPipErrorCode)checkSupportedPipErrorCode {
    // 设备系统低于iOS14
    if ([UIDevice currentDevice].systemVersion.floatValue < 14.0f) return YZVideoPipErrorCodeDeviceSystemVersionLow;
    
    // 设备不支持画中画
    if ([AVPictureInPictureController isPictureInPictureSupported] == NO) return YZVideoPipErrorCodeDeviceUnSupported;
    
    // 项目未开启UIBackgroundModes权限配置
    NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    if (backgroundModes == nil || backgroundModes.count <= 0) return YZVideoPipErrorCodeBackgroundModesNoConfig;
    
    BOOL audioModes = NO;
    for (id modes in backgroundModes) {
        if ([modes isKindOfClass:[NSString class]] == YES) {
            if ([(NSString *)modes isEqualToString:@"audio"]) {
                audioModes = YES;
                break;
            }
        }
    }
    
    // 项目UIBackgroundModes权限未勾选audio
    if (audioModes == NO) return YZVideoPipErrorCodeBackgroundModesNoConfig;
    
    // 没有返现错误
    return NSNotFound;
}

- (void)startVideoPip:(NSURL *)videoUrl withSeekTime:(CGFloat)time {
    // 发现不支持画中画的情况
    if ([self callSupportedPipError] == YES) return;
    
    // 画中画已处于激活状态，不需要再次开启
    if (_pipController.isPictureInPictureActive == YES) {
        [self startPipError:YZVideoPipErrorCodePipHasActive withErrorMessage:@"pip has active status"];
        return;
    }
    
    // 视频URL为空
    if (videoUrl == nil || videoUrl.absoluteString.length <= 0) {
        [self startPipError:YZVideoPipErrorCodeEmptyVideoUrl withErrorMessage:@"start pip video url is empty"];
        return;
    }
    
    // 抛出程序装载代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(loadVideoPip:)]) {
        [self.delegate loadVideoPip:self];
    }
    
    // 尝试停止画中画
    [self stopVideoPip];
    
    // videoUrl是当前播放器所持有的播放URL
    if ([self checkSamePlayerVideoUrl:videoUrl] == YES) {
        // 视频正在加载过程中时，不需要再次加载
        if (self.pipStatus == YZVideoPipStatusWillLoadVideo) return;

        // 需要开启画中画
        _startPip = YES;
        _seekTime = time;
        
        // 如果目前处于视频预加载过程中，此时修正pipStatus为WillLoadVideo状态即可，等加载完成后自动触发开启画中画逻辑
        if (self.pipStatus == YZVideoPipStatusWillPreloadVideo) {
            [self updateVideoPipStatus:YZVideoPipStatusWillLoadVideo];
            return;
        }
        
        // 如果videoUrl已完成预加载处理，直接播放视频
        if (self.pipStatus == YZVideoPipStatusDidPreloadVideo || self.pipStatus == YZVideoPipStatusDidStop) {
            [self callStartVideoPlay];
            return;
        }
    }
    
    // 将要加载视频
    [self updateVideoPipStatus:YZVideoPipStatusWillLoadVideo];
    // 播放视频
    [self replacePipVideo:videoUrl withSeekTime:time];
    // 需要开启画中画
    _startPip = YES;
}

- (void)preloadVideo:(NSURL *)videoUrl {
    // 发现不支持画中画的情况，无法处理预加载
    if ([self callSupportedPipError] == YES) return;
    
    // 画中画已处于激活状态，无法处理预加载
    if (_pipController.isPictureInPictureActive == YES) {
        [self startPipError:YZVideoPipErrorCodePipHasActive withErrorMessage:@"pip has active status"];
        return;
    }
    
    // 播放器处于忙碌时，无法处理预加载
    if ([self checkPlayerSuspend] == NO) return;
    
    // videoUrl是当前播放器所持有的播放URL，不用预加载
    if ([self checkSamePlayerVideoUrl:videoUrl] == YES) return;
    
    // 视频URL为空，无法处理预加载
    if (videoUrl == nil || videoUrl.absoluteString.length <= 0) {
        [self startPipError:YZVideoPipErrorCodeEmptyVideoUrl withErrorMessage:@"preload pip video url is empty"];
        return;
    }
    
    // 将要预加载视频
    [self updateVideoPipStatus:YZVideoPipStatusWillPreloadVideo];
    // 抛出将要预加载视频代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillPreloadVideo:)]) {
        [self.delegate videoWillPreloadVideo:self];
    }
    // 播放视频
    [self replacePipVideo:videoUrl withSeekTime:0.0f];
}

- (void)stopVideoPip {
    if (_pipController == nil) return;
    
    if (_pipController.isPictureInPictureActive == NO) return;
    // 请求停止画中画
    [self updateVideoPipStatus:YZVideoPipStatusCallStop];
    // 停止画中画
    [_pipController stopPictureInPicture];
}

- (void)destroyVideoPip {
    [self removeMessageNotification];
    [self stopVideoPip];
    [self removePlayerData];
    self.delegate = nil;
    // 画中画Controller被销毁
    [self updateVideoPipStatus:YZVideoPipStatusDestroy];
}

- (void)replacePipVideo:(NSURL *)videoUrl withSeekTime:(CGFloat)time {
    _startPip = NO;
    _seekTime = time;
    
    // 播放器做静音处理
    self.player.muted = YES;
    // 移除当前播放资源的监听
    if (self.player.currentItem != nil) {
        [self.player.currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
    }
    // 初始化时播放器
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:videoUrl];
    // 播放item添加播放状态的监听
    [playerItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionNew context:nil];
    // 设置当前播放资源
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
    
    // 抛出视频将要开始播放代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillStartPlay:)]) {
        [self.delegate videoWillStartPlay:self];
    }
}

- (void)updataPipStartDelayTime:(CGFloat)delayTime {
    self.delayStartPipTime = delayTime;
}

- (void)updatePlayerRate:(CGFloat)rate {
    if (_player == nil) return;
    
    self.player.rate = rate;
}

#pragma mark - Private Methods

/// 尝试处理不支持画中画的错误
- (BOOL)callSupportedPipError {
    // 检测是否支持画中画
    NSInteger errorCode = [YZVideoPipController checkSupportedPipErrorCode];
    // 没有发现错误码
    if (errorCode == NSNotFound) return NO;
    
    // 处理错误码
    if (errorCode == YZVideoPipErrorCodeDeviceSystemVersionLow) {
        [self startPipError:errorCode withErrorMessage:@"device systewm version low ios14"];
    } else if (errorCode == YZVideoPipErrorCodeDeviceUnSupported) {
        [self startPipError:errorCode withErrorMessage:@"device unsupported picture in picture"];
    } else if (errorCode == YZVideoPipErrorCodeBackgroundModesNoConfig) {
        [self startPipError:errorCode withErrorMessage:@"project no config background modes audio"];
    }
    
    return YES;
}

/// 设置视频播放器
/// @param layer 画中画依赖的播放容器层
- (void)commitPlayer:(CALayer *)layer {
    // 发现不支持画中画的情况
    if ([self callSupportedPipError] == YES) return;
    
    // 添加视频播放层
    //  1.播放容器层有子视图时，将画中画视频层插入到最下层
    //  2.此时可以看到画中画在开启&关闭时，过渡动画是由容器层 to 画中画弹层的联动
    self.playerLayer.frame = layer.bounds;
    [layer insertSublayer:self.playerLayer atIndex:0];
    
    // 创建播放器
    self.player = [[AVPlayer alloc] init];
    // 设置播放层的播放器
    self.playerLayer.player = self.player;
    
    // 开启设备播放权限
    NSError *error = nil;
    @try {
        if (@available(iOS 10.0, *)) {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
        } else {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
        }
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    } @catch (NSException *exception) {
        [self startPipError:YZVideoPipErrorCodeAudioSessionError withErrorMessage:@"AVAudioSession Error"];
    }
    
    // 开启设备播放权限出错
    if (error != nil) {
        [self startPipError:YZVideoPipErrorCodeAudioSessionError withErrorMessage:error.description];
        return;
    }
    
    // 创建画中画控制器
    self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
    self.pipController.delegate = self;
    // 隐藏快进、快退按钮
//    if (@available(iOS 14.0, *)) self.pipController.requiresLinearPlayback = YES;
    // 隐藏快进、快退、播放暂停按钮
//    [self.pipController setValue:@(1) forKey:@"controlsStyle"];
    
    // 播放器已添加完成
    [self updateVideoPipStatus:YZVideoPipStatusDidCommitPlayer];
}

/// 移除播放器数据
- (void)removePlayerData {
    if (_player == nil) return;
    
    [self.player pause];
    if (self.player.currentItem != nil) {
        [self.player.currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
    }
    [self.playerLayer removeFromSuperlayer];
    
    _player = nil;
    _playerLayer = nil;
    _pipController = nil;
}

/// 开启画中画过程失败
/// @param code 失败code
/// @param errorMsg 失败信息
- (void)startPipError:(YZVideoPipErrorCode)code withErrorMessage:(NSString *)errorMsg {
    if (errorMsg == nil) errorMsg = @"";
    
    // 画中画开启时出现错误
    [self updateVideoPipStatus:YZVideoPipStatusError];
    
    // 创建错误对象
    NSError *error = [NSError errorWithDomain:@"YZVideoPipErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
    // 抛出错误代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoStartPip:withFailedError:)]) {
        [self.delegate videoStartPip:self withFailedError:error];
    }
}

/// 更新视频画中画状态
/// @param status 状态枚举值
- (void)updateVideoPipStatus:(YZVideoPipStatus)status {
    self.pipStatus = status;
}

/// 检测播放器是否处于挂起形态
- (BOOL)checkPlayerSuspend {
    // 视频已完成预加载之前的状态都是挂起形态
    if (self.pipStatus == YZVideoPipStatusWillCommitPlayer ||
        self.pipStatus == YZVideoPipStatusDidCommitPlayer ||
        self.pipStatus == YZVideoPipStatusWillPreloadVideo ||
        self.pipStatus == YZVideoPipStatusDidPreloadVideo) {
        return YES;
    }
    
    // 画中画已停止，此时是挂起形态
    if (self.pipStatus == YZVideoPipStatusDidStop) return YES;
    
    return NO;
}

/// 处理视频播放
- (void)callStartVideoPlay {
    if (self.seekTime <= 0.0f || self.player.currentItem == nil) {
        [self willStartVideoPlay];
        return;
    }
    
    // seek视频时间
    if (self.seekTime > 0.0f) {
        NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
        if (self.seekTime < duration) {
            // 时间尺度的精确度可根据开发需求调整USEC_PER_SEC（1000000）、NSEC_PER_SEC（1000000000）
            // CMTimeMakeWithSeconds(self.seekTime, USEC_PER_SEC)
            [self.player seekToTime:(CMTimeMakeWithSeconds(self.seekTime, 600)) completionHandler:^(BOOL finished) {
                [self willStartVideoPlay];
            }];
        } else {
            [self willStartVideoPlay];
        }
    }
}

/// 将要开始视频播放
- (void)willStartVideoPlay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delayStartPipTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf startVideoPlay];
    });
}

/// 开始视频播放逻辑
- (void)startVideoPlay {
    // 开始播放
    [self.player play];
    // 播放器取消静音
    self.player.muted = NO;
    // 视频已播放
    [self updateVideoPipStatus:YZVideoPipStatusVideoDidPlay];
    // 抛出开始播放代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidStartPlay:)]) {
        [self.delegate videoDidStartPlay:self];
    }
    // 开启画中画
    if (self.startPip == YES) {
        // 请求开启画中画
        [self updateVideoPipStatus:YZVideoPipStatusCallStart];
        [self.pipController startPictureInPicture];
    }
}

/// 检测videoUrl是否是当前播放器所持有的播放URL
/// @param videoUrl 视频URL
- (BOOL)checkSamePlayerVideoUrl:(NSURL *)videoUrl {
    // 无播放器 or 播放器无播放资源
    if (_player == nil || _player.currentItem.asset == nil) return NO;
    
    // 非AVURLAsset
    if ([_player.currentItem.asset isKindOfClass:[AVURLAsset class]] == NO) return NO;
    
    // 获取播放器当前持有的播放资源
    NSURL *playerUrl = ((AVURLAsset *)_player.currentItem.asset).URL;
    
    // 是否是同一个播放URL
    if ([playerUrl isEqual:videoUrl] == YES) return YES;
    
    // 是否是同一个播放URL内容
    if ([playerUrl.absoluteString isEqualToString:videoUrl.absoluteString] == YES) return YES;
    
    return NO;
}

#pragma mark - AVPictureInPictureControllerDelegate

/// 即将开启画中画
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    // 画中画即将开启
    [self updateVideoPipStatus:YZVideoPipStatusWillStart];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillStartPip:)]) {
        [self.delegate videoWillStartPip:self];
    }
}

/// 已经开启画中画
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    // 画中画已经开启
    [self updateVideoPipStatus:YZVideoPipStatusDidStart];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidStartPip:)]) {
        [self.delegate videoDidStartPip:self];
    }
}

/// 开启画中画失败
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    [self startPipError:YZVideoPipErrorCodePipStartFailed withErrorMessage:error.description];
}

/// 即将关闭画中画
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    // 画中画即将关闭
    [self updateVideoPipStatus:YZVideoPipStatusWillStop];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillStopPip:)]) {
        [self.delegate videoWillStopPip:self];
    }
}

/// 已经关闭画中画
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    // 画中画已经关闭
    [self updateVideoPipStatus:YZVideoPipStatusDidStop];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidStopPip:)]) {
        [self.delegate videoDidStopPip:self];
    }
}

/// 关闭画中画且恢复播放界面
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    // 关闭画中画且恢复播放界面
    [self updateVideoPipStatus:YZVideoPipStatusRestore];
    // 停止播放
    [self.player pause];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoRestorePip:withCompletionHandler:)]) {
        [self.delegate videoRestorePip:self withCompletionHandler:completionHandler];
    }
}

#pragma mark - Notification

/// 注册通知消息
- (void)registerMessageNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playEndNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFailedNotification:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
}

/// 移除通知消息
- (void)removeMessageNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)playEndNotification:(NSNotification *)notication {
    // 非播放资源item
    if (notication.object == nil || [notication.object isKindOfClass:[AVPlayerItem class]] == NO) return;
    // 非当前播放资源item
    if (notication.object != self.player.currentItem) return;
    
    // 抛出播放完成代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoPipPlayEnd:)]) {
        [self.delegate videoPipPlayEnd:self];
    }
}

- (void)playFailedNotification:(NSNotification *)notication {
    // 非播放资源item
    if (notication.object == nil || [notication.object isKindOfClass:[AVPlayerItem class]] == NO) return;
    // 非当前播放资源item
    if (notication.object != self.player.currentItem) return;
    
    // 播放失败
    [self startPipError:YZVideoPipErrorCodePlayFailed withErrorMessage:@"video play error"];
}

- (void)audioSessionInterruptionNotification:(NSNotification *)notification {
    if (nil == notification.userInfo) return;
   
    // 中断状态类型
    AVAudioSessionInterruptionType type = [[notification.userInfo objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan: { // 开始中断
            // 停止播放
            [self.player pause];
        }
            break;
        case AVAudioSessionInterruptionTypeEnded: { // 中断已经结束
            // 如果中断结束会附带一个KEY值，表明是否应该恢复音频
            AVAudioSessionInterruptionOptions options = [[notification.userInfo objectForKey:AVAudioSessionInterruptionOptionKey] integerValue];
            if (options == AVAudioSessionInterruptionOptionShouldResume) {
                // 恢复播放
                [self.player play];
            }
        }
            break;
        default:
            break;
    }
}

#pragma mark - Setter & Getter

- (NSTimeInterval)currentTime {
    if (_player == nil) return 0.0f;
    
    return CMTimeGetSeconds(self.player.currentTime);
}

#pragma mark - Lazy Loading

- (AVPlayerLayer *)playerLayer {
    if (_playerLayer == nil) {
        _playerLayer = [AVPlayerLayer layer];
        _playerLayer.backgroundColor = [UIColor blackColor].CGColor;
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
    
    return _playerLayer;
}

#pragma mark - Observer

/// 播放器监听
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(status))] == YES) { // 播放状态
        AVPlayerItem *videoItem = object;
        switch (videoItem.status) {
            case AVPlayerItemStatusUnknown: {
                
            }
                break;
            case AVPlayerItemStatusReadyToPlay: {
                if (self.pipStatus == YZVideoPipStatusWillPreloadVideo) { // 预加载操作
                    // 预加载完成
                    [self updateVideoPipStatus:YZVideoPipStatusDidPreloadVideo];
                    // 抛出预加载视频完成代理方法
                    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidPreloadVideo:)]) {
                        [self.delegate videoDidPreloadVideo:self];
                    }
                    return;
                }
                
                // 视频已加载完成
                [self updateVideoPipStatus:YZVideoPipStatusDidLoadVideo];
                // 处理视频播放
                [self callStartVideoPlay];
            }
                break;
            case AVPlayerItemStatusFailed: {
                // 播放失败
                [self startPipError:YZVideoPipErrorCodePlayFailed withErrorMessage:videoItem.error.description];
            }
                break;
            default:
                break;
        }
    }
}

@end
