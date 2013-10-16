//
//  Demo_Tests.m
//  Demo Tests
//
//  Created by Mario Diana on 10/15/13.
//
//

#import <XCTest/XCTest.h>
#import "DemoAppDelegate.h"


@interface Demo_Tests : XCTestCase

@end

@implementation Demo_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testApplicationDelegateShouldNotBeNil
{
    id appDelegate = [[UIApplication sharedApplication] delegate];
    XCTAssertNotNil(appDelegate, @"Application delegate should not be nil.");
}

- (void)testApplicationDelegateShouldBeInstanceOfAppropriateClass
{
    id appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate isKindOfClass:[DemoAppDelegate class]];
}

@end
