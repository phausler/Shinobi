//
//  BorderView.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/15/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "BorderView.h"

@implementation BorderView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor grayColor] setStroke];
    [NSBezierPath strokeRect:self.bounds];
}

@end
