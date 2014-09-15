//
//  ProjectDirectory.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectDirectory.h"
#import "NinjaProject.h"

@interface ProjectItem (Internal)

- (void)setParent:(ProjectItem *)parent;

@end

@implementation ProjectDirectory {
    NSString *_path;
    NSMutableArray *_children;
    __weak ProjectItem *_parent;
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    
    if (self)
    {
        _path = [path copy];
        _children = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSString *)path
{
    return _path;
}

- (NSArray *)children
{
    return _children;
}

- (void)addChild:(ProjectItem *)item
{
    [item setParent:self];
    [_children addObject:item];
}

@end
