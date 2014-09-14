//
//  ProjectEditorGutter.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectEditorGutter.h"
#import "ProjectEditor.h"

@implementation ProjectEditorGutter {
    ProjectEditor *_editor;
    NSMutableIndexSet *_lines;
    NSMutableDictionary *_lineIndicies;
}

- (instancetype)initWithEditor:(ProjectEditor *)editor
{
    self = [super initWithScrollView:editor.enclosingScrollView orientation:NSVerticalRuler];

    if (self)
    {
        _editor = editor;
        _lineIndicies = [[NSMutableDictionary alloc] init];
        self.ruleThickness = 22.0f;
        [self setClientView:editor];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSIndexSet *)lines
{
    if (_lines == nil)
    {
        _lines = [[NSMutableIndexSet alloc] init];
        [[_editor.textStorage string] enumerateSubstringsInRange:NSMakeRange(0, [_editor.textStorage length]) options:NSStringEnumerationByLines usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [_lines addIndex:enclosingRange.location];
        }];
    }
    return _lines;
}

- (NSUInteger)lineNumber:(NSUInteger)start
{
    NSUInteger lineNo = 0;
    if (start == NSNotFound)
    {
        _lineIndicies[@(0)] = @(lineNo);
        return lineNo;
    }
    
    start = [_lines indexGreaterThanOrEqualToIndex:start];
    NSNumber *line = _lineIndicies[@(start)];
    
    if (line != nil)
    {
        return [line unsignedIntegerValue];
    }
    
    NSUInteger prev = [self lineNumber:[_lines indexLessThanIndex:start]];
    lineNo = prev + 1;
    _lineIndicies[@(start)] = @(lineNo);
    return lineNo;
}

- (void)resetLines
{
    for (NSNumber *start in _lineIndicies)
    {
        [self removeMarker:_lineIndicies[start]];
    }
    [_lineIndicies removeAllObjects];

    _lines = nil;
}

- (void)setClientView:(NSView *)aView
{
    id oldClientView;
    
    oldClientView = [self clientView];
    
    if ((oldClientView != aView) && [oldClientView isKindOfClass:[NSTextView class]])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)oldClientView textStorage]];
    }
    [super setClientView:aView];
    if ((aView != nil) && [aView isKindOfClass:[NSTextView class]])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)aView textStorage]];
        
        [self resetLines];
    }
}

- (void)textDidChange:(NSNotification *)notification
{
    [self resetLines];
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
    id			view;
    NSRect		bounds;
    
    bounds = [self bounds];
    
    [[NSColor darkGrayColor] setFill];
    NSRectFill(bounds);
    
    [[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds)) toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];
    
    view = [self clientView];
    
    if ([view isKindOfClass:[NSTextView class]])
    {
        CGFloat yinset = [view textContainerInset].height;
        NSRect visibleRect = [[[self scrollView] contentView] bounds];
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSRightTextAlignment;
        NSDictionary *textAttributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:9.0],NSForegroundColorAttributeName: [NSColor lightGrayColor], NSParagraphStyleAttributeName: style};
        
        NSIndexSet *lines = [self lines];
        
        NSRange glyphRange = [_editor.layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:_editor.textContainer];
        NSRange range = [_editor.layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
        
        NSUInteger currentIndex = [lines indexGreaterThanOrEqualToIndex:range.location];
        
        while (currentIndex != NSNotFound && currentIndex <= NSMaxRange(glyphRange)) {
            NSUInteger line = [self lineNumber:currentIndex];
            NSRect lineRect = [_editor.layoutManager lineFragmentUsedRectForGlyphAtIndex:currentIndex effectiveRange:NULL];
            
            CGFloat ypos = yinset + NSMinY(lineRect) - NSMinY(visibleRect);
            
            NSString *labelText = [NSString stringWithFormat:@"%ld", line];
            
            NSSize stringSize = [labelText sizeWithAttributes:textAttributes];
            
            NSRect r = NSMakeRect(0,
                                  ypos + (NSHeight(lineRect) - stringSize.height) / 2.0,
                                  self.frame.size.width - 2.0f,
                                  NSHeight(lineRect));
            [labelText drawInRect:r withAttributes:textAttributes];

            currentIndex = [lines indexGreaterThanIndex:currentIndex];
        }
    }
}

@end
