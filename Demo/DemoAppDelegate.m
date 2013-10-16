
#import "DemoAppDelegate.h"
#import "DemoViewController.h"

@implementation DemoAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	DemoViewController *viewController = [[DemoViewController alloc] initWithNibName:@"DemoViewController" bundle:nil];
	self.window.rootViewController = viewController;
	[self.window makeKeyAndVisible];
	return YES;
}

@end
