/* simplewebkit
   WebView.m
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


/* short description how this all works togehter

1. the WebView
* is the master view object and there is only one per browser (or browser tab)
* it holds the mainFrame which represents either the normal <body> or the top level <frame> or <frameset>
* if there is a <frameset> hierarchy, there are additional child WebFrames

2. the WebFrame
* is repsonsible for loading and rendering content from a specific URL
* it uses a WebDataSource to trigger loading and get callbacks
* it is also the owner of the DOMDocument tree
* JavaScript statements are evaluated in a frame context
* it is also the target of user clicks on links since it knows the base URL (through the WebDataSource)

3. the WebDataSource
* is responsible for loading data from an URL
* it may cache data and handle/synchronize loading fo subresources (e.g. for an embedded <img> tag)
* it translates the request and the response URLs
* it provides an estimated content length (for a progress indicator) and the MIMEType of the incoming data stream
* as soon as the header comes in a WebDocomentRepresentation is created and incoming segments are notified
* it also collects the incoming data, so that a WebDocomentRepresentation can handle either segments or the collected data

4. the WebDocumentRepresentation(s)
* there is one for each MIME type (the WebView provides a mapping database)
* it is responsible for parsing the incoming data stream (either completely when finished, or partially)
* and provide a better suitable representation, e.g. an NSImage or a DOMHTMLTree
* finally, it creates a WebDocumentView as the child of the WebView and attaches it to the WebFrame as the -webFrameView
* so, if you want to handle an additional MIME type, write a class that conforms to the WebDocumentRepresentation protocol

5. the DOMHTMLTree
* is only for HTML content
* is (re)built each time a new segment of HTML data comes in
* any change in the DOMHTMLTree is notified to the WebDocumentView (or one of its subviews) by setNeedsLayout

6. the WebDocumentView(s) an its subviews
* are responsible for displaying the contents of its WebDataRepresentation
* either HTML, Images, PDF or whatever (e.g. SVG, XML, ...)
* they gets notified about changes either by updates of the WebDataSource (-dadaSourceUpdated:) or directly (-setNeedsLayout:)
* if one needs layout, it must go to the DOM Tree to find out what has changed and update its size, content, children, layout etc.
* this is a little tricky/risky since the -layout method is called within -drawRect: - so changing e.g. the View frame is very
  critical and may result in drawing glitches
* for HTML, we do a simple trick: the WebDocumentView is an NSTextView and the DOMHTMLTree objects can be traversed to
  return an attributedString with embedded Tables and NSTextAttachments

7. the JavaScript engine
* is programmed according to the specificaion of ECMA-262
* uses a simple recursive stateless parser (could be optimized in stack useage and speed by a state-table driven approach)
* parses the script into a Tree representation in a first step
* then, evaluates the expressions and statements according to the current environement
* this allows to store scripts in translated form and reevaluate them when needed (e.g. on mouse events)
* uses Foundation for basic types (string, number, boolean, null)
* uses WebScriptObject as the base Object representation
* DOMObjects are a subclass of WebScriptObjects and therefore provide bridging, so that changing a DOMHTML tree element through
  JavaScript automativally triggers the appropriate WebDocumentView notification

*/

#import "Private.h"
#import <WebKit/WebView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebBackForwardList.h>
#import <WebKit/WebPreferences.h>

#import "ECMAScriptParser.h"
#import "ECMAScriptEvaluator.h"

#import <WebKit/DOMCSS.h>

// default document representations we understand
#import "WebHTMLDocumentRepresentation.h"	// text/html
#import "WebHTMLDocumentView.h"
#import "WebPDFDocument.h"					// text/pdf
#import "WebXMLDocument.h"					// text/xml
#import "WebTextDocument.h"					// text/*
#import "WebImageDocument.h"				// image/*

NSString *WebElementDOMNodeKey=@"WebElementDOMNode";
NSString *WebElementFrameKey=@"WebElementFrame";
NSString *WebElementImageAltStringKey=@"WebElementImageAltString";
NSString *WebElementImageKey=@"WebElementImage";
NSString *WebElementImageRectKey=@"WebElementImageRect";
NSString *WebElementImageURLKey=@"WebElementImageURL";
NSString *WebElementIsSelectedKey=@"WebElementIsSelected";
NSString *WebElementLinkURLKey=@"WebElementLinkURL";
NSString *WebElementLinkTargetFrameKey=@"WebElementLinkTargetFrame";
NSString *WebElementLinkTitleKey=@"WebElementLinkTitle";
NSString *WebElementLinkLabelKey=@"WebElementLinkLabel";

NSString *WebViewDidBeginEditingNotification=@"WebViewDidBeginEditing";
NSString *WebViewDidChangeNotification=@"WebViewDidChange";
NSString *WebViewDidChangeSelectionNotification=@"WebViewDidChangeSelection";
NSString *WebViewDidChangeTypingStyleNotification=@"WebViewDidChangeTypingStyle";
NSString *WebViewDidEndEditingNotification=@"WebViewDidEndEditing";
NSString *WebViewProgressEstimateChangedNotification=@"WebViewProgressEstimateChanged";
NSString *WebViewProgressFinishedNotification=@"WebViewProgressFinished";
NSString *WebViewProgressStartedNotification=@"WebViewProgressStarted";

@interface _WindowScriptObject : WebScriptObject
{
	DOMHTMLDocument *document; 
}
@end

@implementation _WindowScriptObject
@end

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
				forMIMEType:@"text/html"];
	[self registerViewClass:[_WebImageDocumentView class]
		representationClass:[_WebImageDocumentRepresentation class]
				forMIMEType:@"image/"];		// match all images
	[self registerViewClass:[_WebPDFDocumentView class]
		representationClass:[_WebPDFDocumentRepresentation class]
				forMIMEType:@"text/pdf"];
	[self registerViewClass:[_WebXMLDocumentView class]
		representationClass:[_WebXMLDocumentRepresentation class]
				forMIMEType:@"text/xml"];
	[self registerViewClass:[_WebTextDocumentView class]
		representationClass:[_WebTextDocumentRepresentation class]
				forMIMEType:@"text/"];		// match all other text file types and try our best
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
		[frameView setAllowsScrolling:YES];	// main view can always scroll (if needed)
		[frameView release];
		_groupName=[group retain];
		_drawsBackground=YES;
		_textSizeMultiplier=1.0;	// set default size multiplier (should load from defaults)
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
- (void) setUIDelegate:(id) d; { _uiDelegate=d; }
- (id) frameLoadDelegate; { return _frameLoadDelegate; }
- (void) setFrameLoadDelegate:(id) d; { _frameLoadDelegate=d; }
- (id) resourceLoadDelegate; { return _resourceLoadDelegate; }
- (void) setResourceLoadDelegate:(id) d; { _resourceLoadDelegate=d; }
- (id) downloadDelegate; { return _downloadDelegate; }
- (void) setDownloadDelegate:(id) d; { _downloadDelegate=d; }
- (id) editingDelegate; { return _editingDelegate; }
- (void) setEditingDelegate:(id) d; { _editingDelegate=d; }
- (id) policyDelegate; { return _policyDelegate; }
- (void) setPolicyDelegate:(id) d; { _policyDelegate=d; }
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

- (BOOL) canGoBack; { return _backForwardList?([_backForwardList backItem] != nil):NO; }
- (BOOL) canGoForward; { return _backForwardList?([_backForwardList forwardItem] != nil):NO; }
- (IBAction) goBack:(id) sender; { [self goBack]; }
- (IBAction) goForward:(id) sender; { [self goForward]; }

- (BOOL) goForward;
{
	if([self canGoForward])
		return [self goToBackForwardItem:[_backForwardList itemAtIndex:1]];
	return NO;
}

- (BOOL) goBack;
{
	if([self canGoBack])
		return [self goToBackForwardItem:[_backForwardList itemAtIndex:-1]];
	return NO;
}

- (BOOL) goToBackForwardItem:(WebHistoryItem *) item
{ // this is the core function to handle back and forward movements with reloads
	if(!_backForwardList || ![_backForwardList containsItem:item])
		return NO;	// not found
	[_backForwardList goToItem:item];	// update list
	[_mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[item URLString]]]];	// reload in main frame
	return YES;
}

- (NSString *) applicationNameForUserAgent; { return _applicationName; }
- (void) setApplicationNameForUserAgent:(NSString *) name; { _applicationName=[name retain]; }
- (NSString *) customUserAgent; { return _customAgent; }
- (void) setCustomUserAgent:(NSString *) agent; { _customAgent=[agent retain]; }
- (NSString *) customTextEncodingName; { return _customTextEncoding; }
- (void) setCustomTextEncodingName:(NSString *) name; { _customTextEncoding=[name retain]; }

- (IBAction) takeStringURLFrom:(id) sender;
{
	NSString *str;
	NSURL *u;
	str=[sender stringValue];
	str=[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];	// avoid a quite common problem...
	u=[NSURL URLWithString:str];
	if([[u scheme] length] == 0)
		u=[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", str]];	// add default prefix
#if 0
	NSLog(@"takeStringURL %@ -> %@", str, u);
#endif
	if(u)
		{
		[_mainFrame loadRequest:[NSURLRequest requestWithURL:u]];
		}
	else
		;	// ???
}

- (double) estimatedProgress;
{
	long long loaded=0;
	long long expected=0;
	unsigned l;
	long long e;
	WebDataSource *s;
	// FIXME
	while(NO)
		{ // scan all subresources on this page
		l=[[s data] length];	// how much did we load so far?
		if([s isLoading])
			{
			e=[[s response] expectedContentLength];
			if(e < l)
				e=2*l;	// if we can't determine or did already load more than expected, simply assume more to come...
			}
		else
			e=l;	// everything is loaded as expected
		expected+=e;
		loaded+=l;
		}
	if(expected == 0)
		return 1.0;
	return ((double) loaded)/((double) expected);
}

- (IBAction) reload:(id) sender;
{
	[_mainFrame reload];	// should we also reload subframes?
}

- (IBAction) stopLoading:(id) sender;
{
	[_mainFrame stopLoading];
}

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script;
{
	return [[_mainFrame DOMDocument] evaluateWebScript:script];
}

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

#define ENLARGE	1.2
#define MAXENLARGE	(ENLARGE*ENLARGE*ENLARGE*ENLARGE)
#define MINENLARGE	(1.0/(ENLARGE*ENLARGE*ENLARGE*ENLARGE))

- (BOOL) canMakeTextLarger;
{
	return _textSizeMultiplier < MAXENLARGE;
}

- (BOOL) canMakeTextSmaller;
{
	return _textSizeMultiplier >= MINENLARGE;
}

- (float) textSizeMultiplier; { return _textSizeMultiplier; }

- (void) setTextSizeMultiplier:(float) f
{
	if(f < MINENLARGE) f=MINENLARGE;
	else if(f > MAXENLARGE) f=MAXENLARGE;
	if(_textSizeMultiplier != f)
		{
		_textSizeMultiplier=f;
		[self _recursivelySetNeedsLayout];		// make all our subviews reparse from DOM tree [xxx setNeedsLayout:YES];
		}
}

- (IBAction) makeTextLarger:(id) sender;
{
	if([self canMakeTextLarger])
		[self setTextSizeMultiplier:_textSizeMultiplier*ENLARGE];
}

- (IBAction) makeTextSmaller:(id) sender;
{
	if([self canMakeTextSmaller])
		[self setTextSizeMultiplier:_textSizeMultiplier*(1.0/ENLARGE)];
}

- (NSString *) mediaStyle; { return _mediaStyle; }
- (void) setMediaStyle:(NSString *) style; { ASSIGN(_mediaStyle, style); }
- (DOMCSSStyleDeclaration *) typingStyle; { return _typingStyle; }
- (void) setTypingStyle:(DOMCSSStyleDeclaration *) style; { ASSIGN(_typingStyle, style); }

- (DOMCSSStyleDeclaration *) computedStyleForElement:(DOMElement *) element
									   pseudoElement:(NSString *) pseudoElement;
{
	// could also set up a data source and "load" from there (?)
	return [[[DOMCSSStyleDeclaration alloc] initWithString:pseudoElement forElement:element] autorelease];
}

- (DOMCSSStyleDeclaration *) styleDeclarationWithText:(NSString *) text;
{
	return [self computedStyleForElement:nil pseudoElement:text];
}

- (void) startSpeaking:(id) sender; { [(NSTextView *) [[_mainFrame frameView] documentView] startSpeaking:sender]; }
- (void) stopSpeaking:(id) sender; { [(NSTextView *) [[_mainFrame frameView] documentView] stopSpeaking:sender]; }

- (WebScriptObject *) windowScriptObject
{
	// should be created only once
	WebScriptObject *o;
	/*
	should this be the 'window' object - or is this the "global" object???
	but also handle
	[[[webView windowScriptObject] valueForKeyPath:@"document.documentElement.offsetWidth"] floatValue]
	 
	 http://developer.apple.com/documentation/Cocoa/Conceptual/DisplayWebContent/Tasks/JavaScriptFromObjC.html
	 
	 inidcates it is the 'window' object because one can write 
	 
	 [[webView windowScriptObject] evaluateWebScript:@"location.href"];
	 
	*/
	// FIXME: there is also a webView:windowScriptObjectAvailable: frameload delegate method!
	
	// probably called when the mainFrame has its DOMDocument initialized
	o=[[_WindowScriptObject new] autorelease];
	[o setValue:[_mainFrame DOMDocument] forKey:@"document"];
//	[o setValue:nil forKey:@"window"]; -- no we are the "window" object. A browser has a windows array?
//	[o setValue:nil forKey:@"event"];
//	[o setValue:nil forKey:@"event"]; -- etc.
	return o;
}

- (NSDictionary *) elementAtPoint:(NSPoint) point;
{
	/* should return a dictionary like
	WebElementDOMNode = <DOMHTMLDivElement [DIV]: 0x159a37f8 ''>; 
	WebElementFrame = <WebFrame: 0x381780>; 
	WebElementIsSelected = 0; 
	WebElementTargetFrame = <WebFrame: 0x381780>; 
	*/
	// how it could work:
	// 1. we have to determine the subview/frame view / Web(HTML)DocumentView
	// 2. ask the WebHTMLDocumentView for the character index
	// 3. and the attributes at that textStorage location
	return nil;
}

- (BOOL) isEditable; { return _editable; }
- (void) setEditable:(BOOL) flag; { _editable=flag; }

- (WebPreferences *) preferences; { return _preferences?_preferences:[WebPreferences standardPreferences]; }
- (NSString *) preferencesIdentifier; { return [[self preferences] identifier]; }
- (void) setPreferences:(WebPreferences *) prefs; { ASSIGN(_preferences, prefs); }
- (void) setPreferencesIdentifier:(NSString *) ident; { [self setPreferences:[[[WebPreferences alloc] initWithIdentifier:ident] autorelease]]; }

- (NSWindow *) hostWindow; { return _hostWindow; }
- (void) setHostWindow:(NSWindow *) win; { ASSIGN(_hostWindow, win); }

- (void) viewWillMoveToWindow:(NSWindow *) win
{
  if(!win && _hostWindow)
    { // is being orphaned from the current window
      [_hostWindow setContentView:self];	// make us the content view of the host view
	  // notify the WebDocumentView(s)
    }
	// FIXME:
  [super viewWillMoveToWindow: win];	// this is a FIX for GNUstep only
}

- (void) viewWillMoveToSuperview:(NSView *) view
{
  if(!view && _hostWindow)
    { // is being orphaned from the current superview
      [_hostWindow setContentView:self];	// make us the content view of the host view
											// notify the WebDocumentView(s)
    }
	// FIXME:
  [super viewWillMoveToSuperview: view];	// this is a FIX for GNUstep only
}

- (NSString *) userAgentForURL:(NSURL *) url
{
	return [self customUserAgent];
}

- (BOOL) supportsTextEncoding;
{
	// FIXME: depends on data source contents (used to enable/disable a text encoding menu)
	return YES;
}

+ (NSURL *) URLFromPasteboard:(NSPasteboard *) pasteboard;
{
	return NIMP;
}

+ (NSString *) URLTitleFromPasteboard:(NSPasteboard *) pasteboard;
{
	return NIMP;
}

- (void) writeElement:(NSDictionary *) element
  withPasteboardTypes:(NSArray *) types
		 toPasteboard:(NSPasteboard *) pasteboard;
{
	//
}

// we should substitute _hostWindow if available!

/* incomplete implementation of class 'WebView'

we do not implement for now because they are for HTML/DOM Editing:

method definition for '-writeSelectionWithPasteboardTypes:toPasteboard:' not found
method definition for '-undoManager' not found
method definition for '-spellCheckerDocumentTag' not found
method definition for '-smartInsertDeleteEnabled' not found
method definition for '-showGuessPanel:' not found
method definition for '-setTypingStyle:' not found
method definition for '-setSmartInsertDeleteEnabled:' not found
method definition for '-setSelectedDOMRange:affinity:' not found
method definition for '-setContinuousSpellCheckingEnabled:' not found
method definition for '-selectionAffinity' not found
method definition for '-selectedDOMRange' not found
method definition for '-searchFor:direction:caseSensitive:wrap:' not found
method definition for '-replaceSelectionWithText:' not found
method definition for '-replaceSelectionWithNode:' not found
method definition for '-replaceSelectionWithMarkupString:' not found
method definition for '-replaceSelectionWithArchive:' not found
method definition for '-removeDragCaret' not found
method definition for '-performFindPanelAction:' not found
method definition for '-pasteFont:' not found
method definition for '-pasteboardTypesForSelection' not found
method definition for '-pasteboardTypesForElement:' not found
method definition for '-pasteAsRichText:' not found
method definition for '-pasteAsPlainText:' not found
method definition for '-paste:' not found
method definition for '-moveDragCaretToPoint:' not found
method definition for '-isContinuousSpellCheckingEnabled' not found
method definition for '-editableDOMRangeForPoint:' not found
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
	if([sender isEditable])
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
- (void) webView:(WebView *) sender setContentRect:(NSRect) rect;
{
	[self webView:sender setFrame:[NSWindow frameRectForContentRect:rect styleMask:[[sender window] styleMask]]]; 
}
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

@implementation NSObject (WebResourceLoadDelegate)

- (id) webView:(WebView *) sender identifierForInitialRequest:(NSURLRequest *) req fromDataSource:(WebDataSource *) src; { return [[NSObject new] autorelease]; }
- (void) webView:(WebView *) sender plugInFailedWithError:(NSError *) error dataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *) ch fromDataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didFailLoadingWithError:(NSError *) error fromDataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didFinishLoadingFromDataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *) ch fromDataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didReceiveContentLength:(unsigned) len fromDataSource:(WebDataSource *) src; { return; }
- (void) webView:(WebView *) sender resource:(id) ident didReceiveResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src; { return; }
- (NSURLRequest *) webView:(WebView *) sender resource:(id) ident willSendRequest:(NSURLRequest *) req redirectResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src; { return req; }

@end
