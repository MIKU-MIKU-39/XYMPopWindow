// XYMDemoContentView.h — Content owned only by the example app. Created by Xuyiming.
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface XYMDemoContentView : UIView <UITableViewDataSource>
@property (nonatomic, strong, readonly, nullable) UITableView *tableView;
- (instancetype)initWithText:(NSString *)text scrolling:(BOOL)scrolling inset:(CGFloat)inset;
@end
NS_ASSUME_NONNULL_END
