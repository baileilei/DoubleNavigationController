//
//  UIViewController+DoubleNavigationController.m
//  DoubleNavigationController
//
//  Created by Yao Li on 2018/11/12.
//

#import "UIViewController+DoubleNavigationController.h"
#import <objc/runtime.h>
#import "DNBMethodSwizzle.h"
#import "DBNNavigationDecoration.h"

@interface UIViewController (DoubleNavigationController_Private)
@property (strong, nonatomic) UIView *dbn_fakeNavigationBar;
@property (assign, nonatomic) BOOL dbn_viewAppeared;
@property (assign, atomic) BOOL dbn_needsUpdateNavigation;

@property (strong, nonatomic) DBNNavigationDecoration *dbn_navigationDecoration;

- (void)setDbn_secondNavigationBarHidden:(BOOL)hidden;
@end

@implementation UIViewController (DoubleNavigationController_Private) 
+ (void)load {
    static dispatch_once_t dbnOnceToken;
    dispatch_once(&dbnOnceToken, ^{
        Class clz = [self class];
        DBNSwizzleMethod(clz, @selector(viewDidLoad), clz, @selector(dbn_viewDidLoad));
        DBNSwizzleMethod(clz, @selector(viewWillAppear:), clz, @selector(dbn_viewWillAppear:));
        DBNSwizzleMethod(clz, @selector(viewDidAppear:), clz, @selector(dbn_viewDidAppear:));
        DBNSwizzleMethod(clz, @selector(viewWillDisappear:), clz, @selector(dbn_viewWillDisappear:));
    });
}

#pragma mark - Method Swizzling
- (void)dbn_viewDidLoad {
    [self dbn_viewDidLoad];
}

- (void)dbn_viewWillAppear:(BOOL)animated {
    [self dbn_viewWillAppear:animated];
    
    if (!self.navigationController) {
        return;
    }
    
    if (!self.dbn_viewAppeared) {
        __weak typeof(self) _self = self;
        if ([self respondsToSelector:@selector(dbn_configNavigationController:)]) {
            [self performSelector:@selector(dbn_configNavigationController:) withObject:self.navigationController];
            [self.dbn_navigationDecoration addUpdates:^(UINavigationController * _Nullable navigationController) {
                __strong typeof(_self) self = _self;
                [self performSelector:@selector(dbn_configNavigationController:) withObject:navigationController];
            }];
        }
        if ([self respondsToSelector:@selector(dbn_configNavigationItem:)]) {
            [self performSelector:@selector(dbn_configNavigationItem:) withObject:self.navigationItem];
        }
        self.dbn_viewAppeared = YES;
    }
    
    [self setDbn_secondNavigationBarHidden:NO];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)dbn_viewDidAppear:(BOOL)animated {
    [self dbn_viewDidAppear:animated];
    
    if (!self.navigationController) {
        return;
    }
    
    [self setDbn_secondNavigationBarHidden:YES];

    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.dbn_navigationDecoration doDecorate];
}

- (void)dbn_viewWillDisappear:(BOOL)animated {
    [self dbn_viewWillDisappear:animated];

    if (!self.navigationController
        && !self.dbn_fakeNavigationBar) { // self.navigationController will be nil when popToRootViewController
        return;
    }
    
    [self setDbn_secondNavigationBarHidden:NO];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)setDbn_secondNavigationBarHidden:(BOOL)hidden {
    if (!self.navigationController
        && !self.dbn_fakeNavigationBar) {
        return;
    }
    
    if (!objc_getAssociatedObject(self, @selector(dbn_fakeNavigationBar))
        || self.dbn_needsUpdateNavigation) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.navigationController.navigationBar];
        UIView *dbn_fakeNavigationBar = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        objc_setAssociatedObject(self, @selector(dbn_fakeNavigationBar), dbn_fakeNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.dbn_needsUpdateNavigation = NO;
        [self.view addSubview:self.dbn_fakeNavigationBar];
    }
    
    [self.view bringSubviewToFront:self.dbn_fakeNavigationBar];
    self.dbn_fakeNavigationBar.hidden = hidden;

}

#pragma mark - setter & getter
- (UIView *)dbn_fakeNavigationBar {
    return objc_getAssociatedObject(self, @selector(dbn_fakeNavigationBar));
}

- (void)setDbn_fakeNavigationBar:(UIView *)dbn_fakeNavigationBar {
    objc_setAssociatedObject(self, @selector(dbn_fakeNavigationBar), dbn_fakeNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)dbn_viewAppeared {
    return [objc_getAssociatedObject(self, @selector(dbn_viewAppeared)) boolValue];
}

- (void)setDbn_viewAppeared:(BOOL)dbn_viewAppeared {
    objc_setAssociatedObject(self, @selector(dbn_viewAppeared), [NSNumber numberWithBool:dbn_viewAppeared], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)dbn_needsUpdateNavigation {
    return [objc_getAssociatedObject(self, @selector(dbn_needsUpdateNavigation)) boolValue];
}

- (void)setDbn_needsUpdateNavigation:(BOOL)dbn_needsUpdateNavigation {
    objc_setAssociatedObject(self, @selector(dbn_needsUpdateNavigation), [NSNumber numberWithBool:dbn_needsUpdateNavigation], OBJC_ASSOCIATION_RETAIN);
}

- (DBNNavigationDecoration *)dbn_navigationDecoration {
    if (!objc_getAssociatedObject(self, @selector(dbn_navigationDecoration))) {
        DBNNavigationDecoration *decoration = [[DBNNavigationDecoration alloc] initWithNavigationController:self.navigationController];
        objc_setAssociatedObject(self, @selector(dbn_navigationDecoration), decoration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return objc_getAssociatedObject(self, @selector(dbn_navigationDecoration));
}

- (void)setDbn_navigationDecoration:(DBNNavigationDecoration *)dbn_navigationDecoration {
    objc_setAssociatedObject(self, @selector(dbn_navigationDecoration), dbn_navigationDecoration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIViewController (DoubleNavigationController)
- (void)dbn_setNeedsUpdateNavigation {
    self.dbn_needsUpdateNavigation = YES;
}

- (void)dbn_performBatchUpdates:(void (^)(UINavigationController * _Nonnull))updates {
    if (updates) {
        updates(self.navigationController);
        [self.dbn_navigationDecoration addUpdates:updates];
        self.dbn_needsUpdateNavigation = YES;
    }
}
@end