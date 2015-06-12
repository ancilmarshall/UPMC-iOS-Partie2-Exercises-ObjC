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
@property (nonatomic,strong) NSTimer* timer;
@property (nonatomic,assign) NSUInteger countdownTime;
@property (weak, nonatomic) IBOutlet UILabel *countdownLabel;
@property (nonatomic,assign) NSUInteger score;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (nonatomic,assign) dispatch_queue_t dispatchQueue;
@property (nonatomic,strong) UIDynamicItemBehavior* itemBehavior;
@property (weak, nonatomic) IBOutlet UIButton *startGameButton;
@end

@implementation ViewController

#pragma mark - Initialization

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //initialize audio players background queue, since may take time to load
    self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(self.dispatchQueue, ^(void){
        self.backgroundAudioPlayer = [self audioPlayerWithSound:@"midnight-ride-01a"];
        self.wallBumpAudioPlayer = [self audioPlayerWithSound:@"son"];
        self.starBumpAudioPlayer = [self audioPlayerWithSound:@"squeeze-toy-1"];
        
    });
    
    //core motion manager for acceleration data
    self.cmmanager = [[CMMotionManager alloc] init];
    if (self.cmmanager == nil){
        NSLog(NSLocalizedString(@"CMMotion Manager unable to be defined",nil));
    }
    if (![self.cmmanager isAccelerometerAvailable]){
        NSLog(NSLocalizedString(@"Acclerometer is not available",nil));
    }
    
    //background view
    UIImageView* bg = [[UIImageView alloc] initWithFrame:self.view.frame];
    bg.image = [UIImage imageNamed:@"rouletabille-fond-eau.jpg"];
    [self.view addSubview:bg];
    [self.view sendSubviewToBack:bg]; // to move behind labels in the IB storyboard
    
    //add ball object, centered in the view
    self.ball = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bille"]];
    self.ball.hidden = YES;
    [self.view addSubview:self.ball];
    
    //add starfish target object
    self.starfish = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"etoile-96"]];
    self.starfish.hidden = YES;
    [self.view addSubview:self.starfish];
    
    //UI Kit Dynamics
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[self.ball]];
    self.gravity.magnitude = 0;
    self.gravity.angle = 0;
    
    self.boundary = [[UICollisionBehavior alloc] initWithItems:@[self.ball]];
    self.boundary.translatesReferenceBoundsIntoBoundary = YES;
    
    //add a bit of elasticity to the ball to add bounce
    self.itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.ball]];
    self.itemBehavior.elasticity = 0.5;

    self.boundary.collisionDelegate = self;
    
}

#pragma mark - Game Controls

- (IBAction)startGame:(UIButton *)sender {
    
    // set ball and starfish's frame
    self.ball.center = [self.view center];
    self.starfish.frame = [self randomStarfishFrame];
    [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                     forPath:[self starfishCollisionBoundary]];
    
    self.ball.hidden = NO;
    self.starfish.hidden = NO;
    self.startGameButton.hidden = YES;
    
    dispatch_async(self.dispatchQueue, ^{
        if ([self.backgroundAudioPlayer prepareToPlay]){
            [self.backgroundAudioPlayer play];
        }
    });
    
    self.score = 0;
    //Start a countdown timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(updateCountdownTimer:)
                                                userInfo:nil
                                                 repeats:YES];
    self.countdownTime = 20; //seconds
    [self updateCountdownLabel];
    [self updateScoreLabel];
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    [self.animator addBehavior:self.itemBehavior];
    
    if (self.cmmanager){
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
}

-(void)stopGame;
{
    [self.timer invalidate];
    self.timer = nil;
    //self.ball.hidden = YES;
    //self.starfish.hidden = YES;
    [self.animator removeAllBehaviors];
    if ([self.cmmanager isAccelerometerActive]){
        [self.cmmanager stopAccelerometerUpdates];
    }
    
    dispatch_after(5.0, self.dispatchQueue, ^{
        [self.backgroundAudioPlayer stop];
    });
    
    UIAlertController* alert =
    [UIAlertController alertControllerWithTitle:@"Game Ended"
                                        message:[NSString stringWithFormat:@"Score: %tu",self.score]
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* quit = [UIAlertAction actionWithTitle:@"Quit"
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {
                                                     [self dismissViewControllerAnimated:YES completion:nil];
                                                     self.startGameButton.hidden = NO;
                                                 }];
    UIAlertAction* replay = [UIAlertAction actionWithTitle:@"Replay"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [self startGame:nil];
                                                   }];
    
    [alert addAction:quit];
    [alert addAction:replay];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CollisionBehavior Methods

-(void)collisionBehavior:(UICollisionBehavior *)behavior
     beganContactForItem:(id<UIDynamicItem>)item
  withBoundaryIdentifier:(NSString*)identifier
                 atPoint:(CGPoint)p
{

    if ( [identifier isEqualToString:kStarfishBoundaryIdentifier] ){
        
        if (self.starBumpAudioPlayer != nil){
            if ([self.starBumpAudioPlayer prepareToPlay]){
                [self.starBumpAudioPlayer play];
            }
        } else {
            NSLog(NSLocalizedString(@"StarfishBump Audio Player is nil",nil));
        }
        
        [self.boundary removeBoundaryWithIdentifier:kStarfishBoundaryIdentifier];
        self.starfish.frame = [self randomStarfishFrame];
        [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                         forPath:[self starfishCollisionBoundary]];
        self.score = self.score + 1;
        [self updateScoreLabel];
    }
    else { // wall boundrary
        if (self.wallBumpAudioPlayer != nil){
        }
            if ([self.wallBumpAudioPlayer prepareToPlay]){
                [self.wallBumpAudioPlayer play];
        }
        else {
            NSLog(NSLocalizedString(@"WallBumpAudioPlayer is nil",nil));
        }
    }
}

-(CGRect)randomStarfishFrame;
{
    CGRect frame = self.starfish.frame;
    CGPoint origin = CGPointMake(arc4random_uniform(self.view.frame.size.width-frame.size.width),
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

#pragma mark - Game Labels

-(void)updateCountdownTimer:(id)sender;
{
    self.countdownTime = self.countdownTime - 1;
    [self updateCountdownLabel];
    if (self.countdownTime == 0){
        [self stopGame];
    }
}

-(void)updateCountdownLabel;
{
    NSUInteger minute = self.countdownTime / 60;
    NSUInteger second = self.countdownTime % 60;
    self.countdownLabel.text = [NSString stringWithFormat:@"%02tu:%02tu",minute,second];
}

-(void)updateScoreLabel;
{
    self.scoreLabel.text = [NSString stringWithFormat:@"Score: %tu",self.score];
}



# pragma mark - Helper functions
-(BOOL)prefersStatusBarHidden;
{
    return YES;
}

@end
