//
//  ViewController.m
//  Rouletabille
//
//  Created by Ancil on 6/9/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ViewController.h"

static const NSTimeInterval updateInterval = 0.01; //100 Hz
static const CGFloat acc_deadband_threshold = 0.02;
static const CGFloat acc_max = 1.0;
static NSString* const kStarfishBoundaryIdentifier = @"starfish";

@interface ViewController () <UICollisionBehaviorDelegate, AVAudioPlayerDelegate>

@property (nonatomic,strong) CMMotionManager* cmmanager;
@property (nonatomic,strong) UIDynamicAnimator* animator;
@property (nonatomic,strong) UIGravityBehavior* gravity;
@property (nonatomic,strong) UICollisionBehavior* boundary;
@property (nonatomic,strong) UIImageView* ball;
@property (nonatomic,strong) UIImageView* starfish;
@property (nonatomic,strong) AVAudioPlayer* backgroundAudioPlayer;
@property (nonatomic,strong) AVAudioPlayer* wallBumpAudioPlayer;
@property (nonatomic,strong) AVAudioPlayer* starBumpAudioPlayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //start background music on background queue
    dispatch_queue_t dispatchQueue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(dispatchQueue, ^(void){
        
        self.backgroundAudioPlayer = [self audioPlayerWithSound:@"midnight-ride-01a"];
        if ([self.backgroundAudioPlayer prepareToPlay]){
            [self.backgroundAudioPlayer play];
        }

        self.wallBumpAudioPlayer = [self audioPlayerWithSound:@"son"];
        self.starBumpAudioPlayer = [self audioPlayerWithSound:@"squeeze-toy-1"];
        
    });
    
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
    self.ball = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bille"]];
    CGRect ballframe = self.ball.frame;
    CGPoint ballcenter = [self.view center];
    ballframe.origin.x =  ballcenter.x-ballframe.size.width/2;
    ballframe.origin.y = ballcenter.y-ballframe.size.height/2;
    self.ball.frame = ballframe;
    [self.view addSubview:self.ball];
    
    //add starfish target
    self.starfish = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"etoile-96"]];
    self.starfish.frame = [self randomStarfishFrame];
    [self.view addSubview:self.starfish];
    
    //UI Kit Dynamics
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[self.ball]];
    self.gravity.magnitude = 0;
    self.gravity.angle = 0;
    
    self.boundary = [[UICollisionBehavior alloc] initWithItems:@[self.ball]];
    self.boundary.translatesReferenceBoundsIntoBoundary = YES;
    
    //add a bit of elasticity to the ball to add bounce
    UIDynamicItemBehavior* itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.ball]];
    itemBehavior.elasticity = 0.5;
    [self.animator addBehavior:itemBehavior];

    [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                     forPath:[self starfishCollisionBoundary]];
    self.boundary.collisionDelegate = self;
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    

}

#pragma mark - CollisionBehavior Methods

-(void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item withBoundaryIdentifier:(NSString*)identifier atPoint:(CGPoint)p
{

    if ( [identifier isEqualToString:kStarfishBoundaryIdentifier] ){
        
        if (self.starBumpAudioPlayer != nil){
            if ([self.starBumpAudioPlayer prepareToPlay]){
                [self.starBumpAudioPlayer play];
            }
        }
        
        [self.boundary removeBoundaryWithIdentifier:kStarfishBoundaryIdentifier];
        self.starfish.frame = [self randomStarfishFrame];
        [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                         forPath:[self starfishCollisionBoundary]];
    }
    else {
        if (self.wallBumpAudioPlayer != nil){
        }
            if ([self.wallBumpAudioPlayer prepareToPlay]){
                [self.wallBumpAudioPlayer play];
        }
        else {
            NSLog(@"WallBumpAudioPlayer is nil");
        }
    }
}

-(CGRect)randomStarfishFrame;
{
    CGRect frame = self.starfish.frame;
    CGPoint origin = CGPointMake( arc4random_uniform(self.view.frame.size.width-frame.size.width),
                                  arc4random_uniform(self.view.frame.size.height-frame.size.height));
    frame.origin = origin;
    return frame;
}

-(UIBezierPath*)starfishCollisionBoundary;
{
    CGRect rect = CGRectInset(self.starfish.frame, self.starfish.frame.size.width*0.25,
                              self.starfish.frame.size.width*0.25);
    return [UIBezierPath bezierPathWithRect:rect];
}


#pragma mark - Audio Player methods


-(AVAudioPlayer*)audioPlayerWithSound:(NSString*)sound;
{
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* path = [bundle pathForResource:sound ofType:@"mp3"];
    NSData* data = [NSData dataWithContentsOfFile:path];
    NSError* error;
    AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error != nil || player == nil){
        NSLog(@"Error initializing audio player");
    }else{
        player.delegate = self;
    }
    return player;
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;
{
    
}

# pragma mark - Helper functions
-(BOOL)prefersStatusBarHidden;
{
    return YES;
}

@end
