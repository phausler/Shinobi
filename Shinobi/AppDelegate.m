//
//  AppDelegate.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "AppDelegate.h"
#import "ProjectDocument.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate
            
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

- (IBAction)build:(id)sender
{
    id currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if ([currentDocument isKindOfClass:[ProjectDocument class]])
    {
        [currentDocument build:sender];
    }
}

- (IBAction)clean:(id)sender
{
    id currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if ([currentDocument isKindOfClass:[ProjectDocument class]])
    {
        [currentDocument clean:sender];
    }
}

@end
