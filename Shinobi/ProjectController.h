//
//  ProjectController.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NinjaProject, ProjectEditor;

@interface ProjectController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, retain) NinjaProject *rootItem;
@property (nonatomic, retain) IBOutlet NSOutlineView *projectOutline;
@property (nonatomic, retain) IBOutlet ProjectEditor *editor;
@property (nonatomic, retain) IBOutlet NSProgressIndicator *buildProgress;
@property (nonatomic, retain) IBOutlet NSWindow *window;
@property (nonatomic, retain) IBOutlet NSTextField *statusLabel;
@property (nonatomic, copy) NSString *status;

- (IBAction)build:(id)sender;

@end
