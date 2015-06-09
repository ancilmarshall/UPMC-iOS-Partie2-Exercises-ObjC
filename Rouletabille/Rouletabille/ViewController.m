//
//  ViewController.m
//  Rouletabille
//
//  Created by Ancil on 6/9/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import "ViewController.h"

static const NSTimeInterval updateInterval = 0.01; //100 Hz

@interface ViewController ()
@property (nonatomic,strong) CMMotionManager* cmmanager;
@property (nonatomic,strong) UIDynamicAnimator* animator;
@property (nonatomic,strong) UIGravityBehavior* gravity;
@property (nonatomic,strong) UICollisionBehavior* boundary;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //core motion manager for acceleration data
    self.cmmanager = [[CMMotionManager alloc] init];
    
    if (self.cmmanager){
        if ([self.cmmanager isAccelerometerAvailable]){
            self.cmmanager.accelerometerUpdateInterval = updateInterval;
            [self.cmmanager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                if (error != nil){
                    NSLog(NSLocalizedString(@"Error in CMAcceleratorData update", nil));
                }
                else {
                    CGFloat acc_x = accelerometerData.acceleration.x;
                    CGFloat acc_y = accelerometerData.acceleration.y;
                    
                    CGFloat mag = sqrt( acc_x*acc_x + acc_y*acc_y);
                    // Gravity angle is measured clockwise from +ve X-axis
                    CGFloat angle = atan2(-acc_y, acc_x);
                    
                    self.gravity.magnitude = mag;
                    self.gravity.angle = angle;
                }
            }];
        }
        else {
            NSLog(@"Acclerometer is not available");
        }
    } else {
        NSLog(NSLocalizedString(@"CMMotion Manager unable to be defined",nil));
    }
    
    //add movable object
    UIView* square = [[UIView alloc] initWithFrame:
                      CGRectMake(100, 100, 100, 100)];
    square.backgroundColor = [UIColor grayColor];
    [self.view addSubview:square];
    
    //UI Kit Dynamics
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[square]];
    self.boundary = [[UICollisionBehavior alloc] initWithItems:@[square]];
    self.boundary.translatesReferenceBoundsIntoBoundary = YES;
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    
}


@end
