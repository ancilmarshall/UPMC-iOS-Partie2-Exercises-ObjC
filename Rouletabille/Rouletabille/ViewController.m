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
static const CGFloat acc_deadband_threshold = 0.02;
static const CGFloat acc_max = 1.0;

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
                    if ( mag < acc_deadband_threshold){
                        mag = 0.0f;
                    }
                    else if ( mag > acc_max ){
                        mag = acc_max;
                    }
                    
                    // Gravity angle is measured clockwise from +ve X-axis
                    CGFloat angle = atan2(-acc_y, acc_x);
                    
                    self.gravity.magnitude = mag;
                    self.gravity.angle = angle;
                }
            }];
        }
        else {
            NSLog(NSLocalizedString(@"Acclerometer is not available",nil));
        }
    } else {
        NSLog(NSLocalizedString(@"CMMotion Manager unable to be defined",nil));
    }
    
    //add movable object, centered in the view
    UIImageView* ball = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bille"]];
    CGRect ballframe = ball.frame;
    CGPoint ballcenter = [self.view center];
    ballframe.origin.x =  ballcenter.x-ballframe.size.width/2;
    ballframe.origin.y = ballcenter.y-ballframe.size.height/2;
    ball.frame = ballframe;
    [self.view addSubview:ball];
    
    //UI Kit Dynamics
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[ball]];
    self.gravity.magnitude = 0;
    self.gravity.angle = 0;
    
    self.boundary = [[UICollisionBehavior alloc] initWithItems:@[ball]];
    self.boundary.translatesReferenceBoundsIntoBoundary = YES;
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    
}

-(BOOL)prefersStatusBarHidden;
{
    return YES;
}

@end
