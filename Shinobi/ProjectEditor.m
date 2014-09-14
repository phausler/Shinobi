//
//  ProjectEditor.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectEditor.h"
#import "NinjaProject.h"
#import "ProjectController.h"

@implementation ProjectEditor {
    ProjectItem *_item;
}

- (ProjectItem *)item
{
    return _item;
}

- (void)setItem:(ProjectItem *)item
{
    if (_item != item)
    {
        [_item endSyntaxHighlighting:self];
        _item = item;
        [_item beginSyntaxHighlighting:self];
        [self.textStorage beginEditing];
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:item.contents attributes:self.typingAttributes];
        [self.textStorage setAttributedString:str];
        [self.enclosingScrollView.verticalRulerView setNeedsDisplay:YES];
        [self.textStorage endEditing];
        [self scrollToBeginningOfDocument:nil];
    }
}

- (void)beginEditingForItem:(ProjectItem *)item
{
    if (_item == item)
    {
        [self.textStorage beginEditing];
    }
}

- (NSDictionary *)attributesForType:(ASTSyntaxType)type
{
    static NSDictionary *typeAttributes = nil;
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        typeAttributes = @{
            @(ASTSyntaxBuiltinType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.75 green:0.22 blue:0.60 alpha:1.0]},
            @(ASTSyntaxNumericLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.55 green:0.52 blue:0.80 alpha:1.0]},
            @(ASTSyntaxStringLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.80 green:0.27 blue:0.30 alpha:1.0]},
            @(ASTSyntaxIntrinsicLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.75 green:0.22 blue:0.60 alpha:1.0]},
            @(ASTSyntaxFunctionType): @{NSForegroundColorAttributeName: [NSColor greenColor]},
            @(ASTSyntaxCXXMethodType): @{NSForegroundColorAttributeName: [NSColor greenColor]},
            @(ASTSyntaxOtherType): @{NSForegroundColorAttributeName: [NSColor grayColor]},
        };
    });
    return typeAttributes[@(type)];
}

- (NSString *)substringWithRange:(NSRange)range
{
    return [[self.textStorage string] substringWithRange:range];
}

- (void)setType:(ASTSyntaxType)type range:(NSRange)range tooltip:(NSString *)tooltip forItem:(ProjectItem *)item
{
    if (_item == item)
    {
        if (tooltip != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
                NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
                [self addToolTipRect:rect owner:self userData:nil];
            });
            NSMutableDictionary *attrs = [[self attributesForType:type] mutableCopy];
            [attrs setObject:tooltip forKey:@"tooltip"];
            [self.textStorage setAttributes:attrs range:range];
        }
        else
        {
            [self.textStorage setAttributes:[self attributesForType:type] range:range];
        }
    }
}

- (void)setType:(ASTSyntaxType)type range:(NSRange)range forItem:(ProjectItem *)item
{
    [self setType:type range:range tooltip:nil forItem:item];
}

- (NSString *)view:(NSView *)view
  stringForToolTip:(NSToolTipTag)tag
             point:(NSPoint)point
          userData:(void *)data
{
    NSUInteger glyphIndex = [self.layoutManager glyphIndexForPoint:point inTextContainer:self.textContainer];
    NSUInteger charIndex = [self.layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    
    if (charIndex >= [self.textStorage length])
    {
        return @"";
    }
    
    NSDictionary *attrs = [self.textStorage attributesAtIndex:charIndex effectiveRange:NULL];
    return [attrs objectForKey:@"tooltip"];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint pt = [self convertPoint:theEvent.locationInWindow fromView:nil];
    self.controller.status = [self view:self stringForToolTip:0 point:pt userData:NULL];
    [super mouseMoved:theEvent];
}

- (void)endEditingForItem:(ProjectItem *)item
{
    if (_item == item)
    {
        [self.textStorage endEditing];
    }
}

@end
