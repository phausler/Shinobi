//
//  ProjectEditor.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ProjectItem.h"

@class ProjectDocument;

@interface ProjectEditor : NSTextView <ProjectItemSyntaxHighlightingDelegate>

@property (nonatomic, retain) ProjectItem *item;
@property (nonatomic, weak) ProjectDocument *document;

- (void)jumpToSymbol:(NSMenuItem *)sender;

@end
