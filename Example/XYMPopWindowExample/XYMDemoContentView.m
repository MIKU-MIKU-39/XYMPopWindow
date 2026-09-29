// XYMDemoContentView.m — Text content and a long list. Created by Xuyiming.
#import "XYMDemoContentView.h"
#import <Masonry/Masonry.h>

@implementation XYMDemoContentView
- (instancetype)initWithText:(NSString *)text scrolling:(BOOL)scrolling inset:(CGFloat)inset {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.backgroundColor = UIColor.secondarySystemBackgroundColor;
    UILabel *heading = [[UILabel alloc] init];
    heading.text = text;
    heading.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    heading.adjustsFontSizeToFitWidth = YES;
    [self addSubview:heading];
    // The first 32 points are reserved for the component's header-only pan region.
    [heading mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(32);
        make.left.equalTo(self).offset(16);
        make.right.equalTo(self).offset(-90);
        make.height.mas_equalTo(24);
    }];
    if (scrolling) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.rowHeight = 44;
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _tableView.contentInset = UIEdgeInsetsMake(inset, 0, 0, 0);
        _tableView.accessibilityIdentifier = @"demo.list";
        [self addSubview:_tableView];
        [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(heading.mas_bottom).offset(8);
            make.left.right.bottom.equalTo(self);
        }];
        [_tableView layoutIfNeeded];
        _tableView.contentOffset = CGPointMake(0, -inset);
    } else {
        UILabel *body = [[UILabel alloc] init];
        body.text = @"上方调整参数，右上角关闭。\n支持替换为业务自定义内容。";
        body.numberOfLines = 0;
        body.font = [UIFont systemFontOfSize:12];
        body.textColor = UIColor.secondaryLabelColor;
        [self addSubview:body];
        [body mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(heading.mas_bottom).offset(6);
            make.left.right.equalTo(self).inset(16);
            make.bottom.lessThanOrEqualTo(self).offset(-8);
        }];
    }
    return self;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 40; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Item"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Item"];
    cell.textLabel.text = [NSString stringWithFormat:@"示例列表 · 第 %ld 项", (long)indexPath.row + 1];
    return cell;
}
@end
