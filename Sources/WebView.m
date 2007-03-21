/* simplewebkit
   WebView.m
   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Dr. H. Nikolaus Schaller

   This file is part of the GNUstep Database Library.

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
#import <WebKit/WebView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebBackForwardList.h>

// default document representations we understand
#import "WebHTMLDocumentRepresentation.h"
#import "WebHTMLDocumentView.h"
#import "WebImageDocumentRepresentation.h"
#import "WebPDFDocumentRepresentation.h"
#import "WebXMLDocumentRepresentation.h"

@implementation WebView

static NSMutableDictionary *_viewClasses;
static NSMutableDictionary *_representationClasses;
static NSArray *_htmlMimeTypes;

+ (BOOL) canShowMIMEType:(NSString *) MIMEType;
{
	return [self _viewClassForMIMEType:MIMEType] != Nil;
}

+ (BOOL) canShowMIMETypeAsHTML:(NSString *) MIMEType
{
	return [_htmlMimeTypes containsObject:MIMEType];	// FIXME: case insensitive???
}

+ (void) initialize;
{
#if 0
	NSLog(@"WebView +initialize");
#endif
	[self setMIMETypesShownAsHTML:[NSArray arrayWithObjects:@"text/html", nil]];
	[self registerViewClass:[_WebHTMLDocumentView class]
		representationClass:[_WebHTMLDocumentRepresentation class]
				forMIMEType:@"text/html"];	// we are ourselves the default for HTML
	[self registerViewClass:[NSImageView class]
		representationClass:[_WebImageDocumentRepresentation class]
				forMIMEType:@"image/"];		// match all images
	[self registerViewClass:self	// [_WebPDFDocumentView class] - subclass of NSPDFView
		representationClass:[_WebPDFDocumentRepresentation class]
				forMIMEType:@"text/pdf"];
	[self registerViewClass:self	// [_WebXMLDocumentView class]
		representationClass:[_WebXMLDocumentRepresentation class]
				forMIMEType:@"text/xml"];
}

+ (NSArray *) MIMETypesShownAsHTML; { return _htmlMimeTypes; }

+ (void) registerViewClass:(Class) class representationClass:(Class) repClass forMIMEType:(NSString *) type;
{
#if 0
	NSLog(@"registerViewClass:%@ representationClass:%@ forMIMEType:%@", NSStringFromClass(class), NSStringFromClass(repClass), type);
#endif
	if(!_viewClasses)
		{ // allocate container(s)
		_viewClasses=[[NSMutableDictionary alloc] initWithCapacity:5];
		_representationClasses=[[NSMutableDictionary alloc] initWithCapacity:5];
		}
	if(class != Nil && repClass != Nil)
		{
		[_viewClasses setObject:class forKey:type];
		[_representationClasses setObject:repClass forKey:type];
		}
	else
		{
		[_viewClasses removeObjectForKey:type];
		[_representationClasses removeObjectForKey:type];
		}
}

+ (void) setMIMETypesShownAsHTML:(NSArray *) types;
{
	ASSIGN(_htmlMimeTypes, types);
}

+ (Class) _representationClassForMIMEType:(NSString *) type;
{ // find representation class
	Class cls;
	NSArray *c;
	c=[type componentsSeparatedByString:@";"];
	type=[c objectAtIndex:0];	// ignore ; parameters
	if([self canShowMIMETypeAsHTML:type])
		type=@"text/html";
	if((cls=[_representationClasses objectForKey:type]))
		return cls;	// appears to match
	c=[type componentsSeparatedByString:@"/"];
	type=[[c objectAtIndex:0] stringByAppendingString:@"/"];	// get major type component only and append /
	cls=[_representationClasses objectForKey:type];
	return cls;
}

+ (Class) _viewClassForMIMEType:(NSString *) type;
{ // find view class
	Class cls;
	NSArray *c=[type componentsSeparatedByString:@";"];
	type=[c objectAtIndex:0];	// ignore ; parameters
	if([self canShowMIMETypeAsHTML:type])
		type=@"text/html";
	if((cls=[_viewClasses objectForKey:type]))
		return cls;	// appears to match full type
	c=[type componentsSeparatedByString:@"/"];
	type=[[c objectAtIndex:0] stringByAppendingString:@"/"];	// get major type component only and append /
	cls=[_viewClasses objectForKey:type];	// check for wildcard match
	return cls;
}

- (id) initWithFrame:(NSRect) rect;
{
	return [self initWithFrame:rect frameName:nil groupName:nil];
}

- (id) initWithFrame:(NSRect) rect frameName:(NSString *) name groupName:(NSString *) group;
{
#if 0
	NSLog(@"mySTEP: WebView initWithFrame:%@", NSStringFromRect(rect));
#endif
	if((self=[super initWithFrame:rect]))
		{
		WebFrameView *frameView=[[WebFrameView alloc] initWithFrame:(NSRect){ NSZeroPoint, rect.size}];	// view for the main frame
		_mainFrame=[[WebFrame alloc] initWithName:name webFrameView:frameView webView:self];	// assign a WebFrame
		[self addSubview:frameView];		// make it our subview with same size
		[frameView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];	// autoresize main Frame with WebView
		[frameView setAllowsScrolling:YES];	// main view can always scroll (if needed)
		[frameView release];
		_groupName=[group retain];
		_drawsBackground=YES;
		_textSize=4;	// default size
		}
	return self;
}

#if 0
- (void) awakeFromNib
{
	NSLog(@"mySTEP: WebView awakeFromNib");
}
#endif

- (void) dealloc;
{
	[_mainFrame release];
	[_groupName release];
	[_backForwardList release];
	[_customAgent release];
	[_customTextEncoding release];
	[_applicationName release];
	[super dealloc];
}

- (WebFrame *) mainFrame;   { return _mainFrame; }
- (id) UIDelegate; { return _uiDelegate; }
- (void) setUIDelegate:(id) uid; { _uiDelegate=uid; }
- (id) frameLoadDelegate; { return _frameLoadDelegate; }
- (void) setFrameLoadDelegate:(id) uid; { _frameLoadDelegate=uid; }
- (NSString *) groupName; { return _groupName; }
- (void) setGroupName:(NSString *) str; { ASSIGN(_groupName, str); }

- (WebBackForwardList *) backForwardList; { return _backForwardList; }

- (void) setMaintainsBackForwardList:(BOOL) flag;
{
	if(flag && !_backForwardList)
		_backForwardList=[[WebBackForwardList alloc] init];
	else if(!flag && _backForwardList)
		[_backForwardList release], _backForwardList=nil;
}

- (NSString *) applicationNameForUserAgent; { return _applicationName; }
- (void) setApplicationNameForUserAgent:(NSString *) name; { _applicationName=[name retain]; }
- (NSString *) customUserAgent; { return _customAgent; }
- (void) setCustomUserAgent:(NSString *) agent; { _customAgent=[agent retain]; }
- (NSString *) customTextEncodingName; { return _customTextEncoding; }
- (void) setCustomTextEncodingName:(NSString *) name; { _customTextEncoding=[name retain]; }

	// FIXME

- (BOOL) canGoBack; { return NO; }
- (BOOL) canGoForward; { return NO; }

- (IBAction) takeStringURLFrom:(id) sender;
{
	// add http:// prefix if there is none yet
	NSURL *u=[NSURL URLWithString:[sender stringValue]];
#if 0
	NSLog(@"takeStringURL %@", u);
#endif
	[_mainFrame loadRequest:[NSURLRequest requestWithURL:u]];
}

- (double) estimatedProgress;
{
// FIXME
	return 0.0;
}

- (IBAction) reload:(id) sender;
{
	[_mainFrame reload];	// should also reload subframes?
}

- (IBAction) stopLoading:(id) sender;
{
	[_mainFrame stopLoading];
}

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script;
{
	return @"JavaScript not implemented";
}

- (IBAction) goBack:(id) sender; { NIMP; }
- (IBAction) goForward:(id) sender; { NIMP; }

- (void) drawRect:(NSRect) rect;
{
	if(_drawsBackground)
		{
		[[NSColor whiteColor] set];
		NSRectFill(rect);
		}
}

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem
{
	NSString *sel=NSStringFromSelector([menuItem action]);
	if([sel isEqualToString:@"goBack:"]) return [self canGoBack];
	if([sel isEqualToString:@"goForward:"]) return [self canGoForward];
	if([sel isEqualToString:@"makeTextLarger:"]) return [self canMakeTextLarger];
	if([sel isEqualToString:@"makeTextSmaller:"]) return [self canMakeTextSmaller];
	return YES;
}

// private methods!

- (BOOL) drawsBackground;
{
	return _drawsBackground;
}

- (void) setDrawsBackground:(BOOL) flag;
{
	_drawsBackground=flag;
}

// FIXME: no - we should modify/use the textSizeMultiplier and keep the NSFont logic in the WebHTMLDocument!

static NSMutableArray *fonts;
static NSMutableArray *hfonts;

- (NSArray *) _fontsForSize;
{ // 7 default fonts for the <font size="x"> tag - 0 (size=1) is smallest, 6 is largest, 2 is default
	if(!fonts)
		{
		fonts=[[NSMutableArray alloc] initWithCapacity:7];
		// adjust these sizes by the _textSize so that text is scaled
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:8.0]];		// 1
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:10.0]];		// 2
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:12.0]];		// 3=default
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:14.0]];		// 4 - <h3>
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:16.0]];		// 5 - <h2>
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:18.0]];		// 6 - <h1>
		[fonts addObject:[NSFont fontWithName:@"Helvetica" size:24.0]];		// 7
		}
	return fonts;
}

- (NSArray *) _fontsForHeader;
{ // 6 fonts for the <h#> tags - 0 (<h1>) is largest, 5 is smallest
	if(!hfonts)
		{
		hfonts=[[NSMutableArray alloc] initWithCapacity:6];
		// adjust these sizes by the _textSize so that text is scaled
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:24.0]];	// 1 - <h1>
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:18.0]];	// 2 - <h2>
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:16.0]];	// 3 - <h3>
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:14.0]];	// 4 - <h4>
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:12.0]];	// 5 - <h5>
		[hfonts addObject:[NSFont fontWithName:@"Helvetica-Bold" size:10.0]];	// 6 - <h6>
		}
	return hfonts;
}

// FIXME: modify the multiplier factor to increase in steps of 1.2 or decrease by 1/1.2
- (BOOL) canMakeTextLarger;
{
	return _textSize < 9;
}

- (BOOL) canMakeTextSmaller;
{
	return _textSize > 0;
}

- (void) _setTextSize:(int) sz
{
	if(_textSize != sz)
		{
		_textSize=sz;
		[fonts release];
		fonts=nil;
		// make our subviews reparse from DOM tree [xxx setNeedsLayout:YES];
		}
}

- (IBAction) makeTextLarger:(id) sender;
{
	if([self canMakeTextLarger])
		[self _setTextSize:_textSize+1];
}

- (IBAction) makeTextSmaller:(id) sender;
{
	if([self canMakeTextSmaller])
		[self _setTextSize:_textSize-1];
}

- (NSString *) mediaStyle; { return _mediaStyle; }
- (void) setMediaStyle:(NSString *) style; { ASSIGN(_mediaStyle, style); }
- (DOMCSSStyleDeclaration *) typingStyle; { return _typingStyle; }
- (void) setTypingStyle:(DOMCSSStyleDeclaration *) style; { ASSIGN(_typingStyle, style); }

- (DOMCSSStyleDeclaration *) computedStyleForElement:(DOMElement *) element
									   pseudoElement:(NSString *) pseudoElement;
{
	// could also set up a data source and "load" from there
	return [[[DOMCSSStyleDeclaration alloc] initWithString:pseudoElement forElement:element] autorelease];
}

- (DOMCSSStyleDeclaration *) styleDeclarationWithText:(NSString *) text;
{
	return [self computedStyleForElement:nil pseudoElement:text];
}

- (void) startSpeaking:(id) sender; { [(NSTextView *) [[_mainFrame frameView] documentView] startSpeaking:sender]; }
- (void) stopSpeaking:(id) sender; { [(NSTextView *) [[_mainFrame frameView] documentView] stopSpeaking:sender]; }

/* incomplete implementation of class 'WebView'

method definition for '+URLTitleFromPasteboard:' not found
method definition for '+URLFromPasteboard:' not found
method definition for '-writeSelectionWithPasteboardTypes:toPasteboard:' not found
method definition for '-writeElement:withPasteboardTypes:toPasteboard:' not found
method definition for '-windowScriptObject' not found
method definition for '-userAgentForURL:' not found
method definition for '-undoManager' not found
method definition for '-textSizeMultiplier' not found
method definition for '-supportsTextEncoding' not found
method definition for '-spellCheckerDocumentTag' not found
method definition for '-smartInsertDeleteEnabled' not found
method definition for '-showGuessPanel:' not found
method definition for '-setTypingStyle:' not found
method definition for '-setTextSizeMultiplier:' not found
method definition for '-setSmartInsertDeleteEnabled:' not found
method definition for '-setSelectedDOMRange:affinity:' not found
method definition for '-setResourceLoadDelegate:' not found
method definition for '-setPreferencesIdentifier:' not found
method definition for '-setPreferences:' not found
method definition for '-setPolicyDelegate:' not found
method definition for '-setMediaStyle:' not found
method definition for '-setHostWindow:' not found
method definition for '-setEditingDelegate:' not found
method definition for '-setEditable:' not found
method definition for '-setDownloadDelegate:' not found
method definition for '-setContinuousSpellCheckingEnabled:' not found
method definition for '-selectionAffinity' not found
method definition for '-selectedDOMRange' not found
method definition for '-searchFor:direction:caseSensitive:wrap:' not found
method definition for '-resourceLoadDelegate' not found
method definition for '-replaceSelectionWithText:' not found
method definition for '-replaceSelectionWithNode:' not found
method definition for '-replaceSelectionWithMarkupString:' not found
method definition for '-replaceSelectionWithArchive:' not found
method definition for '-removeDragCaret' not found
method definition for '-preferencesIdentifier' not found
method definition for '-preferences' not found
method definition for '-policyDelegate' not found
method definition for '-performFindPanelAction:' not found
method definition for '-pasteFont:' not found
method definition for '-pasteboardTypesForSelection' not found
method definition for '-pasteboardTypesForElement:' not found
method definition for '-pasteAsRichText:' not found
method definition for '-pasteAsPlainText:' not found
method definition for '-paste:' not found
method definition for '-moveDragCaretToPoint:' not found
method definition for '-isEditable' not found
method definition for '-isContinuousSpellCheckingEnabled' not found
method definition for '-hostWindow' not found
method definition for '-goToBackForwardItem:' not found
method definition for '-goForward' not found
method definition for '-goBack' not found
method definition for '-elementAtPoint:' not found
method definition for '-editingDelegate' not found
method definition for '-editableDOMRangeForPoint:' not found
method definition for '-downloadDelegate' not found
method definition for '-deleteSelection' not found
method definition for '-delete:' not found
method definition for '-cut:' not found
method definition for '-copyFont:' not found
method definition for '-copy:' not found
method definition for '-checkSpelling:' not found
method definition for '-changeFont:' not found
method definition for '-changeDocumentBackgroundColor:' not found
method definition for '-changeColor:' not found
method definition for '-changeAttributes:' not found
method definition for '-applyStyle:' not found
method definition for '-alignRight:' not found
method definition for '-alignLeft:' not found
method definition for '-alignJustified:' not found
method definition for '-alignCenter:' not found
 
*/

@end

// default implementations

@implementation NSObject (WebUIDelegate)

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) menu; { return menu; }
- (WebView *) webView:(WebView *) sender createWebViewWithRequest:(NSURLRequest *) request; { return nil; }
- (unsigned) webView:(WebView *) sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>) mask; { return WebDragDestinationActionAny; }
- (unsigned) webView:(WebView *) sender dragSourceActionMaskForPoint:(NSPoint) point;
{
	if(0 /* editable */)
		return (WebDragSourceActionAny & ~WebDragSourceActionLink);
	else
		return WebDragDestinationActionAny;
}

- (void) webView:(WebView *) sender makeFirstResponder:(NSResponder *) responder; { [[sender window] makeFirstResponder:responder]; }
- (void) webView:(WebView *) sender mouseDidMoveOverElement:(NSDictionary *) element modifierFlags:(unsigned int) flags; { return; }
- (void) webView:(WebView *) sender runJavaScriptAlertPanelWithMessage:(NSString *) message; { return; }
- (BOOL) webView:(WebView *) sender runJavaScriptConfirmPanelWithMessage:(NSString *) message; { return NO; }
- (NSString *) webView:(WebView *) sender runJavaScriptTextInputPanelWithPrompt:(NSString *) prompt defaultText:(NSString *) text; { return @""; }
- (void) webView:(WebView *) sender runOpenPanelForFileButtonWithResultListener:(id<WebOpenPanelResultListener>) listener; { return; }
//- (void) webView:(WebView *) sender setContentRect:(NSRect) rect; { [self webView:sender setFrame:[[sender window] frameRectForContentRect:rect]]; }
- (void) webView:(WebView *) sender setFrame:(NSRect) frame; { [[sender window] setFrame:frame display:YES]; }
- (void) webView:(WebView *) sender setResizable:(BOOL) flag; { [[sender window] setShowsResizeIndicator:flag]; }
- (void) webView:(WebView *) sender setStatusBarVisible:(BOOL) flag; { return; }
- (void) webView:(WebView *) sender setStatusText:(NSString *) text; { return; }
- (void) webView:(WebView *) sender setToolbarsVisible:(BOOL) flag; { return; }
- (BOOL) webView:(WebView *) sender shouldPerformAction:(SEL) action fromSender:(id) send; { return YES; }
- (BOOL) webView:(WebView *) sender validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>) item defaultValidation:(BOOL) flag; { return flag; }
- (void) webView:(WebView *) sender willPerformDragDestinationAction:(WebDragDestinationAction) action forDraggingInfo:(id <NSDraggingInfo>) info; { return; }
- (void) webView:(WebView *) sender willPerformDragSourceAction:(WebDragSourceAction) action fromPoint:(NSPoint) point withPasteboard:(NSPasteboard *) pasteboard; { return; }
- (BOOL) webViewAreToolbarsVisible:(WebView *) sender; { return NO; }
- (void) webViewClose:(WebView *) sender; { [[sender window] close]; }
- (NSRect) webViewContentRect:(WebView *) sender; { return [[[sender window] contentView] frame]; }
- (NSResponder *) webViewFirstResponder:(WebView *) sender; { return [[sender window] firstResponder]; }
- (void) webViewFocus:(WebView *) sender; { return [[sender window] orderFront:nil]; }
- (NSRect) webViewFrame:(WebView *) sender; { return [sender frame]; }
- (BOOL) webViewIsResizable:(WebView *) sender; { return NO; }
- (BOOL) webViewIsStatusBarVisible:(WebView *) sender; { return NO; }
- (void) webViewShow:(WebView *) sender; { return; }
- (NSString *) webViewStatusText:(WebView *) sender; { return nil; }
- (void ) webViewUnfocus:(WebView *) sender; { return; }

@end

@implementation NSObject (WebFrameLoadDelegate)

- (void) webView:(WebView *) sender didCancelClientRedirectForFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didChangeLocationWithinPageForFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didCommitLoadForFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didFailLoadWithError:(NSError *) error forFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didFailProvisionalLoadWithError:(NSError *) error forFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *)frame; { return; }
- (void) webView:(WebView *) sender didReceiveIcon:(NSImage *) image forFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame; { return; }
- (void) webView:(WebView *) sender didStartProvisionalLoadForFrame:(WebFrame *)frame; { return; }
- (void) webView:(WebView *) sender serverRedirectedForDataSource:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender willCloseFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender willPerformClientRedirectToURL:(NSURL *) url delay:(NSTimeInterval) seconds fireDate:(NSDate *) date forFrame:(WebFrame *) frame; { return; }
- (void) webView:(WebView *) sender windowScriptObjectAvailable:(WebScriptObject *) script; { return; }

@end
