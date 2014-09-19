//
//  ProjectEditor.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectEditor.h"
#import "NinjaProject.h"
#import "ProjectDocument.h"
#import "SymbolicDefinition.h"

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
        NSAttributedString *str = nil;
        
        if (item != nil)
        {
            str = [[NSAttributedString alloc] initWithString:item.contents attributes:self.typingAttributes];
            
        }
        else
        {
            str = [[NSAttributedString alloc] initWithString:@"" attributes:self.typingAttributes];
        }
        
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

- (NSDictionary *)attributesForType:(SyntaxType)type
{
    static NSDictionary *typeAttributes = nil;
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        typeAttributes = @{
            @(SyntaxBuiltinType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.75 green:0.22 blue:0.60 alpha:1.0]},
            @(SyntaxNumericLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.55 green:0.52 blue:0.80 alpha:1.0]},
            @(SyntaxStringLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.80 green:0.27 blue:0.30 alpha:1.0]},
            @(SyntaxIntrinsicLiteralType): @{NSForegroundColorAttributeName: [NSColor colorWithRed:0.75 green:0.22 blue:0.60 alpha:1.0]},
            @(SyntaxFunctionType): @{NSForegroundColorAttributeName: [NSColor greenColor]},
            @(SyntaxCXXMethodType): @{NSForegroundColorAttributeName: [NSColor greenColor]},
            @(SyntaxPreprocessorType): @{NSForegroundColorAttributeName: [NSColor brownColor]},
            @(SyntaxCommentType): @{NSForegroundColorAttributeName: [NSColor greenColor]},
            @(SyntaxOtherType): @{NSForegroundColorAttributeName: [NSColor grayColor]},
        };
    });
    return typeAttributes[@(type)];
}

- (NSString *)substringWithRange:(NSRange)range
{
    return [[self.textStorage string] substringWithRange:range];
}

- (void)setType:(SyntaxType)type range:(NSRange)range tooltip:(NSString *)tooltip forItem:(ProjectItem *)item
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

- (void)setType:(SyntaxType)type range:(NSRange)range forItem:(ProjectItem *)item
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
    self.document.status = [self view:self stringForToolTip:0 point:pt userData:NULL];
    [super mouseMoved:theEvent];
}

- (void)endEditingForItem:(ProjectItem *)item
{
    if (_item == item)
    {
        [self.textStorage endEditing];
    }
}

- (void)jumpToSymbol:(NSMenuItem *)sender
{
    SymbolicDefinition *def = [sender representedObject];
    NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:def.range actualCharacterRange:NULL];
    NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
    [self scrollRectToVisible:rect];
}

@end
