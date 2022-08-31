//
//  YZNavigationController.m
//  YZVideoPip
//
//  Created by hyz on 2022/8/31.
//  Copyright © 2022 zone1026. All rights reserved.
//

#import "YZNavigationController.h"
#import "YZVideoViewController.h"

@interface YZNavigationController ()

@end

@implementation YZNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (nullable UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (self.topViewController != nil &&
        [self.topViewController isKindOfClass:[YZVideoViewController class]] == YES) {
        [((YZVideoViewController *)self.topViewController) destroyVideoPlayVc:NO];
    }
    
    return [super popViewControllerAnimated:animated];
}

@end
