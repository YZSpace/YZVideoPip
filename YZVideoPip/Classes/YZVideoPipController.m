//
//  YZVideoPipController.m
//  YZVideoPip
//
//  Created by hyz on 2022/8/29.
//

#import "YZVideoPipController.h"

@interface YZVideoPipController () <AVPictureInPictureControllerDelegate>
/// 视频播放器
@property (nonatomic, strong) AVPlayer *player;
/// 视频播放器视图层
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
/// 画中画控制器
@property (nonatomic, strong) AVPictureInPictureController *pipController;

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
    if (_pipController == nil) return;
    
    // 发现不支持画中画的情况
    if ([self callSupportedPipError] == YES) return;
    
    if (_pipController.isPictureInPictureActive == YES) {
        [self startPipError:YZVideoPipErrorCodePipHasActive WithErrorMessage:@""];
        return;
    }
    
    // 尝试停止画中画
    [self stopVideoPip];
    // 抛出程序装载代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(loadVideoPip:)]) {
        [self.delegate loadVideoPip:self];
    }
    // 播放视频
    [self replacePipVideo:videoUrl withSeekTime:time];
    // 需要开启画中画
    _startPip = YES;
}

- (void)stopVideoPip {
    if (_pipController == nil) return;
    
    if (_pipController.isPictureInPictureActive == NO) return;
    
    [_pipController stopPictureInPicture];
}

- (void)destroyVideoPip {
    [self removeMessageNotification];
    [self removePlayerData];
    [self stopVideoPip];
    self.delegate = nil;
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

#pragma mark - Private Methods

/// 尝试处理不支持画中画的错误
- (BOOL)callSupportedPipError {
    // 检测是否支持画中画
    NSInteger errorCode = [YZVideoPipController checkSupportedPipErrorCode];
    // 没有发现错误码
    if (errorCode == NSNotFound) return NO;
    
    // 处理错误码
    if (errorCode == YZVideoPipErrorCodeDeviceSystemVersionLow) {
        [self startPipError:errorCode WithErrorMessage:@"device systewm version low ios14"];
    } else if (errorCode == YZVideoPipErrorCodeDeviceUnSupported) {
        [self startPipError:errorCode WithErrorMessage:@"device unsupported picture in picture"];
    } else if (errorCode == YZVideoPipErrorCodeBackgroundModesNoConfig) {
        [self startPipError:errorCode WithErrorMessage:@"project no config background modes audio"];
    }
    
    return YES;
}

/// 设置视频播放器
/// @param layer 画中画依赖的播放容器层
- (void)commitPlayer:(CALayer *)layer {
    // 发现不支持画中画的情况
    if ([self callSupportedPipError] == YES) return;
    
    // 添加视频播放层
    [layer addSublayer:self.playerLayer];
    // 创建播放器
    self.player = [[AVPlayer alloc] init];
    // 设置播放层的播放器
    self.playerLayer.player = self.player;
    
    // 开启设备播放权限
    @try {
        NSError *error = nil;
        if (@available(iOS 10.0, *)) {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
        } else {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionOrientationBack error:&error];
        }
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
    } @catch (NSException *exception) {
        NSLog(@"AVAudioSession发生错误");
    }
    
    // 创建画中画控制器
    self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
    self.pipController.delegate = self;
}

/// 移除播放器数据
- (void)removePlayerData {
    if (_player == nil) return;
    
    [self.player pause];
    if (self.player.currentItem != nil) {
        [self.player.currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
    }
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.pipController = nil;
}

/// 开启画中画过程失败
/// @param code 失败code
/// @param errorMsg 失败信息
- (void)startPipError:(YZVideoPipErrorCode)code WithErrorMessage:(NSString *)errorMsg {
    if (errorMsg == nil) errorMsg = @"";
    // 创建错误对象
    NSError *error = [NSError errorWithDomain:@"YZVideoPipErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
    // 抛出错误代理方法
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoStartPip:withFailedError:)]) {
        [self.delegate videoStartPip:self withFailedError:error];
    }
}

/// 将要开始视频播放
- (void)willStartVideoPlay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delayStartPipTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 开始播放
        [weakSelf.player play];
        // 开启画中画
        if (weakSelf.startPip == YES) {
            [weakSelf.pipController startPictureInPicture];
        }
        // 抛出开始播放代理方法
        if (weakSelf.delegate != nil && [weakSelf.delegate respondsToSelector:@selector(videoDidStartPlay:)]) {
            [weakSelf.delegate videoDidStartPlay:self];
        }
    });
}

#pragma mark - AVPictureInPictureControllerDelegate

/// 即将开启画中画
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillStartPip:)]) {
        [self.delegate videoWillStartPip:self];
    }
}

/// 已经开启画中画
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidStartPip:)]) {
        [self.delegate videoDidStartPip:self];
    }
}

// 开启画中画失败
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    [self startPipError:YZVideoPipErrorCodePipStartFailed WithErrorMessage:error.description];
}

/// 即将关闭画中画
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoWillStopPip:)]) {
        [self.delegate videoWillStopPip:self];
    }
}

/// 已经关闭画中画
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDidStopPip:)]) {
        [self.delegate videoDidStopPip:self];
    }
}

/// 关闭画中画且恢复播放界面
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
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
    [self startPipError:YZVideoPipErrorCodePlayFailed WithErrorMessage:@"video play error"];
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
        // 把画中画播放层移出屏幕外，使其肉眼不可见
        CGRect frame = [UIScreen mainScreen].bounds;
        frame.origin.x = -(MAX(frame.size.width, frame.size.height));
        _playerLayer.frame = frame;
        _playerLayer.backgroundColor = [UIColor clearColor].CGColor;
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
                // 播放器取消静音
                self.player.muted = NO;
                // seek视频时间
                if (self.seekTime > 0.0f) {
                    NSTimeInterval duration = CMTimeGetSeconds(videoItem.duration);
                    if (self.seekTime < duration) {
                        [self.player seekToTime:(CMTimeMakeWithSeconds(self.seekTime, 60)) completionHandler:^(BOOL finished) {
                            [self willStartVideoPlay];
                        }];
                    } else {
                        [self willStartVideoPlay];
                    }
                } else {
                    [self willStartVideoPlay];
                }
            }
                break;
            case AVPlayerItemStatusFailed: {
                // 播放失败
                [self startPipError:YZVideoPipErrorCodePlayFailed WithErrorMessage:videoItem.error.description];
            }
                break;
            default:
                break;
        }
    }
}

@end
