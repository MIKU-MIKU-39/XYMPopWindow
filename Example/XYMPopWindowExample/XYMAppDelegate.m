// XYMAppDelegate.m — Configure the example window scene. Created by Xuyiming.
#import "XYMAppDelegate.h"
#import "XYMSceneDelegate.h"

@implementation XYMAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
    options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                                       sessionRole:connectingSceneSession.role];
    configuration.delegateClass = XYMSceneDelegate.class;
    return configuration;
}
@end

