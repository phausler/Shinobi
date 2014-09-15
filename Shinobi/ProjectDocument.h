//
//  ProjectController.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JumpBar.h"

@class NinjaProject, ProjectEditor;

@interface ProjectDocument : NSDocument <NSOutlineViewDataSource, NSOutlineViewDelegate, JumpBarDelegate>

@property (nonatomic, retain) NinjaProject *rootItem;
@property (nonatomic, retain) IBOutlet NSOutlineView *projectOutline;
@property (nonatomic, retain) IBOutlet ProjectEditor *editor;
@property (nonatomic, retain) IBOutlet NSProgressIndicator *buildProgress;
@property (nonatomic, retain) IBOutlet NSTextField *statusLabel;
@property (nonatomic, retain) IBOutlet JumpBar *editorPath;
@property (nonatomic, copy) NSString *status;

- (IBAction)build:(id)sender;

@end
