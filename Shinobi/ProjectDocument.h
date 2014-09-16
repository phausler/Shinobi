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
@property (nonatomic, retain) IBOutlet NSPanel *addNewFilePanel;

- (IBAction)build:(id)sender;
- (IBAction)dismissAddNewFile:(id)sender;
- (IBAction)addNewFile:(id)sender;
- (IBAction)addNewFilePrev:(id)sender;
- (IBAction)addNewFileNext:(id)sender;

@end
