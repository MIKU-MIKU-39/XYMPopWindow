// XYMPopWindowWebView.h — Reusable popup component. Created by Xuyiming.

#import "XYMBasicPopWindowView.h"
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XYMPopWindowWebView : XYMBasicPopWindowView
@property (nonatomic, strong) WKWebView * webView;
@property (nonatomic, strong) UILabel * titleL;
@property (nonatomic, strong) UIButton * backBtn;

- (instancetype)initWithTitle:(NSString *)title url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
