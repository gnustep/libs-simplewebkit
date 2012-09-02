/* simplewebkit
   WebHTMLDocumentView.m

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

#import "Private.h"
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebHTMLDocumentView.h>
#import <WebKit/DOMCSS.h>

NSString *DOMHTMLAnchorElementTargetWindow=@"DOMHTMLAnchorElementTargetName";
NSString *DOMHTMLAnchorElementAnchorName=@"DOMHTMLAnchorElementAnchorName";

#if !defined (GNUSTEP) && !defined (__mySTEP__)
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_3)	

// Tiger (10.4) and later - include (through WebKit/WebView.h and Cocoa/Cocoa.h) and implements Tables

#else

// declarations for headers of classes introduced in OSX 10.4 (#import <NSTextTable.h>) on systems that don't have it

@interface NSTextBlock : NSObject <NSCoding, NSCopying>
- (void) setBackgroundColor:(NSColor *) color;
- (void) setBorderColor:(NSColor *) color;
- (void) setWidth:(float) width type:(int) type forLayer:(int) layer;

// NOTE: values must match implementation in Apple AppKit!

#define NSTextBlockBorder 0
#define NSTextBlockPadding -1
#define NSTextBlockMargin 1

#define NSTextBlockAbsoluteValueType 0
#define NSTextBlockPercentageValueType 1

#define NSTextBlockTopAlignment	0
#define NSTextBlockMiddleAlignment 1
#define NSTextBlockBottomAlignment 2
#define NSTextBlockBaselineAlignment 3

#define NSTextBlockWidth	0
#define NSTextBlockMinimumWidth	1
#define NSTextBlockMaximumWidth	2
#define NSTextBlockHeight	4
#define NSTextBlockMinimumHeight	5
#define NSTextBlockMaximumHeight	6

#define NSTextTableAutomaticLayoutAlgorithm	0
#define NSTextTableFixedLayoutAlgorithm	1

@end

@interface NSTextTable : NSTextBlock
- (int) numberOfColumns;
- (void) setHidesEmptyCells:(BOOL) flag;
- (void) setNumberOfColumns:(unsigned) cols;
@end

@interface NSTextTableBlock : NSTextBlock
- (id) initWithTable:(NSTextTable *) table startingRow:(int) r rowSpan:(int) rs startingColumn:(int) c columnSpan:(int) cs;
@end

@interface NSTextList : NSObject <NSCoding, NSCopying>
- (id) initWithMarkerFormat:(NSString *) fmt options:(unsigned) mask;
- (unsigned) listOptions;
- (NSString *) markerForItemNumber:(int) item;
- (NSString *) markerFormat;
@end

enum
{
    NSTextListPrependEnclosingMarker = 1
};

@interface NSParagraphStyle (NSTextBlock)
- (NSArray *) textBlocks;
- (NSArray *) textLists;
@end

@interface SWKTextTableCell : NSTextAttachmentCell
{
	NSAttributedString *table;
}
@end

@implementation NSParagraphStyle (NSTextBlock)
- (NSArray *) textBlocks; { return nil; }
- (NSArray *) textLists; { return nil; }
@end

@interface NSMutableParagraphStyle (NSTextBlock)
- (void) setTextBlocks:(NSArray *) array;
- (void) setTextLists:(NSArray *) array;
@end

@implementation NSMutableParagraphStyle (NSTextBlock)
- (void) setTextBlocks:(NSArray *) array; { return; }	// ignore
- (void) setTextLists:(NSArray *) array; { return; }	// ignore
@end

@implementation SWKTextTableCell

// when asked to draw, analyse the table blocks and draw a table

@end

#endif
#endif

@implementation DOMNode (Layout)

// FIXME: don't stumble over dates like 2011-08-22 05:02:10

- (void) _processPhoneNumbers:(NSMutableAttributedString *) str;
{
	NSString *raw=[str string];
	NSScanner *sc=[NSScanner scannerWithString:raw];
	[sc setCharactersToBeSkipped:nil];	// don't skip spaces or newlines automatically
	while(![sc isAtEnd])
		{
		unsigned start=[sc scanLocation];	// remember where we did start
		NSRange rng;
		NSDictionary *attr=[str attributesAtIndex:start effectiveRange:&rng];
		if(![attr objectForKey:NSLinkAttributeName])
			{ // we don't yet have a link here
				NSString *number=nil;
				static NSCharacterSet *digits;
				static NSCharacterSet *ignorable;
				if(!digits) digits=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789#*"] retain];
				// FIXME: what about dots? Some countries write a phone number as 12.34.56.78
				// so we should accept dots but only if they separate at least two digits...
				// but don't recognize dates like 29.12.2007
				if(!ignorable) ignorable=[[NSCharacterSet characterSetWithCharactersInString:@" -()\t"] retain];	// NOTE: does not include \n !
				[sc scanString:@"+" intoString:&number];	// looks like a good start (if followed by any digits)
				while(![sc isAtEnd])
					{
					NSString *segment;
					if([sc scanCharactersFromSet:ignorable intoString:NULL])
						continue;	// skip
					if([sc scanCharactersFromSet:digits intoString:&segment])
						{ // found some (more) digits
							if(number)
								number=[number stringByAppendingString:segment];	// collect
							else
								number=segment;		// first segment
							continue;	// skip
						}
					break;	// no digits
					}
				if([number length] > 6)
					{ // there have been enough digits in sequence so that it looks like a phone number
						NSRange srng=NSMakeRange(start, [sc scanLocation]-start);	// string range
						if(srng.length <= rng.length)
							{ // we have uniform attributes (i.e. rng covers srng) else -> ignore
#if 0
								NSLog(@"found telephone number: %@", number);
#endif
								// preprocess number so that it fits into E.164 and DIN 5008 formats
								// how do we handle if someone writes +49 (0) 89 - we must remove the 0?
								if([number hasPrefix:@"00"])
									number=[NSString stringWithFormat:@"+%@", [number substringFromIndex:2]];	// convert to international format
#if 0
								NSLog(@"  -> %@", number);
#endif
								[str addAttribute:NSLinkAttributeName value:[NSString stringWithFormat:@"tel:%@", number] range:srng];	// add link
								continue;
							}
					}
			}
		[sc setScanLocation:start+1];	// skip anything else
		}
}

- (void) _layout:(NSView *) parent;
{
	NIMP;	// no default implementation!
}

@end

@implementation DOMHTMLFrameSetElement (Layout)

- (NSEnumerator *) _htmlFrameSetEnumerator:(NSString *) str totalPixels:(float) pixels;
{ // returns array with fractions of stretch
	NSArray *elements=[str componentsSeparatedByString:@","];
	NSEnumerator *e;
	NSString *element;
	NSMutableArray *r=[NSMutableArray arrayWithCapacity:[elements count]];
	float total=0.0;
	float strech=0.0;
	e=[elements objectEnumerator];
	while((element=[e nextObject]))
		{ // pix or x% or * or n* - first pass to get total width
			float width;
			element=[element stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if([element isEqualToString:@"*"])
				strech+=1.0;	// count number of '*' positions
			else
				{
				width=[element floatValue];
				if([element hasSuffix:@"*"])
					width *= 1.0;	// ??? this factor is only relevant if we mix units, e.g. "160,20%,*,5*"
				else if([element hasSuffix:@"%"])
					width *= 0.01;
				else
					width/=pixels;	// convert absolute dimensions to factor
				if(width > 0.0)
					total+=width;	// accumulate
				}
		}
	if(strech > 0)
		{ // equally distribute stretch
			// FIXME: this fails if we mix stretch and other * notations: "1*,5*,*,3*" - the total is undefined!
		strech=(1.0-total)/strech;	// how much is missing to 100% for each *
		total=1.0;		// 100% total
		}
	if(total == 0.0)
		return nil;
	e=[elements objectEnumerator];
	while((element=[e nextObject]))
		{ // x% or * or n*
			float width;
			element=[element stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if([element isEqualToString:@"*"])
				width=strech;
			else
				{
				width=[element floatValue];
				if([element hasSuffix:@"*"])
					width *= 1.0;
				else if([element hasSuffix:@"%"])
					width *= 0.01;
				else
					width/=pixels;	// absolute dimensions to factor
				}
			[r addObject:[NSNumber numberWithFloat:width/total]];	// fraction of total width
		}
	return [r objectEnumerator];
}

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) dividerIndex;
{
	// go through children
	// chekc if any <frame> (even if nested in sub-<frameset>) has the noresize attribute
	return proposedPosition;
}

- (void) _layout:(NSView *) view;
{ // recursively arrange subviews so that they match children
	NSString *splits;	// "50%,*"
	NSEnumerator *e;	// enumerator
	NSNumber *split;	// current splitting percentage (float)
	DOMNodeList *children=[self childNodes];
	unsigned count=[children length];
	unsigned childIndex=0;
	unsigned subviewIndex=0;
	float position=0.0;
	float total;
	NSRect frame;
	BOOL vertical;
	WebFrame *webFrame=[self webFrame];
	WebView *webView=[webFrame webView];
	DOMCSSStyleDeclaration *style;
	DOMCSSValue *val;
#if 0
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif	
	// FIXME: this may not be very efficient if the style is not cached
	style=[webView computedStyleForElement:self pseudoElement:@""];
	val=[style getPropertyCSSValue:@"x-frameset-orientation"];
	vertical=[[val _toString] isEqualToString:@"vertical"];
	val=[style getPropertyCSSValue:@"x-frameset-elements"];
	splits=[val _toString];	
	if(![view isKindOfClass:[_WebHTMLDocumentFrameSetView class]])
		{ // add/substitute a new _WebHTMLDocumentFrameSetView (subclass of NSSplitView) view of same dimensions
			_WebHTMLDocumentFrameSetView *setView=[[_WebHTMLDocumentFrameSetView alloc] initWithFrame:[view frame]];
			if([[view superview] isKindOfClass:[NSClipView class]])
				[(NSClipView *) [view superview] setDocumentView:setView];			// make the FrameSetView the document view
			else
				[[view superview] replaceSubview:view with:setView];	// replace
			[setView setDelegate:self];	// become the delegate (to control no-resize)
			view=setView;	// use new
			[setView release];
		}
	[(NSSplitView *) view setVertical:vertical];
	for(childIndex=0, subviewIndex=0; childIndex < count; childIndex++)
		{
		DOMHTMLElement *child=(DOMHTMLElement *) [children item:childIndex];
#if 1
		NSLog(@"child=%@", child);
#endif
		if([child isKindOfClass:[DOMHTMLFrameSetElement class]] || [child isKindOfClass:[DOMHTMLFrameElement class]])
			{ // real content
				subviewIndex++;	// one more
				if(subviewIndex > [[view subviews] count])
					{ // we don't have instantiated enough subviews yet - add one
						_WebHTMLDocumentView *childView=[[_WebHTMLDocumentView alloc] initWithFrame:[view frame]];
						[view addSubview:childView];
						[childView release];
					}
			}
		}
	while([[view subviews] count] > subviewIndex)
		[[[view subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];	// we have too many subviews - remove last one
#if 0
	NSLog(@"subviews = %@", [view subviews]);
#endif
	frame=[view frame];
	total=(vertical?frame.size.width:frame.size.height)-[(NSSplitView *) view dividerThickness]*(subviewIndex-1);	// how much room we can distribute
	e=[self _htmlFrameSetEnumerator:splits totalPixels:total];		// comma separated list e.g. "20%,*" or "1*,3*,7*"
	for(childIndex=0, subviewIndex=0; childIndex < count; childIndex++)
		{
		DOMHTMLElement *child=(DOMHTMLElement *) [children item:childIndex];
		if([child isKindOfClass:[DOMHTMLFrameSetElement class]] || [child isKindOfClass:[DOMHTMLFrameElement class]])
			{ // real content
				NSView *childView=[[view subviews] objectAtIndex:subviewIndex];
				[child _layout:childView];	// layout subview - this may replace the original subview!
				childView=[[view subviews] objectAtIndex:subviewIndex];	// fetch the (new) subview to resize as needed
#if 0
				NSLog(@" child = %@ - %@", childView, NSStringFromRect([childView frame]));
#endif
				split=[e nextObject];	// get next splitting info
				if(!split)
					break;	// mismatch in count
				frame=[childView frame];
#if 0
				NSLog(@"  was = %@", NSStringFromRect([childView frame]));
#endif
				if(vertical)
					{ // vertical splitter
						frame.origin.x=position;
						position += frame.size.width=[split floatValue]*total;	// how much of total
					}
				else
					{
					frame.origin.y=position;
					position += frame.size.height=[split floatValue]*total;	// how much of total
					}
				position += [(NSSplitView *) view dividerThickness];	// leave room for divider
				[childView setFrame:frame];	// adjust
#if 0
				NSLog(@"  is = %@ -> %@", NSStringFromRect(frame), NSStringFromRect([childView frame]));
#endif
				subviewIndex++;
			}
		}
	[(NSSplitView *) view adjustSubviews];	// adjust them all
}

@end

@implementation DOMHTMLFrameElement (Layout)

- (void) _layout:(NSView *) view;
{
	NSString *name=[self valueForKey:@"name"];
	NSString *src=[self valueForKey:@"src"];
	WebFrame *webFrame=[self webFrame];
	WebView *webView=[webFrame webView];
	WebFrameView *frameView;
	DOMCSSStyleDeclaration *style;
	DOMCSSValue *val;
#if 0
	NSLog(@"_layout: %@", self);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	// FIXME: this may not be very efficient if the style is not cached
	style=[webView computedStyleForElement:self pseudoElement:@""];
	// FIXME: get name and src also from CSS!
	if(![view isKindOfClass:[WebFrameView class]])
		{ // substitute with a WebFrameView
			frameView=[[WebFrameView alloc] initWithFrame:[view frame]];
			[[view superview] replaceSubview:view with:frameView];	// replace
			view=frameView;	// use new
			[frameView release];
			webFrame=[[WebFrame alloc] initWithName:name
									webFrameView:frameView
										 webView:webView];	// allocate a new WebFrame
			[frameView _setWebFrame:webFrame];	// create and attach a new WebFrame
			[webFrame release];
			[webFrame _setFrameElement:self];	// make a link
			[[self webFrame] _addChildFrame:webFrame];	// make new frame a child of our frame
			if(src)
				[webFrame loadRequest:[NSURLRequest requestWithURL:[self URLWithAttributeString:@"src"]]];
		}
	else
		{
		frameView=(WebFrameView *) view;
		webFrame=[frameView webFrame];		// get the webframe
		}
	[webFrame _setFrameName:name];
	val=[style getPropertyCSSValue:@"x-frame-scrolling"];
	if(val)
		{
		NSString *scrolling=[val _toString];	// YES, auto, ...
		[frameView setAllowsScrolling:NO];
		[frameView setAllowsAutoScrolling:NO];
		if([scrolling caseInsensitiveCompare:@"auto"] == NSOrderedSame)
			{ // enable autoscroll
				[frameView setAllowsScrolling:YES];
				[frameView setAllowsAutoScrolling:YES];
			}
		else if([scrolling isEqualToString:@""] || [scrolling caseInsensitiveCompare:@"yes"] == NSOrderedSame)
			[frameView setAllowsScrolling:YES];
		}
	val=[style getPropertyCSSValue:@"x-frame-resizable"];
	if(val)
		{
		// somehow remember so that the NSSplitView delegate can get the value
		}
	// margins
	[frameView setNeedsDisplay:YES];
}

@end

@implementation DOMHTMLBodyElement (Layout)

- (void) _layout:(NSView *) view;
{
	DOMHTMLDocument *htmlDocument=(DOMHTMLDocument *) [self ownerDocument];
	WebDataSource *source=[htmlDocument _webDataSource];
	NSString *anchor=[[[source response] URL] fragment];
	WebFrame *webFrame=[self webFrame];
	WebView *webView=[webFrame webView];
	WebFrameView *frameView;
	DOMCSSStyleDeclaration *style;
	DOMCSSValue *val;
	NSTextStorage *ts;
	NSScrollView *sc=[view enclosingScrollView];
#if 0
	NSLog(@"%@ _layout: %@", NSStringFromClass(isa), view);
	NSLog(@"attribs: %@", [self _attributes]);
#endif
	if(![view isKindOfClass:[_WebHTMLDocumentView class]])
		{ // add/substitute a new _WebHTMLDocumentView view to our parent (NSClipView)
			view=[[_WebHTMLDocumentView alloc] initWithFrame:(NSRect){ NSZeroPoint, [view frame].size }];	// create a new one with same frame
#if 0
			NSLog(@"replace document view %@ by %@", view, textView);
#endif
			[[[self webFrame] frameView] _setDocumentView:view];	// replace - and add whatever notifications the Scrollview needs
			[view release];
			[(_WebHTMLDocumentView *) view setDrawsBackground:NO];	// default
#if 0
			NSLog(@"textv=%@", view);
			NSLog(@"mask=%02x", [view autoresizingMask]);
			NSLog(@"horiz=%d", [view isHorizontallyResizable]);
			NSLog(@"vert=%d", [view isVerticallyResizable]);
			NSLog(@"webdoc=%@", [view superview]);
			NSLog(@"mask=%02x", [[view superview] autoresizingMask]);
			NSLog(@"clipv=%@", [[view superview] superview]);
			NSLog(@"mask=%02x", [[[view superview] superview] autoresizingMask]);
			NSLog(@"scrollv=%@", [[[view superview] superview] superview]);
			NSLog(@"mask=%02x", [[[[view superview] superview] superview] autoresizingMask]);
			NSLog(@"autohides=%d", [[[[view superview] superview] superview] autohidesScrollers]);
			NSLog(@"horiz=%d", [[[[view superview] superview] superview] hasHorizontalScroller]);
			NSLog(@"vert=%d", [[[[view superview] superview] superview] hasVerticalScroller]);
			NSLog(@"layoutManager=%@", [view layoutManager]);
			NSLog(@"textContainers=%@", [[view layoutManager] textContainers]);
#endif
		}
	ts=[(NSTextView *) view textStorage];
	[ts replaceCharactersInRange:NSMakeRange(0, [ts length]) withString:@""];	// clear current content

	NS_DURING
		[[[(DOMHTMLElement *) self webFrame] webView] _spliceNode:self to:ts parentStyle:nil parentAttributes:nil];
	
	// to correctly handle <pre>:
	// scan through all paragraphs
	// find all non-breaking paras, i.e. those with lineBreakMode == NSLineBreakByClipping
	// determine unlimited width of any such paragraph
	// resize textView to MIN(clipView.width, maxWidth+2*inset)
	// also look for oversized attachments!
	
	// FIXME: we should recognize this element:
	// <meta name = "format-detection" content = "telephone=no">
	// as described at http://developer.apple.com/documentation/AppleApplications/Reference/SafariWebContent/UsingiPhoneApplications/chapter_6_section_3.html
	
		[self _processPhoneNumbers:ts];	// update content
	
	NS_HANDLER
		if(NSRunAlertPanel(@"An internal layout exception occurred\nPlease report to <http://projects.goldelico.com/p/swk/issues>",
						   @"URL: <%@>\nException: %@",
						   @"Continue",
						   @"Abort",
						   nil,
						   [[[[webFrame dataSource] request] URL] absoluteString],
						   localException
						   ) == NSAlertAlternateReturn)
			[localException raise];	// should end any processing
	NS_ENDHANDLER
	
	style=[webView computedStyleForElement:self pseudoElement:@""];

#if 0
	
	val=[style getPropertyCSSValue:@"background-attachment"];
	if(val)
		{
		}
	val=[style getPropertyCSSValue:@"background-position"];
	if(val)
		{
		}			
	val=[style getPropertyCSSValue:@"background-repeat"];
	if(val)
		{
		}
#endif

	val=[style getPropertyCSSValue:@"background-color"];
	if(val)
		{
		// FIXME: make sure the default is "transparent"
		if([[val _toString] isEqualToString:@"transparent"])
			[(_WebHTMLDocumentView *) view setDrawsBackground:NO]; // disable background
		else
			{
			NSColor *color=[val _getNSColorValue];
			if(color)
				{
				[(_WebHTMLDocumentView *) view setBackgroundColor:color];
#if 1	// WORKAROUND
				/* the next line is a workaround for the following problem:
				 If we show HTML text that is longer than the scrollview it has a vertical scroller.
				 Now, if a new page is loaded and the text is shorter and completely fits into the
				 NSScrollView, the scroller is automatically hidden.
				 Due to a bug we still have to fix, the NSTextView is not aware of this
				 before the user resizes the enclosing WebView and NSScrollView.
				 And, the background is only drawn for the not-wide-enough NSTextView.
				 As a workaround, we set the background also for the ScrollView.
				 */
				[sc setBackgroundColor:color];
#endif
				[(_WebHTMLDocumentView *) view setDrawsBackground:YES];
				}
			}
		}
	val=[style getPropertyCSSValue:@"background-image"];
	if(val)
		{
		// FIXME: load the image
		NSImage *img=nil;
		// FIXME: handle background-repeat: we could create tiles sharing the NSImage...
		NSImageView *iv;
		// scan all subviews
		// remove/reuse existing NSImageViews
		iv=[[NSImageView alloc] initWithFrame:[view frame]];
		// attach a NSImageView subview to the textview
		// FIXME: this adds a new subview each time we call _layout!
		[view addSubview:iv];
		[iv release];
		}
	val=[style getPropertyCSSValue:@"x-visited-color"];
	if(val)
		{
		[(_WebHTMLDocumentView *) view setLinkColor:[val _getNSColorValue]];	// change link color
		}
	/*
	 [view setTextContainerInset:NSMakeSize(2.0, 4.0)];	// leave some margin (shouldn't this be defined in the <body> CSS?)
	 */
	[(_WebHTMLDocumentView *) view setDelegate:[self webFrame]];	// should be someone who can handle clicks on links and knows the base URL
	if([anchor length] != 0)
		{ // locate a matching anchor
			unsigned idx, cnt=[ts length];
			for(idx=0; idx < cnt; idx++)
				{
				NSString *attr=[ts attribute:@"DOMHTMLAnchorElementAnchorName" atIndex:idx effectiveRange:NULL];
				if(attr && [attr isEqualToString:anchor])
					break;
				}
			if(idx < cnt)
				[(_WebHTMLDocumentView *) view scrollRangeToVisible:NSMakeRange(idx, 0)];	// jump to anchor
		}
	//	[view setMarkedTextAttributes: ]	// update for visited link color (assuming that we mark visited links)
	[sc tile];
	[sc reflectScrolledClipView:[sc contentView]];	// make scrollers autohide
#if 0	// show view hierarchy
	{
	NSView *parent;
	//	[textView display];
	NSLog(@"view hierarchy");
	NSLog(@"NSWindow=%@", [view window]);
	parent=view;
	while(parent)
		NSLog(@"%p: %@", parent, parent), parent=[parent superview];
	}
#endif	
}

@end

@implementation _WebHTMLDocumentView

// NSView overrides

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{ // set other attributes (selectable, editable etc.)
		[self setEditable:NO];
		[self setSelectable:YES];
		[self setVerticallyResizable:YES];
		[self setHorizontallyResizable:NO];	// for proper line breaks
		[self setTextContainerInset:NSMakeSize(2.0, 4.0)];	// leave some margin (should this be defined in the <body> CSS?
		[[self textContainer] setWidthTracksTextView:YES];
		[[self textContainer] setHeightTracksTextView:NO];
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		// attach a defalt context menu (Back, Forward etc.) for HTML pages
		}
	return self;
}

- (void) drawRect:(NSRect) rect;
{
#if 0
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
#endif
	if(_needsLayout)
		[self layout];
	if(_backgroundImage)
		; // draw
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
#if 0
	NSLog(@"dataSourceUpdated: %@", source);
#endif
#if 0	// show view hierarchy
	while(self)
		NSLog(@"%p: %@", self, self), self=(_WebHTMLDocumentView *) [self superview];
#endif	
}

- (void) layout;
{ // do the layout of subviews - NOTE: this is called from within drawRect!
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[_dataSource webFrame] DOMDocument] firstChild];
	DOMHTMLElement *body=(DOMHTMLElement *) [html lastChild];	// either <body> or could be a <frameset>
#if 0
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[body performSelector:@selector(_layout:) withObject:self afterDelay:0.0];	// process the <body> tag (could also be a <frameset>) from the runloop
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
#if 0
	NSLog(@"setNeedsLayout");
#endif
	if(_needsLayout == flag)
		return;	// we already know
	_needsLayout=flag;
	if(flag)
		[self setNeedsDisplay:YES];	// trigger a drawRect
}

- (void) viewDidMoveToHostWindow;
{
	NIMP;
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
	NIMP;
}

- (void) setLinkColor:(NSColor *) color
{
#if 0
	NSLog(@"setLinkColor: %@", color);
#endif
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_3 < MAC_OS_X_VERSION_MAX_ALLOWED
	if(color)
		[self setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:color, NSUnderlineColorAttributeName,
			[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
			[NSCursor pointingHandCursor], NSCursorAttributeName,
			nil]];		// define link color
	else
		[self setLinkTextAttributes:nil];	// default
#endif
}

- (void) setBackgroundImage:(NSImage *) img
{
	ASSIGN(_backgroundImage, img);
	[self setNeedsDisplay:YES];
}

// @protocol WebDocumentText

- (NSAttributedString *) attributedString; { return [self textStorage]; }
- (void) deselectAll; { NIMP; }
- (void) selectAll; { NIMP; }
- (NSAttributedString *) selectedAttributedString;  { return NIMP; }
- (NSString *) selectedString;  { return [[self selectedAttributedString] string]; }
- (NSString *) string;  { return [[self attributedString] string]; }
- (BOOL) supportsTextEncoding; { return NO; }	// CHECKME: or YES???

@end

@implementation _WebHTMLDocumentFrameSetView

// NSSplitView overrides

- (id) initWithFrame:(NSRect) rect;
{
	if((self=[super initWithFrame:rect]))
		{
		[self setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		[self setIsPaneSplitter:NO];
		}
	return self;
}

- (float) dividerThickness
{
	return 6.0;
}

- (void) drawDividerInRect:(NSRect) aRect
{
	// draw splitter background
	// if this splitter is moveable:
	[super drawDividerInRect:aRect];
}

- (void) drawRect:(NSRect) rect;
{
#if 0
	NSLog(@"%@ drawRect:%@", self, NSStringFromRect(rect));
#endif
	if(_needsLayout)
		[self layout];
	[[NSColor lightGrayColor] set];
	NSRectFill(rect);	// draw a splitter background
	[super drawRect:rect];
}

// @protocol WebDocumentView

- (void) dataSourceUpdated:(WebDataSource *) source;
{
}

- (void) layout;
{ // do the layout especially of subviews
	DOMHTMLHtmlElement *html=(DOMHTMLHtmlElement *) [[[[_dataSource webFrame] DOMDocument] firstChild] firstChild];
	DOMHTMLElement *frameset=(DOMHTMLElement *) [html lastChild];	// should be a <frameset>
#if 0
	NSLog(@"%@ %@", NSStringFromClass(isa), NSStringFromSelector(_cmd));
#endif
	_needsLayout=NO;
	[frameset _layout:self];	// process the <frameset> tag
}

- (void) setDataSource:(WebDataSource *) source;
{
	_dataSource=source;
}

- (void) setNeedsLayout:(BOOL) flag;
{
	_needsLayout=flag;
	[self setNeedsDisplay:YES];
}

- (void) viewDidMoveToHostWindow;
{
}

- (void) viewWillMoveToHostWindow:(NSWindow *) win;
{
}

// @protocol WebDocumentText

- (NSAttributedString *) attributedString;
{ // collect from all subviews...
	return NIMP;
}

- (void) deselectAll; { NIMP; }
- (void) selectAll; { NIMP; }
- (NSAttributedString *) selectedAttributedString;  { return NIMP; }
- (NSString *) selectedString;  { return [[self selectedAttributedString] string]; }
- (NSString *) string;  { return [[self attributedString] string]; }
- (BOOL) supportsTextEncoding; { return NO; }	// CHECKME: or YES???

@end

@implementation NSText (NSTextAttachment)

- (NSText *) currentEditor;
{
	return nil;	// someone calls that...
}

@end

@implementation NSTextAttachmentCell (NSTextAttachment)

+ (NSTextAttachment *) textAttachmentWithCellOfClass:(Class) class;
{
	NSTextAttachment *attachment=[[[NSTextAttachment alloc] initWithFileWrapper:nil] autorelease];
	[attachment setAttachmentCell:[[[class alloc] init] autorelease]];
#if 0
	NSLog(@"attachment cell=%@", [attachment attachmentCell]);
#endif
	return attachment;
}

@end

// abstract extensions for NSCell so that we can use *any* subclass as an attachment cell - unless overridden explicity in a subclass

@implementation NSCell (NSTextAttachment)

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { return; }
- (NSTextAttachment *) attachment; { return nil; }

- (NSRect) cellFrameForTextContainer:(NSTextContainer *) container
								proposedLineFragment:(NSRect) fragment
											 glyphPosition:(NSPoint) pos
											characterIndex:(unsigned) index;
{
	return (NSRect){ NSZeroPoint, [self cellSize] };
}

- (void) drawWithFrame:(NSRect)cellFrame
								inView:(NSView *)controlView
				characterIndex:(unsigned) index;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame
								inView:(NSView *)controlView
				characterIndex:(unsigned) index
				 layoutManager:(NSLayoutManager *) manager;
{
	[self drawWithFrame:cellFrame inView:controlView];
}

- (BOOL) trackMouse:(NSEvent *)event 
			 inRect:(NSRect)cellFrame 
			 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
	   untilMouseUp:(BOOL)flag;
{
	BOOL done=NO;
//	NSLog(@"mouse in view %@", NSStringFromPoint([controlTextView convertPoint:[event locationInWindow] fromView:nil]));
//	NSLog(@"trackMouse: %@ inRect: %@ ofView: %@ atCharacterIndex: %u untilOp: %d", event, NSStringFromRect(cellFrame), controlTextView, index, flag);
	while([event type] != NSLeftMouseUp)	// loop outside until mouse goes up 
		{
			NSPoint p = [controlTextView convertPoint:[event locationInWindow] fromView:nil];
			if(NSMouseInRect(p, cellFrame, [controlTextView isFlipped]))
				{ // highlight cell
					[self setHighlighted:YES];	
					[controlTextView setNeedsDisplay:YES];
					done=[self trackMouse:event
									inRect:cellFrame
									ofView:controlTextView
							 untilMouseUp:NO];
					[self setHighlighted:NO];	
					[controlTextView setNeedsDisplay:YES];
					if(done)
						break;
				}
			if(!flag)
				break;	// don't wait until mouse is up, i.e. exit if we leave the rect
			event = [NSApp nextEventMatchingMask:NSLeftMouseDownMask | NSLeftMouseUpMask | NSMouseMovedMask | NSLeftMouseDraggedMask
									   untilDate:[NSDate distantFuture]						// get next event
										  inMode:NSEventTrackingRunLoopMode 
										 dequeue:YES];			
  		}
	return done;
}

- (BOOL) wantsToTrackMouse;
{
	return YES;
}

- (BOOL) wantsToTrackMouseForEvent:(NSEvent *) event
							inRect:(NSRect) rect
							ofView:(NSView *) controlView
				  atCharacterIndex:(unsigned) index;
{ // this could make tracking only on parts of the cell or depend on the attributes of the character
	return [self wantsToTrackMouse];
}

@end

@implementation NSActionCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -30.0); }

@end

@implementation NSButtonCell (NSTextAttachment)

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -20.0); }

// add missing methods

@end

@implementation NSTextFieldCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }

- (BOOL) trackMouse:(NSEvent *)event 
						 inRect:(NSRect)cellFrame 
						 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
			 untilMouseUp:(BOOL)flag;
{ // click into text field
	if(![self isEditable])
		return NO;
	if([[controlTextView window] makeFirstResponder:controlTextView])
			{
				[self editWithFrame:cellFrame
										 inView:controlTextView
										 editor:[self setUpFieldEditorAttributes:[[controlTextView window] fieldEditor:YES forObject:controlTextView]]
									 delegate:[self target]
											event:event];
				return YES;	// field editor should now be in editing mode
			}
	return NO;
}

// add missing methods

@end

@interface NSInputTextFieldCell : NSTextFieldCell
{
	int lines;
	int cols;
}

@end

@implementation NSInputTextFieldCell

- (void) textDidEndEditing:(NSNotification *)aNotification
{
	NSNumber *code = [[aNotification userInfo] objectForKey:@"NSTextMovement"];
	[self setStringValue:[[aNotification object] string]];	// copy value to cell
	[self endEditing:[aNotification object]];	
	switch([code intValue])
		{
			case NSReturnTextMovement:
				[NSApp sendAction:[self action] to:[self target] from:self];
				break;
			case NSTabTextMovement:
				break;
			case NSBacktabTextMovement:
				break;
			case NSIllegalTextMovement:
				break;
		}
}

@end

@implementation NSPopUpButtonCell (NSTextAttachment)

- (NSSize) cellSize; { return NSMakeSize(200.0, 22.0); }		// should depend on font&SIZE parameter

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, -10.0); }

	// add missing methods

@end

@implementation NSViewAttachmentCell

// show a generic view as an attachment cell (e.g. an WebFrameView for <iframe>)
// or an embedded editable NSTextView for <textarea>

// is the view a subview of our control view???

- (void) dealloc;
{
	[view release];
	[super dealloc];
}

- (void) setView:(NSView *) v; { ASSIGN(view, v); }
- (NSView *) view; { return view; }

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { attachment=anAttachment; }
- (NSTextAttachment *) attachment; { return attachment; }

- (NSPoint) cellBaselineOffset; { return view?[view frame].origin:NSZeroPoint; }
- (NSSize) cellSize; { return view?[view frame].size:NSZeroSize; }

- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{
	[view setNeedsDisplayInRect:cellFrame];
	[view drawRect:cellFrame];
}

- (BOOL) trackMouse:(NSEvent *)event 
						 inRect:(NSRect)cellFrame 
						 ofView:(NSView *)controlTextView 
   atCharacterIndex:(unsigned) index
			 untilMouseUp:(BOOL)flag;
{ // click into text field
	if(![[controlTextView window] makeFirstResponder:view])
		return NO;
	// check for resize
	[view mouseDown:event];	// tracking loop of embedded view
	return YES;
}

@end

@implementation NSHRAttachmentCell

- (id)init
{
    if((self=[super initTextCell:@"<hr>"]))
		{
		_shaded = NO;
		_size = 2;
		_width = 100;
		_widthIsPercent = YES;
		}
    return self;
}

- (void) setAttachment:(NSTextAttachment *) anAttachment;	 { attachment=anAttachment; }
- (NSTextAttachment *) attachment; { return attachment; }

- (NSPoint) cellBaselineOffset; { return NSMakePoint(0.0, 1.0); }

- (NSRect) cellFrameForTextContainer:(NSTextContainer *) container
				proposedLineFragment:(NSRect) fragment
					   glyphPosition:(NSPoint) pos
					  characterIndex:(unsigned) index;
{ // make a text attachment cell that eats up the remaining space up to the end of the current fragment (minus line padding)
	fragment.size.width-=pos.x+2*[container lineFragmentPadding];	// should be the same as the containerInset.width
	fragment.size.height=5.0;
	fragment.origin=NSZeroPoint;	// it appears that we must return relative coordinates
	return fragment;
}

- (void) setShaded:(BOOL)shaded
{
    _shaded = shaded;
}

- (void) setSize:(int)size
{
    _size = size;
}

- (void) setWidth:(int)width
{
    _width = width;
}

- (void) setIfWidthIsPercent:(BOOL)flag
{
    _widthIsPercent = flag;
}
    
- (void) drawWithFrame:(NSRect)cellFrame
				inView:(NSView *)controlView
{ // draw a horizontal line
	NSPoint upLeft;
	NSPoint lowRight;
	NSRect bar;
	NSBezierPath *p;
	NSBezierPath *shadow;
	float lineWidth;
		
	lineWidth = _size;
	
	upLeft = NSMakePoint(NSMinX(cellFrame)+4, NSMidY(cellFrame)- lineWidth/2);
	lowRight = NSMakePoint(NSMaxX(cellFrame)-4, NSMidY(cellFrame)+lineWidth/2);
	
	if (_shaded)
	{
		lowRight = NSMakePoint(lowRight.x-1, lowRight.y-1);
		bar = NSMakeRect(upLeft.x, upLeft.y, lowRight.x-upLeft.x, lowRight.y-upLeft.y);
	
		p = [NSBezierPath bezierPath];
		[p setLineWidth:1.0];
		[p appendBezierPathWithRect: bar];
		[[NSColor blackColor] set];
		[p fill];
	
		shadow = [NSBezierPath bezierPath];
		[shadow moveToPoint:NSMakePoint(upLeft.x+1, lowRight.y+1)];
		[shadow lineToPoint:NSMakePoint(lowRight.x, lowRight.y+1)];
		[shadow lineToPoint:NSMakePoint(lowRight.x, upLeft.y)];
		[[NSColor lightGrayColor] set];
		[shadow stroke];
	}
	else
	{
		bar = NSMakeRect(upLeft.x, upLeft.y, lowRight.x-upLeft.x, lowRight.y-upLeft.y);
	
		p = [NSBezierPath bezierPath];
		[p setLineWidth:1.0];
		[p appendBezierPathWithRect: bar];
		[[NSColor blackColor] set];
		[p stroke];
	}
#if 0
	[[NSColor redColor] set];
	NSRectFill(cellFrame);
#endif

}

- (BOOL) wantsToTrackMouse; { return NO; }

@end

@implementation WebView (NSAttributedString)

// FIXME: inherit bei Attributen verarbeiten und Wert aus parentAttribs Ÿbernehmen
// unklar: was hei§t 'inherit' bei pseudoElements?

- (void) _spliceNode:(DOMNode *) node to:(NSMutableAttributedString *) str parentStyle:(DOMCSSStyleDeclaration *) parent parentAttributes:(NSDictionary *) parentAttributes;
{ // recursively splice this node and any subnodes, taking end of last fragment into account
	unsigned i, cnt;
	DOMCSSValue *val;
	NSString *sval;
	WebPreferences *preferences=[self preferences];
	NSMutableDictionary *attributes;
	DOMCSSStyleDeclaration *style;
	DOMNodeList *childNodes;
	NSString *display;
	NSString *visibility;
	BOOL lastIsInline;
	BOOL isInline;
	NSTextAttachment *attachment;
	NSString *string;
	if(![node isKindOfClass:[DOMElement class]])
		{ // inherit all style for DOMText nodes
			style=parent;					// inherit style
			attributes=(NSMutableDictionary *) parentAttributes;	// inherit attributes
			childNodes=nil;					// no children
		}
	else
		{ // calculate/apply new style
			// FIXME: make pseudoElement depend on state, e.g. :hover, :link etc.
			style=[self _styleForElement:node pseudoElement:@"" parentStyle:parent];
			attributes=[NSMutableDictionary dictionaryWithCapacity:10];	// we will create a set of new ones
			childNodes=[node childNodes];
		}
	display=[[style getPropertyCSSValue:@"display"] _toString];
	visibility=[[style getPropertyCSSValue:@"visibility"] _toString];
	// FIXME: handle "display: run-in"
	lastIsInline=([str length] != 0 && ![[str string] hasSuffix:@"\n"]);	// did not end with block
	isInline=style == parent || !display || [display isEqualToString:@"inline"];	// plain text counts as inline
	
	// hm. _range is only known for DOMHTMLElements!
	//	_range.location=[str length];
	//	_range.length=0;
	
	if([visibility isEqualToString:@"collapse"])
		return;
	if([display isEqualToString:@"none"])
		return;

	// FIXME: move this after the end of the style calculation where we would handle the children
//	[[[node webFrame] frameView] documentView]
	string=[node _string];	// may be nil
	
	// FIXME: handle default values!
	// handle (ignore) incompatible/unknown values, i.e. specifying a list as the font size
	
	if(childNodes && ([childNodes length] > 0 || [string length] > 0))
		{ // calculate (new) string attributes to apply and pass down to children
			NSMutableParagraphStyle *p=[[parentAttributes objectForKey:NSParagraphStyleAttributeName] mutableCopy];	// start with inherited paragraph style
			NSFont *f=[parentAttributes objectForKey:NSFontAttributeName];	// start with inherited font
			NSFont *ff;	// temporary converted font
			if(!p) p=[[[NSMutableParagraphStyle alloc] init] autorelease];	// start with default paragraph style
			if(!f) f=[NSFont systemFontOfSize:0.0];	// default system font (should be overridden by <body> in default CSS)
			val=[style getPropertyCSSValue:@"font-family"];
			if(val)
				{ // scan through all fonts defined by font-family until we find one that exists and provides the font
					NSEnumerator *e=[[val _toStringArray] objectEnumerator];	// get as string array
					NSString *fname;
					while((fname=[e nextObject]))
						{ // modify font family
							if([fname isEqualToString:@"sans-serif"])
								fname=[preferences sansSerifFontFamily];
							else if([fname isEqualToString:@"serif"])
								fname=[preferences serifFontFamily];
							else if([fname isEqualToString:@"monospace"])
								fname=[preferences fixedFontFamily];
							else if([fname isEqualToString:@"cursive"])
								fname=[preferences cursiveFontFamily];
							else if([fname isEqualToString:@"fantasy"])
								fname=[preferences fantasyFontFamily];
							else if([fname isEqualToString:@"default"])
								fname=[preferences standardFontFamily];
							if(fname)
								{
								ff=[[NSFontManager sharedFontManager] fontWithFamily:fname traits:0 weight:5 size:12.0];
								if(ff)
									{ // first matching font found!
									f=ff;
									break;									
									}
								}
						}
				}
			val=[style getPropertyCSSValue:@"font-size"];
			if(val)
				{
				float sz;
				float def=[f isFixedPitch]?[preferences defaultFixedFontSize]:[preferences defaultFontSize];
				sz=[[parentAttributes objectForKey:NSFontAttributeName] pointSize]/[self textSizeMultiplier];	// inherited size
				if([(DOMCSSPrimitiveValue *) val primitiveType] == DOM_CSS_IDENT || [(DOMCSSPrimitiveValue *) val primitiveType] == DOM_CSS_STRING)
					{
					sval=[val _toString];
					if([sval isEqualToString:@"smaller"])
						sz/=1.2;
					else if([sval isEqualToString:@"larger"])
						sz*=1.2;
					else if([sval isEqualToString:@"medium"])
						sz=def;
					else if([sval isEqualToString:@"unknown"])
						sz=def;
					else if([sval isEqualToString:@"large"])
						sz=14.0/12*def;
					else if([sval isEqualToString:@"x-large"])
						sz=18.0/12*def;
					else if([sval isEqualToString:@"xx-large"])
						sz=24.0/12*def;
					else if([sval isEqualToString:@"small"])
						sz=10.0/12*def;
					else if([sval isEqualToString:@"x-small"])
						sz=8.0*12/def;
					else if([sval isEqualToString:@"xx-small"])
						sz=6.0/12*def;
					else if([sval hasPrefix:@"+"])
						{ // <font size=+3>
							sz*=pow(1.2, [[sval substringFromIndex:1] floatValue]);
						}
					else if([sval hasPrefix:@"-"])
						{ // <font size=-3>
							sz*=pow(1.2, [sval floatValue]);
						}
					else if([sval floatValue])
						{ // <font size=3>
						float expo=[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_NUMBER];
						if(expo < 1.0) expo=1.0;
						if(expo > 7.0) expo=7.0;
						sz=def*pow(1.2, expo-4.0);
						}
					if(sz < [preferences minimumLogicalFontSize])
						sz=[preferences minimumLogicalFontSize];
					}
				else
					{
					sz=[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:sz andFont:[parentAttributes objectForKey:NSFontAttributeName]];
					// for relative specs:	if(sz < [preferences minimumLogicalFontSize])
					//							sz=[preferences minimumLogicalFontSize];
					}
				if(sz < [preferences minimumFontSize])
					sz=[preferences minimumFontSize];
				ff=[[NSFontManager sharedFontManager] convertFont:f toSize:sz*[self textSizeMultiplier]];	// try to convert
				if(ff) f=ff;
				}
			val=[style getPropertyCSSValue:@"font-style"];
			if(val)
				{
				sval=[val _toString];
				if([sval isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSItalicFontMask];
				else if([sval isEqualToString:@"italic"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSItalicFontMask];
				else if([sval isEqualToString:@"oblique"])
					;
				if(ff) f=ff;
				}
			val=[style getPropertyCSSValue:@"font-weight"];
			if(val)
				{
				sval=[val _toString];
				if([sval isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSBoldFontMask];
				else if([sval isEqualToString:@"bold"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSBoldFontMask];
				else if([sval isEqualToString:@"bolder"])
					ff=[[NSFontManager sharedFontManager] convertWeight:YES ofFont:f];
				else if([sval isEqualToString:@"lighter"])
					ff=[[NSFontManager sharedFontManager] convertWeight:NO ofFont:f];
				// handle numeric values (how? we may have to loop over convertWeight until we get close enough...)
				// - (NSFont *)fontWithFamily:[f family] traits:[f traits] weight:15*weight/10 size:[f size]
				if(ff) f=ff;
				}
			val=[style getPropertyCSSValue:@"font-variant"];
			if(val)
				{
				sval=[val _toString];
				if([sval isEqualToString:@"normal"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toNotHaveTrait:NSSmallCapsFontMask];
				else if([sval isEqualToString:@"small-caps"])
					ff=[[NSFontManager sharedFontManager] convertFont:f toHaveTrait:NSSmallCapsFontMask];
				if(ff) f=ff;
				}
			[attributes setObject:f forKey:NSFontAttributeName];
			val=[style getPropertyCSSValue:@"text-decoration"];
			if(val)
				{ // set underline, overline, strikethrough - try to blink
					NSEnumerator *e=[[val _toStringArray] objectEnumerator];
					NSString *deco;
					while((deco=[e nextObject]))
						{
						if([deco isEqualToString:@"underline"])
							{ // make underlined
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
							[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
							[attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
#endif					
							}
						else if([deco isEqualToString:@"overline"])
							;	// FIXME: not available as NSAttributedString attribute
						else if([deco isEqualToString:@"line-through"])
							{ // make strike-through
#if defined(__mySTEP__) || MAC_OS_X_VERSION_10_2 < MAC_OS_X_VERSION_MAX_ALLOWED
							[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
#else	// MacOS X < 10.3 and GNUstep
							// [attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSStrikethroughStyleAttributeName];
#endif
							}
						}
				}
			val=[style getPropertyCSSValue:@"color"];
			if(val)
				{
				NSColor *color=[val _getNSColorValue];
				if(color)
					[attributes setObject:color forKey:NSForegroundColorAttributeName];
				}
			val=[style getPropertyCSSValue:@"cursor"];
			if(val)
				{
				NSCursor *cursor=nil;
				sval=[val _toString];
				if([sval isEqualToString:@"auto"])
					cursor=[NSCursor arrowCursor];
				else if([sval isEqualToString:@"default"])
					cursor=[NSCursor arrowCursor];
				else if([sval isEqualToString:@"pointer"])
					cursor=[NSCursor pointingHandCursor];
				else if([sval isEqualToString:@"crosshair"])
					cursor=[NSCursor crosshairCursor];
				// FIXME: decode more cursor names
				if(cursor)
					[attributes setObject:cursor forKey:NSCursorAttributeName];
				}
			val=[style getPropertyCSSValue:@"x-link"];
			if(val)
				{
				sval=[val _toString];
				[attributes setObject:sval forKey:NSLinkAttributeName];	// set the link (as a string)
				}
			val=[style getPropertyCSSValue:@"x-tooltip"];
			if(val)
				{
				sval=[val _toString];
				[attributes setObject:sval forKey:NSToolTipAttributeName];	// set the tooltip string
				}
			val=[style getPropertyCSSValue:@"x-target-window"];
			if(val)
				{
				sval=[val _toString];
				[attributes setObject:sval forKey:DOMHTMLAnchorElementTargetWindow];	// set the target window name string
				}
			val=[style getPropertyCSSValue:@"x-anchor"];
			if(val)
				{
				sval=[val _toString];
				[attributes setObject:sval forKey:DOMHTMLAnchorElementAnchorName];	// set the anchor
				}
			/* background */
#if NOT_IMPLEMENTED
			// should we really implement this here?
			val=[style getPropertyCSSValue:@"background-attachment"];
			if(val)
				{
				}
			val=[style getPropertyCSSValue:@"background-position"];
			if(val)
				{
				}			
			val=[style getPropertyCSSValue:@"background-repeat"];
			if(val)
				{
				}
			val=[style getPropertyCSSValue:@"background-color"];
			if(val)
				{
				// FIXME: make sure the default is "transparent"
				if([[val _toString] isEqualToString:@"transparent"])
					; // disable background
				
				// access the NSTextView used to display the attributed string
				// and set [view setBackgroundColor:]
				}
			val=[style getPropertyCSSValue:@"background-image"];
			if(val)
				{
				// attach a NSImageView subview to the textview
				}
#endif
			/* paragraph style */
			val=[style getPropertyCSSValue:@"text-align"];
			if(val)
				{
				sval=[val _toString];
				if([sval isEqualToString:@"left"])
					[p setAlignment:NSLeftTextAlignment];
				else if([sval isEqualToString:@"center"])
					[p setAlignment:NSCenterTextAlignment];
				else if([sval isEqualToString:@"right"])
					[p setAlignment:NSRightTextAlignment];
				else if([sval isEqualToString:@"justify"])
					[p setAlignment:NSJustifiedTextAlignment];
				// if([align isEqualToString:@"char"])
				//    [p setAlignment:NSNaturalTextAlignment];
				}
			val=[style getPropertyCSSValue:@"vertical-align"];
			if(val)
				{
				sval=[val _toString];
				if([sval isEqualToString:@"super"])
					[attributes setObject:[NSNumber numberWithInt:1] forKey:NSSuperscriptAttributeName];
				else if([sval isEqualToString:@"sub"])
					[attributes setObject:[NSNumber numberWithInt:-1] forKey:NSSuperscriptAttributeName];
				else if([sval isEqualToString:@"top"])
					; // modify table cell if possible
				else if([sval isEqualToString:@"middle"])
					; // modify table cell if possible
				else if([sval isEqualToString:@"bottom"])
					; // modify table cell if possible
				}
			val=[style getPropertyCSSValue:@"margin-left"];
			if(val)
				{
				[p setFirstLineHeadIndent:[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:[p firstLineHeadIndent] andFont:[attributes objectForKey:NSFontAttributeName]]];
				}
			val=[style getPropertyCSSValue:@"margin-left"];
			if(val)
				{
				[p setHeadIndent:[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:[p headIndent] andFont:[attributes objectForKey:NSFontAttributeName]]];
				}
			// setHyphenationFactor:
			// setLineBreakMode: -- does this depend on white-space == pre?
			// setTighteningFactorForTruncation:
			// setLineHeightMultiple:
			val=[style getPropertyCSSValue:@"line-height"];
			if(val)
				{
				// check for simple numerical value -> factor instead of 100%
				float s=[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:[p lineSpacing]+[f ascender]+[f descender] andFont:[attributes objectForKey:NSFontAttributeName]];
				s-=[f ascender]+[f descender];	// paragraph style does not define a line-height but a spacing
				if(s < 0.0) s=0.0;
				[p setLineSpacing:s];
				}
			// setMaximumLineHeight:
			// setMinimumLineHeight:
			val=[style getPropertyCSSValue:@"margin-bottom"];
			if(val)
				{
				[p setParagraphSpacing:[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:[p paragraphSpacing] andFont:[attributes objectForKey:NSFontAttributeName]]];
				}
			val=[style getPropertyCSSValue:@"margin-top"];
			if(val)
				{
				[p setParagraphSpacingBefore:[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:[p paragraphSpacingBefore] andFont:[attributes objectForKey:NSFontAttributeName]]];
				}
			val=[style getPropertyCSSValue:@"margin-right"];
			if(val)
				{
				// FIXME: % is relative to enclosing block!
				[p setTailIndent:-[(DOMCSSPrimitiveValue *) val getFloatValue:DOM_CSS_PT relativeTo100Percent:-[p tailIndent] andFont:[attributes objectForKey:NSFontAttributeName]]];	// positive tailIndent means total line width
				}
			val=[style getPropertyCSSValue:@"direction"];
			if(val)
				{		
					sval=[val _toString];
					if([sval isEqualToString:@"ltr"])
						[p setBaseWritingDirection:NSWritingDirectionLeftToRight];
					else if([sval isEqualToString:@"rtl"])
						[p setBaseWritingDirection:NSWritingDirectionRightToLeft];
					// else NSWritingDirectionNatural?
				}
#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED
			val=[style getPropertyCSSValue:@"x-header-level"];
			if(val)
				{
				[p setHeaderLevel:[[val _toString] intValue]];	// if someone wants to convert the attributed string back to HTML...					
				}
#endif
			[attributes setObject:p forKey:NSParagraphStyleAttributeName];
		}
	/* text modification */
	val=[style getPropertyCSSValue:@"white-space"];
	if(val)
		{ // must this be defined!? What is the defalult?
			BOOL nowrap=NO;
			BOOL nobrk=NO;
			BOOL trim=NO;
			NSMutableString *s;
			sval=[val _toString];
			if([sval isEqualToString:@"normal"])
				trim=YES, nobrk=YES;
			else if([sval isEqualToString:@"nowrap"])
				trim=YES, nobrk=YES, nowrap=YES;
			else if([sval isEqualToString:@"pre"])
				nowrap=YES;
			else if([sval isEqualToString:@"pre-wrap"])
				nobrk=YES, nowrap=YES;
			else if([sval isEqualToString:@"pre-line"])
				trim=YES, nowrap=YES;
			s=[[string mutableCopy] autorelease];

/* we have no access to p here!
			if(nowrap)
				[p setLineBreakMode:NSLineBreakByClipping];
*/
			if(nobrk)
				{ // don't break where html says
					[s replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
					[s replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space
					[s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [s length])];	// convert to space				
				}
			if(trim)
				{ // trim multiple spaces
#if 1	// QUESTIONABLE_OPTIMIZATION
					while([s replaceOccurrencesOfString:@"        " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert long space sequences into single one
						;
#endif
					while([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [s length])])	// convert double spaces into single one
						;	// trim multiple spaces to single ones as long as we find them
					if([s hasPrefix:@" "])
						{ // new fragment starts with a space
							NSString *ss=[str string];	// previous string
							if([ss length] == 0 || [ss hasSuffix:@"\n"] || [ss hasSuffix:@" "])
								s=(NSMutableString *) [s substringFromIndex:1];	// strip off leading spaces if last fragment indicates that						
						}
				}
			string=s;
		}
	val=[style getPropertyCSSValue:@"text-transform"]; 
	if(val)
		{
		sval=[val _toString];
		if([sval isEqualToString:@"uppercase"])
			string=[string uppercaseString];
		else if([sval isEqualToString:@"lowercase"])
			string=[string lowercaseString];
		else if([sval isEqualToString:@"capitalize"])
			string=[string capitalizedString];
		else if([sval isEqualToString:@"password"])
			string=[@"" stringByPaddingToLength:[string length] withString:@"*" startingAtIndex:0];
		}
	val=[style getPropertyCSSValue:@"quotes"];
	if(val)
		{
		sval=[val _toString];
		// handle "quotes: "
		}
	if([visibility isEqualToString:@"hidden"])
		{
		// replace by string with spaces of same length
		}
	if(lastIsInline && !isInline)
		{ // we need to close the last inline segment and prefix new block mode segment
			if([[str string] hasSuffix:@" "])
				[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@"\n"];	// replace if it did end with a space
			else
				[str replaceCharactersInRange:NSMakeRange([str length], 0) withString:@"\n"];	// this operation inherits attributes of the previous section
		}
	// to implement the :before pseudo element, we must extract the attribute/style calculation to a separate method
	// and use style=[self _styleForElement:node pseudoElement:@"before" parentStyle:parent];
	val=[style getPropertyCSSValue:@"x-before"];
	if(val)
		{ // special case to implement <br>
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:[val _toString] attributes:attributes] autorelease]];
		}
	if([display isEqualToString:@"inline-block"])
		{ // create an inline-block
			NSMutableAttributedString *value=[[[NSMutableAttributedString alloc] init] autorelease];
			NSCell *cell;
			childNodes=[node childNodes];
			for(i=0; i<[childNodes length]; i++)
				{ // add child nodes
					// NSLog(@"splice child %@", [_childNodes item:i]);
					[self _spliceNode:[childNodes item:i] to:str parentStyle:style parentAttributes:attributes];
				}
			[(DOMElement *) node _processPhoneNumbers:value];	// update conten
			// allow cell type to be modified
			attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSCell class]];
			string=nil;
			childNodes=nil;	// already processed
			cell=(NSCell *) [attachment attachmentCell];	// get the real cell
			[cell setAttributedStringValue:value];	// formatted by contents between <buton> and </button>
			// set other attributes like background, cellSize etc.
#if 0
			NSLog(@"  cell: %@", cell);
#endif
		}
	else
		attachment=[node _attachmentForStyle:style];	// may be nil
	if(attachment)
		{ // add attribute attachment (if available)
			NSMutableAttributedString *astr=(NSMutableAttributedString *)[NSMutableAttributedString attributedStringWithAttachment:attachment];
			[astr addAttributes:attributes range:NSMakeRange(0, [astr length])];
			[str appendAttributedString:astr];
		}
	if([string length] > 0)	
		{ // add attributed string
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease]];
		}
	for(i=0; i<[childNodes length]; i++)
		{ // add child nodes
			// NSLog(@"splice child %@", [_childNodes item:i]);
			[self _spliceNode:[childNodes item:i] to:str parentStyle:style parentAttributes:attributes];
		}
	val=[style getPropertyCSSValue:@"x-after"];
	if(val)
		{ // special case
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:[val _toString] attributes:attributes] autorelease]];
		}
	if(!isInline)
		{ // close our block
			if([[str string] hasSuffix:@" "])
				[str replaceCharactersInRange:NSMakeRange([str length]-1, 1) withString:@""];	// strip off any trailing space
			[str appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attributes] autorelease]];	// close this block
		}
	//	_range.length=[str length]-_range.location;	// store resulting range
	//	[_style release];
	//	_style=nil;
}


@end
