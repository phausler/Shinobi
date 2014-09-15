//
//  ProjectController.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectController.h"
#import "NinjaProject.h"
#import "ProjectEditor.h"
#import "NinjaNode.h"
#import "ProjectEditorGutter.h"

@interface ProjectController () <NinjaProjectBuildDelegate>
@end

@implementation ProjectController

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        self.rootItem = [[NinjaProject alloc] initWithPath:@"/Users/phausler/Documents/Shinobi/build.ninja"];
        self.rootItem.buildDelegate = self;
    }
    
    return self;
}

- (void)buildProgressChanged:(BuildProgress)progress
{
    [self.buildProgress setMaxValue:progress.total];
    [self.buildProgress setDoubleValue:progress.finished];
}

- (void)awakeFromNib
{
    self.window.title = [[[self.rootItem path] stringByDeletingLastPathComponent] lastPathComponent];
    self.editor.typingAttributes = @{NSForegroundColorAttributeName: [NSColor whiteColor], NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:11.0]};
    ProjectEditorGutter *gutter = [[ProjectEditorGutter alloc] initWithEditor:self.editor];
    [self.editor.enclosingScrollView setVerticalRulerView:gutter];
    [self.editor.enclosingScrollView setHasHorizontalRuler:NO];
    [self.editor.enclosingScrollView setHasVerticalRuler:YES];
    [self.editor.enclosingScrollView setRulersVisible:YES];
    self.editor.controller = self;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return (item == nil) ? 1 : [[item children] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return (item == nil) ? YES : ([item children] != nil);
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    return (item == nil) ? self.rootItem : [[(ProjectItem *)item children] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (item == self.rootItem)
    {
        return [[[self.rootItem path] stringByDeletingLastPathComponent] lastPathComponent];
    }
    
    return [[item path] lastPathComponent];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    ProjectItem *item = (ProjectItem *)[self.projectOutline itemAtRow:[self.projectOutline selectedRow]];
    if ([item isKindOfClass:[NinjaNode class]])
    {
        self.window.title = [item.path lastPathComponent];
        self.editor.item = item;
    }
}

- (IBAction)build:(id)sender
{
    self.buildProgress.indeterminate = NO;
    [self.buildProgress setMaxValue:1];
    [self.buildProgress setDoubleValue:0];
    self.buildProgress.displayedWhenStopped = YES;
    [self.rootItem build];
}

- (NSString *)status
{
    return self.statusLabel.stringValue;
}

- (void)setStatus:(NSString *)status
{
    if (status == nil)
    {
        status = @"";
    }
    
    self.statusLabel.stringValue = status;
}

@end
