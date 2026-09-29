// XYMFeatureViewController.h — Interactive feature demonstrations. Created by Xuyiming.
#import <UIKit/UIKit.h>
#import <XYMPopWindow/XYMPopWindow.h>

typedef NS_ENUM(NSInteger, XYMDemoFeature) {
    XYMDemoFeatureAppearance, XYMDemoFeatureVisibility, XYMDemoFeatureGestures,
    XYMDemoFeatureBackground, XYMDemoFeatureNested, XYMDemoFeatureScroll,
    XYMDemoFeatureContent, XYMDemoFeatureWeb, XYMDemoFeatureCount
};

NS_ASSUME_NONNULL_BEGIN
@interface XYMFeatureViewController : UIViewController
@property (nonatomic, assign, readonly) XYMDemoFeature feature;
@property (nonatomic, strong, readonly, nullable) XYMBasicPopWindowView *rootPopup;
@property (nonatomic, copy, readonly) NSString *eventLog;
+ (NSArray<NSString *> *)featureTitles;
+ (NSArray<NSString *> *)featureDetails;
- (instancetype)initWithFeature:(XYMDemoFeature)feature;
- (void)showExample;
- (void)closeExample;
@end
NS_ASSUME_NONNULL_END
