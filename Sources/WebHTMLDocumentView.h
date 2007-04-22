//
//  WebHTMLDocumentView.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Sep 01 2005.
//  Copyright (c) 2005 DSITRI. All rights reserved.
//

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

@interface _WebHTMLDocumentView : NSTextView <WebDocumentView, WebDocumentText>
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}
@end

// if we display frames
// corresponds to the <frameset> tag

@interface _WebHTMLDocumentFrameSetView : NSView <WebDocumentView, WebDocumentText>	
{
	WebDataSource *_dataSource;
	BOOL _needsLayout;
}
@end

@interface NSTextAttachmentCell (NSTextAttachment)

+ (NSTextAttachment *) textAttachmentWithCellOfClass:(Class) class;	// manage an arbitrary NSCell as attachment cell

@end

@interface NSAnyViewAttachmentCell : NSTextAttachmentCell
{ // embed any NSView in an attachment cell - e.g. an NSTableView (<select size=5>) or NSTextView (<textarea>)
	NSView *_view;
}

- (NSSize) cellSize;
- (void) setView:(NSView *) view;
- (NSView *) view;

@end
