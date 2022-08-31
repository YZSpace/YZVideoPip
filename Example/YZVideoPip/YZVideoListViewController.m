//
//  YZVideoListViewController.m
//  YZVideoPip
//
//  Created by hyz on 2022/8/29.
//  Copyright © 2022 zone1026. All rights reserved.
//

#import "YZVideoListViewController.h"
#import "YZVideoViewController.h"

@interface YZVideoListViewController ()
/// 视频URL集合
@property (nonatomic, strong) NSArray <NSURL *> *videoUrlArr;
/// 视频播放页面视图控制器
@property (nonatomic, strong) YZVideoViewController *videoVc;

@end

@implementation YZVideoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // 视频URL集合
    self.videoUrlArr = @[
        [NSURL URLWithString:@"https://www.apple.com.cn/105/media/cn/ipad-air/2022/5abf2ff6-ee5b-4a99-849c-a127722124cc/films/product/ipad-air-product-tpl-cn-2022_16x9.m3u8"],
        [NSURL URLWithString:@"https://www.apple.com.cn/105/media/us/imac-24/2021/5e004d75-3ad6-4bb9-ab59-41f891fc52f0/anim/colors-hero/large.mp4"],
        [NSURL URLWithString:@"https://www.apple.com.cn/105/media/us/imac-24/2021/5e004d75-3ad6-4bb9-ab59-41f891fc52f0/anim/colors-lifestyle/large.mp4"],
        [NSURL URLWithString:@"https://www.apple.com.cn/105/media/cn/macbook-pro-14-and-16/2021/a1c5d17e-d8e4-4fa8-b70a-bc61bd266412/films/product/macbook-pro-14-and-16-product-tpl-cn-2021_16x9.m3u8"],
        [NSURL URLWithString:@"https://www.apple.com.cn/105/media/cn/apple-watch-se/2020/a2e86bd7-8c1e-4214-952e-80385aba937d/anim/hero/large.mp4"],
        [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"iphone-11" ofType:@"mp4"]],
        [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"iphone-11-pro" ofType:@"mp4"]],
    ];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.videoUrlArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"videoCell" forIndexPath:indexPath];
    NSURL *url = [self.videoUrlArr objectAtIndex:indexPath.row];
    cell.textLabel.text = url.lastPathComponent;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.videoVc != nil) {
        [self.videoVc destroyVideoPlayVc:YES];
    }
    
    self.videoVc = [self.storyboard instantiateViewControllerWithIdentifier:@"videoVc"];
    self.videoVc.videoUrl = [self.videoUrlArr objectAtIndex:indexPath.row];
    __weak typeof(self) weakSelf = self;
    self.videoVc.pipStopBlock = ^{
        weakSelf.videoVc = nil;
    };
    [self.navigationController pushViewController:self.videoVc animated:YES];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
