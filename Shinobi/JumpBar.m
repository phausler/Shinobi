//
//  JumpBar.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/15/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "JumpBar.h"

@implementation JumpBar

@synthesize delegate;

- (void)mouseDown:(NSEvent *)event {
    
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    
    
    NSPathCell *cell = self.cell;
    NSPathComponentCell *componentCell = [cell pathComponentCellAtPoint:point
                                                              withFrame:self.bounds
                                                                 inView:self];
    
    NSRect componentRect = [cell rectOfPathComponentCell:componentCell
                                               withFrame:self.bounds
                                                  inView:self];
    
    NSMenu *menu = [delegate pathControl:self menuForCell:componentCell];
    
    if (menu.numberOfItems > 0) {
        NSUInteger selectedMenuItemIndex = 0;
        for (NSUInteger menuItemIndex = 0; menuItemIndex < menu.numberOfItems; menuItemIndex++) {
            if ([[menu itemAtIndex:menuItemIndex] state] == NSOnState) {
                selectedMenuItemIndex = menuItemIndex;
                break;
            }
        }
        
        NSMenuItem *selectedMenuItem = [menu itemAtIndex:selectedMenuItemIndex];
        [menu popUpMenuPositioningItem:selectedMenuItem
                            atLocation:NSMakePoint(NSMinX(componentRect) - 17, NSMinY(componentRect) + 2)
                                inView:self];
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    if (event.type != NSLeftMouseDown) {
        return nil;
    }
    return [super menuForEvent:event];
}

@end
