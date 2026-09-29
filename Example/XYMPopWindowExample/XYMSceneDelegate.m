// XYMSceneDelegate.m — Present the component examples. Created by Xuyiming.
#import "XYMSceneDelegate.h"
#import "XYMDemoViewController.h"

@implementation XYMSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
    options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    XYMDemoViewController *demo = [[XYMDemoViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:demo];
    [self.window makeKeyAndVisible];
}
@end

