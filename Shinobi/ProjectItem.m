//
//  ProjectItem.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectItem.h"
#import "NinjaProject.h"

@implementation ProjectItem {
    __weak ProjectItem *_parent;
}

- (NinjaProject *)project
{
    if (self.parent == nil)
    {
        return nil;
    }
    else
    {
        if (self.parent.parent == nil)
        {
            return (NinjaProject *)self.parent;
        }
        
        return self.parent.project;
    }
}

- (NSString *)absolutePath
{
    NSString *path = self.path;
    
    if ([path isAbsolutePath])
    {
        return path;
    }
    
    return [[self.project.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:self.path];
}

- (void)addChild:(ProjectItem *)item
{
    
}

- (ProjectItem *)parent
{
    return _parent;
}

- (void)setParent:(ProjectItem *)parent
{
    _parent = parent;
}

- (void)beginSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate
{
    
}

- (void)endSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate
{
    
}

- (ProjectItem *)childForPath:(NSString *)path
{
    NSArray *pathComponents = [path pathComponents];
    NSString *firstPathComponent = [pathComponents objectAtIndex:0];
    NSString *remaining =
    
    remaining = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)]];
    
    for (ProjectItem *child in self.children)
    {
        if (self.parent == nil && [child.path isEqualToString:firstPathComponent])
        {
            if ([remaining length] == 0)
            {
                return child;
            }
            else
            {
                return [child childForPath:remaining];
            }
        }
        else if (self.parent != nil && [child.path isEqualToString:[self.path stringByAppendingPathComponent:firstPathComponent]])
        {
            if ([remaining length] == 0)
            {
                return child;
            }
            else
            {
                return [child childForPath:remaining];
            }
        }
    }
    
    return nil;
}

@end
