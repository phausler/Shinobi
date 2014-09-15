//
//  ProjectController.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectDocument.h"
#import "NinjaProject.h"
#import "ProjectEditor.h"
#import "NinjaNode.h"
#import "ProjectEditorGutter.h"

@interface ProjectDocument () <NinjaProjectBuildDelegate>
@end

@implementation ProjectDocument

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
    
    }
    
    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    self.editor.typingAttributes = @{NSForegroundColorAttributeName: [NSColor whiteColor], NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:11.0]};
    ProjectEditorGutter *gutter = [[ProjectEditorGutter alloc] initWithEditor:self.editor];
    [self.editor.enclosingScrollView setVerticalRulerView:gutter];
    [self.editor.enclosingScrollView setHasHorizontalRuler:NO];
    [self.editor.enclosingScrollView setHasVerticalRuler:YES];
    [self.editor.enclosingScrollView setRulersVisible:YES];
    self.editor.controller = self;
    if (self.rootItem != nil)
    {
        [self.projectOutline reloadData];
    }
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSString *)windowNibName
{
    return @"ProjectDocument";
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return NO;
}

- (BOOL)isEntireFileLoaded
{
    return self.rootItem != nil;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    NSString *path = [url path];
    self.rootItem = [[NinjaProject alloc] initWithPath:path];
    self.rootItem.buildDelegate = self;
    return [self isEntireFileLoaded];
}

- (void)buildProgressChanged:(BuildProgress)progress
{
    [self.buildProgress setMaxValue:progress.total];
    [self.buildProgress setDoubleValue:progress.finished];
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
