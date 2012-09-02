/* simplewebkit
   WebHTMLDocumentView.h

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#import <Foundation/Foundation.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebHistoryItem.h>
#import <WebKit/WebView.h>
#import <WebKit/DOM.h>
#import <AppKit/NSTextView.h>

// our document view is a NSTextView which (re)loads HTML as an NSAttributedString
// corresponds to the <body> tag

// FIXME: refactor to WebHTMLView

// special style attributes

extern NSString *DOMHTMLAnchorElementTargetWindow;
extern NSString *DOMHTMLAnchorElementAnchorName;

@interface _WebHTMLDocumentView : NSTextView <WebDocumentView, WebDocumentText>
{
	WebDataSource *_dataSource;
	NSImage *_backgroundImage;
	BOOL _needsLayout;
}
- (void) setLinkColor:(NSColor *) color;
- (void) setBackgroundImage:(NSImage *) img;
@end

// if we display frames
// corresponds to the <frameset> tag

@interface _WebHTMLDocumentFrameSetView : NSSplitView <WebDocumentView, WebDocumentText>	
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}
@end

@interface NSTextAttachmentCell (NSTextAttachment)

+ (NSTextAttachment *) textAttachmentWithCellOfClass:(Class) class;	// manage an arbitrary NSCell as attachment cell

@end

@interface NSViewAttachmentCell : NSTextAttachmentCell
{ // embed an arbitrary NSView in an attachment cell - e.g. an NSTableView (<select size=5>) or NSTextView (<textarea>) or a WebFrame (<iframe>)
	NSTextAttachment *attachment;	// just a pointer
	NSView *view;
}

- (void) setAttachment:(NSTextAttachment *) anAttachment;
- (NSTextAttachment *) attachment;
- (void) setView:(NSView *) view;
- (NSView *) view;

@end

@interface NSHRAttachmentCell : NSTextAttachmentCell
{
    NSTextAttachment *attachment;
    BOOL _shaded;
    int _size;
    int _width;
    BOOL _widthIsPercent;
}
- (void) setShaded:(BOOL)shaded;
- (void) setSize:(int)size;
- (void) setWidth:(int)width;
- (void) setIfWidthIsPercent:(BOOL)flag;

@end

@interface WebView (NSAttributedString)

- (void) _spliceNode:(DOMNode *) node to:(NSMutableAttributedString *) str parentStyle:(DOMCSSStyleDeclaration *) parent parentAttributes:(NSDictionary *) parentAttributes;

@end