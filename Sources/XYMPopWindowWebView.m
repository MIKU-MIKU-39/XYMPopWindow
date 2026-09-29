// XYMPopWindowWebView.m — Reusable popup component. Created by Xuyiming.

#import "XYMPopWindowWebView.h"
#import <Masonry/Masonry.h>
@interface XYMPopWindowWebView ()<WKUIDelegate,WKNavigationDelegate>

@end

@implementation XYMPopWindowWebView{
    NSString * titleStr;
    NSURL * webUrl;
}

- (instancetype)initWithTitle:(NSString *)title url:(NSURL *)url{
    if(self = [super init]){
        titleStr = [title copy];
        webUrl = url;
        [self setupUI];
    }
    return self;
}
- (void)setupUI{
    self.popView.backgroundColor = [UIColor colorWithWhite:20.0 / 255.0 alpha:1];
    self.popView_header_Radius = 12;
    self.popView_height = 467;
    self.backBtn = [[UIButton alloc]initWithFrame:CGRectMake(12, 12, 24, 24)];
    // 原工程可继续使用自己的图片；独立接入没有该资源时使用系统图标。
    UIImage *backImage = [UIImage imageNamed:@"btn_back"];
    if (!backImage) {
        if (@available(iOS 13.0, *)) backImage = [UIImage systemImageNamed:@"chevron.left"];
    }
    self.backBtn.tintColor = UIColor.whiteColor;
    [self.backBtn setImage:backImage forState:UIControlStateNormal];
    [self.backBtn addTarget:self action:@selector(backTap) forControlEvents:UIControlEventTouchUpInside];
    self.titleL = [[UILabel alloc]init];
    self.titleL.textColor = UIColor.whiteColor;
    self.titleL.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.titleL.text = titleStr;
    self.titleL.textAlignment = NSTextAlignmentCenter;
    self.webView = [[WKWebView alloc]init];
    self.webView.backgroundColor = UIColor.clearColor;
    self.webView.UIDelegate = self;
    
    self.webView.navigationDelegate = self;
    
    self.webView.allowsBackForwardNavigationGestures = YES;
    
    [self.popView addSubview:self.backBtn];
    [self.popView addSubview:self.titleL];
    [self.popView addSubview:self.webView];
    [self.titleL mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.popView).offset(48);
        make.right.equalTo(self.popView).offset(-48);
        make.top.equalTo(self.popView).offset(12);
        make.height.mas_equalTo(24);
    }];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.popView);
        make.top.equalTo(self.popView).offset(44);
    }];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:webUrl];
    [self.webView loadRequest:request];
    
}

- (void)backTap{
    if(self.webView.canGoBack){
        [self.webView goBack];
    }else{
        [self disMissAnimation:YES completion:nil];
    }
}

@end
