//
//  HumeurNetServiceBrowserDelegate.h
//  Humeur
//
//  Created by Ancil on 6/17/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HumeurTableViewController.h"

@interface HumeurNetServiceBrowserDelegate : NSObject <NSNetServiceBrowserDelegate>

@property (nonatomic,assign) BOOL searching;
@property (atomic,strong) NSMutableArray* services;
@property (nonatomic,weak) HumeurTableViewController* tableViewController;

-(instancetype)initWithTableViewController:(UITableViewController*)tvc NS_DESIGNATED_INITIALIZER;
-(void)handleError:(NSNumber* )error;
-(void)updateUI;

@end
