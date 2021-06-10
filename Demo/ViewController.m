//
//  ViewController.m
//  Demo
//
//  Created by Mario Diana on 6/9/21.
//

#import "ViewController.h"
#import "DemoViewController.h"

@interface ViewController ()
@property (nonatomic, weak) IBOutlet UILabel* gainValue;
@property (nonatomic, weak) IBOutlet UISlider* gainSlider;
@property (nonatomic, weak) DemoViewController* demo;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)updateGain:(id)sender
{
    UISlider* slider = sender;
    self.gainValue.text = [NSString stringWithFormat:@"Gain: %.1f", [slider value]];
}


- (IBAction)captureGain:(id)sender
{
    [self updateGain:sender];
    UISlider* slider = sender;
    Float32 gain = (Float32)[slider value];
    [[self demo] setGain:gain];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Grab a handle from the storyboard.
    if ([@"DemoViewControllerSegue" isEqualToString:[segue identifier]]) {
        self.demo = [segue destinationViewController];
    }
}

@end
