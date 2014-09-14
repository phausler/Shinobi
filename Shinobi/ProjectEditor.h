//
//  ProjectEditor.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ProjectItem.h"

@class ProjectController;

@interface ProjectEditor : NSTextView <ProjectItemSyntaxHighlightingDelegate>

@property (nonatomic, retain) ProjectItem *item;
@property (nonatomic, weak) ProjectController *controller;

@end
