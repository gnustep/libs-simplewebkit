//
//  MyDocument.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 07.04.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
#import "MyApplication.h"
#import <WebKit/DOMCSS.h>

// FIXME: SWK also needs some (private) implementation for properly handling URLs in link-tooltips, handling CSS, -title etc.

@interface NSURL (UnicodeURL)

+ (NSURL *) URLWithUnicodeString:(NSString *) str;
- (id) initWithUnicodeString:(NSString *) str;
- (NSString *) unicodeAbsoluteString;
- (NSString *) unicodeHost;

@end

@implementation NSURL (UnicodeURL)

+ (NSURL *) URLWithUnicodeString:(NSString *) str;
{
	return [[[self alloc] initWithUnicodeString:str] autorelease];
}

- (id) initWithUnicodeString:(NSString *) str;
{
	// FIXME:
	return [self initWithString:str];
}

- (NSString *) unicodeAbsoluteString;
{
	// FIXME:
	return [self absoluteString];
}

- (NSString *) unicodeHost;
{
	// FIXME:
	return [self host];
}

@end

@implementation MyDocument

- (NSString *) windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"MyDocument";
}

- (void) windowControllerDidLoadNib:(NSWindowController *) aController
{
#if 1
	NSLog(@"windowControllerDidLoadNib");
#endif
#if 0
	NSLog(@"isflipped=%d %@", [[domTree superview] isFlipped], [domTree superview]);	// is a split view flipped?
	NSLog(@"isflipped=%d %@", [[[domTree superview] superview] isFlipped], [[domTree superview] superview]);	// is a split view flipped?
	NSLog(@"isflipped=%d %@", [[[[domTree superview] superview] superview] isFlipped], [[[domTree superview] superview] superview]);	// is a split view flipped?
#endif
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[domTree setDoubleAction:@selector(doubleClick:)];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressStartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressEstimateChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressFinishedNotification object:nil];
	[webView setResourceLoadDelegate:[NSApp delegate]];
	[webView setUIDelegate:self];
	[webView setGroupName:@"MyDocument"];
	[webView setMaintainsBackForwardList:YES];
	[webView setCustomUserAgent:nil];
	[webView setApplicationNameForUserAgent:@"GNUstep Simple WebKit Browser"];
	[self showStatus:@""];
	if(!openfile)
		{ // make dependent on preferences what happens on launch
			[self home:self];	// default to Home
			return;
		}
	[self setLocationAndLoad:openfile];
	[openfile release];
	openfile=nil;
}

- (void) dealloc;
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[openfile release];
	[destinations release];
	[domNodes release];
	[super dealloc];
}

- (void) setLocationAndLoad:(NSURL *) url;
{
	[self setLocation:url];
	[webView takeStringURLFrom:currentURL];
#if 0
	NSLog(@"1 document=%p", [[webView mainFrame] DOMDocument]);
#endif
}

- (void) setLocation:(NSURL *) url;
{
#if 1
	NSLog(@"setLocation %@", url);
#endif
	if(!url)
		return;
	[currentURL setStringValue:[url unicodeAbsoluteString]];
}

- (IBAction) makeTextDefault:(id) Sender;
{
	[webView setTextSizeMultiplier:1.0];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	NSString *sel=NSStringFromSelector([item action]);
	if([sel isEqualToString:@"makeTextDefault:"]) return [webView textSizeMultiplier] != 1.0;
	return YES;
}

- (IBAction) home:(id) Sender;
{
	NSString *home=[[NSUserDefaults standardUserDefaults] objectForKey:@"HomePage"];
	if(!home)
		home=@"about:blank";
#if 1
	[self setLocationAndLoad:[NSURL URLWithUnicodeString:home]];
#else
	[[webView mainFrame] loadHTMLString:@"<html><head><title>Document Title</title></head><body bgcolor=\"#f0f0f0f0\">Welcome to the GNUstep Web Browser</body></html>" baseURL:nil];
#endif
}

- (IBAction) goBack:(id) sender;
{ // button must be set to "continuous" in Interface Builder
#if 1
	NSLog(@"goBack %@", [NSApp currentEvent]);
#endif
	if([[NSApp currentEvent] type] == NSPeriodic)
		{
#if 1
		NSLog(@"periodic event");
#endif
#if 0			// FIXME
		NSMenu *menu=[[[NSMenu alloc] init] autorelease];
		NSMenuItem *mi;
		mi=[menu addItemWithTitle:@"Item1" action:@selector(history:) keyEquivalent:@""];
		// [mi setRepresentedObject:hitem];
		// [mi setTarget:self];
		mi=[menu addItemWithTitle:@"Item2" action:@selector(history:) keyEquivalent:@""];
		[NSMenu popUpContextMenu:menu withEvent:[NSApp currentEvent] forView:sender];	// should probably be the original mousedown event with a reference to the window!
#endif
		}
	else
		[webView goBack:sender];	// standard event
}

- (IBAction) goForward:(id) sender;
{ // button must be set to "continuous" in Interface Builder
#if 1
	NSLog(@"goForward %@", [NSApp currentEvent]);
#endif
	if([[NSApp currentEvent] type] == NSPeriodic)
		{
#if 1
		NSLog(@"periodic event");
#endif
		}
	else
		[webView goForward:sender];
}

- (NSData *) dataRepresentationOfType:(NSString *)aType
{
    return nil;	// nothing to Save
}

- (BOOL) readFromURL:(NSURL *) url ofType:(NSString *) typeName error:(NSError **) outError
{
#if 1
	NSLog(@"readFromURL: %@", url);
#endif
	openfile=[url retain];
	return YES;
}

- (WebView *) webView; { return webView; }

- (void) showStatus:(NSString *) str;
{
	[status setStringValue:str];
#if 1
	NSLog(@"status: %@", str);
#endif
}

- (IBAction) loadPageFromComboBox:(id) sender;
{
	NSString *str;
	NSURL *u;
	str=[sender stringValue];
	if([str hasPrefix:@"test:"])
		{ // test file -> relative to our demo resources
			NSString *path=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"DemoHTML"];
			path=[path stringByAppendingPathComponent:[str substringFromIndex:5]];
			u=[NSURL fileURLWithPath:path];
		}
	else
		u=[NSURL URLWithUnicodeString:str];
	if([[u scheme] length] == 0)
		u=[NSURL URLWithUnicodeString:[NSString stringWithFormat:@"http://%@", str]];	// try to prefix
#if 1
	NSLog(@"loadPageFromComboBox %@ -> %@", str, u);
#endif
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:u]];
	[sender becomeFirstResponder];	// keep first responder state
}

- (IBAction) loadPageFromMenuItem:(id) sender
{
	NSString *str;
	NSURL *u;
	str=[sender title];
	u=[NSURL URLWithUnicodeString:str];
	if([[u scheme] length] == 0)
		u=[NSURL URLWithUnicodeString:[NSString stringWithFormat:@"http://%@", str]];	// try to prefix
#if 1
	NSLog(@"loadPageFromMenuItem %@ -> %@", str, u);
#endif
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:u]];
}

- (IBAction) loadPageFromHistoryItem:(id) menuItem
{
	WebHistoryItem *historyItem=[menuItem representedObject];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithUnicodeString:[historyItem URLString]]]];
}

- (IBAction) scriptFromMenuItem:(id) sender;
{
	[command setStringValue:[sender title]];
	[self script:command];
}

- (IBAction) showSource:(id) sender
{
	NSString *src=[[[[webView mainFrame] dataSource] representation] documentSource];
	if(!src)
		src=@"<no document source available>";
	[docSource setString:src];
	[[docSource window] makeKeyAndOrderFront:sender];
}

- (IBAction) showAttributedString:(id) sender
{
	NSString *src=[[(NSTextView *) [[[webView mainFrame] frameView] documentView] textStorage] description];
	if(!src)
		src=@"<no documentView available>";
	[docSource setString:src];
	[[docSource window] makeKeyAndOrderFront:sender];
}

- (IBAction) showDOMTree:(id) sender;
{
	[[domTree window] makeKeyAndOrderFront:sender];
	[domTree reloadData];
}

- (IBAction) showStyleSheets:(id) sender;
{
	[[styleSheets window] makeKeyAndOrderFront:sender];
	[styleSheets reloadData];
}

- (IBAction) showViewTree:(id) sender;
{
	[[viewTree window] makeKeyAndOrderFront:sender];
	[viewTree reloadData];
}

- (IBAction) openJavaScriptConsole:(id) sender
{
	[[command window] makeKeyAndOrderFront:sender];
}

- (IBAction) script:(id) sender
{ // evaluate java script
	NSString *cmd=[sender stringValue];
	NSString *r;
	[[result textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:cmd] autorelease]];
	[[result textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
	[result scrollRangeToVisible:NSMakeRange([[result textStorage] length], 0)];
	[sender setStringValue:@""];	// clear
	//	r=[[webView stringByEvaluatingJavaScriptFromString:cmd] description];	<- this one returns NSString only (or substitutes @"")
	r=[[webView windowScriptObject] evaluateWebScript:cmd];
	if(!r)
		r=@"<nil>";
	[[result textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:@"-> "] autorelease]];
	[[result textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:[r description]] autorelease]];
	[[result textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
	[result scrollRangeToVisible:NSMakeRange([[result textStorage] length], 0)];
	[[sender window] makeFirstResponder:sender];	// stay first responder
}

- (void) tile;
{
	// resize webView, status bar and toolbar dependent on flags
}

- (void) updateProgress:(NSNotification *) notif;
{
	// decode notification type
	[[currentURL controlView] setNeedsDisplay:YES];
}

// UI delegate methods

- (WebView *) webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{ // create a new window
	id myDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"Hypertext Markup Language" display:YES];
	[[[myDocument webView] mainFrame] loadRequest:request];
	return [myDocument webView];
}

- (void) webViewShow:(WebView *)sender
{ // show window
	id myDocument = [[NSDocumentController sharedDocumentController] documentForWindow:[sender window]];
#if 1
	NSLog(@"webViewShow=%@", sender);
#endif
	[myDocument showWindows];
}

- (void) webView:(WebView *) sender setFrame:(NSRect) frame;
{ // resize window by JavaScript request
	// [window setFrame:frame];
}

- (void) webView:(WebView *) sender setResizable:(BOOL) flag;
{ // allow user to resize window
}

- (void) webView:(WebView *) sender setStatusBarVisible:(BOOL) flag;
{ // show status bar
	hasStatusBar=flag;
	[self tile];
}

- (void) webView:(WebView *) sender setStatusText:(NSString *) text;
{
	[self showStatus:text];
}

- (void) webView:(WebView *) sender setToolbarsVisible:(BOOL) flag;
{
	hasToolbar=flag;
	[self tile];
}

//- (BOOL) webView:(WebView *) sender shouldPerformAction:(SEL) action fromSender:(id) sender;
//- (BOOL) webView:(WebView *) sender validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>) item defaultValidation:(BOOL) flag;
//- (void) webView:(WebView *) sender willPerformDragDestinationAction:(WebDragDestinationAction) action forDraggingInfo:(id <NSDraggingInfo>) info;
//- (void) webView:(WebView *) sender willPerformDragSourceAction:(WebDragSourceAction) action fromPoint:(NSPoint) point withPasteboard:(NSPasteboard *) pasteboard;

- (BOOL) webViewAreToolbarsVisible:(WebView *) sender;
{
	return hasToolbar;
}

- (void) webViewClose:(WebView *) sender;
{
	[[sender window] close];	// close the window where the WebView is embedded in
}

// - (NSRect) webViewContentRect:(WebView *) sender;
// - (NSResponder *) webViewFirstResponder:(WebView *) sender;
// - (void) webViewFocus:(WebView *) sender;

- (NSRect) webViewFrame:(WebView *) sender;
{
	return [webView frame];
}

- (BOOL) webViewIsResizable:(WebView *) sender;
{
	return YES;
}

- (BOOL) webViewIsStatusBarVisible:(WebView *) sender;
{
	return hasStatusBar;
}

- (NSString *) webViewStatusText:(WebView *) sender;
{
	return [status stringValue];
}

// - (void ) webViewUnfocus:(WebView *) sender;

- (void) webView:(WebView *) sender didFailProvisionalLoadWithError:(NSError *) error forFrame:(WebFrame *) frame;
{
	// FIXME: here you can substitute any nicely formatted error message using embedded CSS and JavaScript
	NSString *message=[NSString stringWithFormat:
					   @"<title>Page load failed</title>"
					   @"<h2>Error while trying to load URL %@</h2>"
					   @"The error message is: %@",
					   /* FIXME: htmlentities() if path contains & or ; */[[[frame provisionalDataSource] request] URL], error];
	[frame loadAlternateHTMLString:message baseURL:nil forUnreachableURL:[[[frame provisionalDataSource] request] URL]];
	[self showStatus:@"Server error."];
}

- (void) webView:(WebView *)sender didFailLoadWithError:(NSError *)error :(WebFrame *)frame
{
	// FIXME: here you can substitute any nicely formatted error message using embedded CSS and JavaScript
	NSString *message=[NSString stringWithFormat:
					   @"<title>Page load failed</title>"
					   @"<h2>Error while trying to load URL %@</h2>"
					   @"The error message is: %@",
					   /* FIXME: htmlentities() if path contains & or ; */[[[frame dataSource] request] URL], error];
	[frame loadAlternateHTMLString:message baseURL:nil forUnreachableURL:[[[frame dataSource] request] URL]];
	[self showStatus:@"Load error."];
}


- (void) webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
#if 1
	NSLog(@"didStartProvisionalLoadForFrame:%@", frame);
#endif
	if(frame == [sender mainFrame])
		{
		NSURL *url=[[[frame provisionalDataSource] request] URL];
		if(url)
			{
			[currentURL setStringValue:[url absoluteString]];
			[self showStatus:[NSString stringWithFormat:@"Loading %@...", [url absoluteString]]];
			[[NSApp delegate] removeSubresourcesForFrame:frame];
			}
		else
			{
			NSLog(@"nil URL?");
			[self showStatus:@"nil URL?"];
			}
		}
}

- (void) webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
#if 1
	NSLog(@"title %@ for frame %@", title, frame);
#endif
	if(frame == [sender mainFrame])
		{
		[self setFileName:title];
		}
}

- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	NSString *src;
#if 1
	NSLog(@"webview=%@ didFinishLoadForFrame=%@", sender, frame);
	NSLog(@"webview subviews=%@", [sender subviews]);
	NSLog(@"webview mainFrame=%@", [sender mainFrame]);
	NSLog(@"frame childFrames=%@", [frame childFrames]);
	NSLog(@"frame dataSource=%@", [frame dataSource]);
	NSLog(@"frame dataSource pageTitle=%@", [[frame dataSource] pageTitle]);
	NSLog(@"frame dataSource textEncodingName=%@", [[frame dataSource] textEncodingName]);
	NSLog(@"frame dataSource initialRequest=%@", [[frame dataSource] initialRequest]);
	NSLog(@"frame dataSource request=%@", [[frame dataSource] request]);
	NSLog(@"frame dataSource response=%@", [[frame dataSource] response]);
	NSLog(@"frame dataSource response URL=%@", [[[frame dataSource] response] URL]);
	NSLog(@"frame dataSource subresources=%@", [[frame dataSource] subresources]);
	NSLog(@"frame dataSource mainresource=%@", [[frame dataSource] mainResource]);
	NSLog(@"frame DOMDocument=%@", [frame DOMDocument]);
	NSLog(@"frame frameElement=%@", [frame frameElement]);
	NSLog(@"frame frameView=%@", [frame frameView]);
	NSLog(@"frame name=%@", [frame name]);
	NSLog(@"frame parentFrame=%@", [frame parentFrame]);
	NSLog(@"frame provisionalDataSource=%@", [frame provisionalDataSource]);
	NSLog(@"frame webView=%@", [frame webView]);
	NSLog(@"frame webView elementAtPoint:(10,10)=%@", [[frame webView] elementAtPoint:NSMakePoint(10.0, 10.0)]);
#if 1	// check JavaScript DOM integration
	NSLog(@"webView JavaScript=%@", [[frame webView] stringByEvaluatingJavaScriptFromString:@"document.documentElement.offsetWidth"]);
	NSLog(@"frame DOMDocument WebScript=%@", [[frame DOMDocument] evaluateWebScript:@"document.documentElement.offsetWidth"]);
	NSLog(@"windowScriptObject=%@", [sender windowScriptObject]);
	NSLog(@"windowScriptObject document=%@", [[sender windowScriptObject] valueForKeyPath:@"document"]);
	NSLog(@"windowScriptObject document.documentElement=%@", [[sender windowScriptObject] valueForKeyPath:@"document.documentElement"]);
	NSLog(@"windowScriptObject document.documentElement.offsetWidth=%@", [[sender windowScriptObject] valueForKeyPath:@"document.documentElement.offsetWidth"]);
	NSLog(@"windowScriptObject frames=%@", [[sender windowScriptObject] evaluateWebScript:@"frames"]);
	NSLog(@"windowScriptObject frames[0]=%@", [[sender windowScriptObject] evaluateWebScript:@"frames[0]"]);
	NSLog(@"styleDeclarationWithText=%@", [[frame webView] styleDeclarationWithText:@"color: red;"]);
#endif
	// and... print subviews hierarchy
#endif
	if(frame == [sender mainFrame])
		{
		NSString *src=[[[[webView mainFrame] dataSource] representation] documentSource];
		[backButton setEnabled:[sender canGoBack]];
		[forwardButton setEnabled:[sender canGoForward]];
		[historyTable reloadData];
		[backForwardTable reloadData];
		[self showStatus:@"Main Frame Done."];
		[currentItem release];
		currentItem=nil;
		[domTree reloadData];
		[domAttribs reloadData];
		[currentCSS release];
		currentCSS=nil;
		[domCSS reloadData];
		currentView=nil;
		[viewTree reloadData];
		[viewAttribs reloadData];
		[styleSheets reloadData];
		if(!src)
			src=@"<no document source available>";
		[docSource setString:src];
		}
	else
		{
		[self showStatus:@"Subframe Done."];
		}
}

- (void) webView:(WebView *) sender willCloseFrame:(WebFrame *) frame
{
#if 1
	NSLog(@"webview=%@ willCloseFrame=%@", sender, frame);
#endif
	// no! should be called in some didCloseFrame:	[[NSApp delegate] removeSubresourcesForFrame:frame];
}

- (id) comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index
{
	return [destinations objectAtIndex:index];
}

- (int) numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	if(!destinations)
		{
		NSString *dir;
		NSString *f;
		NSEnumerator *e;
		destinations=[[NSMutableArray alloc] init];
		[destinations addObject:@"-- rendering and browser tests --"];
		[destinations addObject:@"http://info.cern.ch/hypertext/WWW/TheProject.html"];
		[destinations addObject:@"http://www.mired.org/home/mwm/bugs.html"];
		[destinations addObject:@"http://dillo.rti-zone.org/Html.testsuite/"];
		[destinations addObject:@"http://www.webstandards.org/files/acid2/test.html"];
		[destinations addObject:@"http://acid3.acidtests.org/"];
		[destinations addObject:@"http://whatsmyuseragent.com/"];
		[destinations addObject:@"http://www.html5test.com/"];
		[destinations addObject:@"-- JavaScript (speed) --"];
		[destinations addObject:@"http://celtickane.com/webdesign/jsspeed2007.php"];
		[destinations addObject:@"http://pentestmonkey.net/jsbm/index.html"];
		[destinations addObject:@"http://www.hixie.ch/tests/adhoc/perf/dom/artificial/core/001.html"];
		[destinations addObject:@"http://andrewdupont.net/test/double-dollar/"];
		[destinations addObject:@"http://maps.google.com/maps?z=16&ll=48.137583,11.57444&spn=0.009465,0.029998&t=k&om=1"];
		[destinations addObject:@"javascript:alert(\"hello world.\")"];	// special URL
		[destinations addObject:@"http://lcamtuf.coredump.cx/cross_fuzz/"];	// DOM fuzzing security check
		[destinations addObject:@"-- CSS --"];
		[destinations addObject:@"http://www.compucraft.com.au/dev/DisableStyles.htm"];		
		[destinations addObject:@"-- important public pages --"];
		[destinations addObject:@"http://www.quantum-step.com"];
		[destinations addObject:@"http://www.gnustep.org"];
		[destinations addObject:@"http://www.gnustep.org/resources/documentation/Developer/Base/Reference/index.html"];
		[destinations addObject:@"http://wiki.gnustep.org/index.php/SimpleWebKit"];
		[destinations addObject:@"http://www.w3.org/"];
		[destinations addObject:@"http://de.selfhtml.org/html/xhtml/unterschiede.htm#verweise_anker"];
		[destinations addObject:@"http://pda.leo.org/"];
		[destinations addObject:@"http://www.google.com"];
		[destinations addObject:@"http://www.google.de"];
		[destinations addObject:@"http://www.apple.com"];
		[destinations addObject:@"http://www.apple.de"];
		[destinations addObject:@"http://www.yahoo.de"];
		[destinations addObject:@"http://carduus.chanet.de/"];
		[destinations addObject:@"http://gutenberg.chanet.de/eindex.html"];
		[destinations addObject:@"http://mobile.bahn.de/bin/mobil/"];
		[destinations addObject:@"-- non-HTTP/HTML --"];
		[destinations addObject:@"ftp://ftp.gnu.org/pub/gnu"];
		[destinations addObject:@"http://www.w3schools.com/xml/plant_catalog.xml"];
		[destinations addObject:@"file:///Developer/ADC%20Reference%20Library/index.html"];
		[destinations addObject:@"http://www.osxentwicklerforum.de/mobile/"];
		[destinations addObject:@"-- local tests and demos --"];
		dir=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"DemoHTML"];
		e=[[[NSFileManager defaultManager] directoryContentsAtPath:dir] objectEnumerator];
		while((f=[e nextObject]))
			[destinations addObject:[NSString stringWithFormat:@"test:%@", f]];
		// [destinations addObject:@""];
		}
	return [destinations count];
}

- (DOMStyleSheetList *) styleSheet;
{
	DOMHTMLDocument *doc=(DOMHTMLDocument *) [[webView mainFrame] DOMDocument];
	if(![doc respondsToSelector:@selector(styleSheets)])	// FIXME: work around bug in SWK
		doc=(DOMHTMLDocument *) [doc firstChild];
	return [doc styleSheets];
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *ident=[tableColumn identifier];
	if(outlineView == styleSheets)
		{
#if 0
		NSLog(@"adding %p", item);
#endif
#if 0
		if([item respondsToSelector:@selector(cssText)])
			NSLog(@"%@", [(DOMCSSRule *) item cssText]);
#endif
		if([ident isEqual: @"name"])
			return NSStringFromClass([item class]);
		if([item isKindOfClass:[NSString class]])
			return item;
		if([item respondsToSelector:@selector(cssText)])
			return [(DOMCSSRule *) item cssText];
		if([item respondsToSelector:@selector(styleSheet)])
			return [(DOMCSSImportRule *) item styleSheet];	// @import rule
		if([item respondsToSelector:@selector(href)])
			return [(DOMCSSStyleSheet *) item href];
		return @"";
		}
	if(outlineView == domTree)
		{
#if 0
		NSLog(@"2 document=%p", [[webView mainFrame] DOMDocument]);
		NSLog(@"3 document=%p", [[webView mainFrame] DOMDocument]);
		NSLog(@"3 refs=%u", [[[webView mainFrame] DOMDocument] retainCount]);
		NSLog(@"item=%p", item);
		NSLog(@"4 refs=%u", [item retainCount]);
#endif
		if([ident isEqual: @"name"])
			return [item nodeName];
		else if([ident isEqual: @"class"])
			return NSStringFromClass([item class]);
		else if([ident isEqual: @"value"])
			return [item nodeValue];
		}
	else if(outlineView == viewTree)
		{
		if([ident isEqual: @"class"])
			return NSStringFromClass([item class]);
		else if([ident isEqual: @"frame"])
			{
			NSRect frame=[item frame];
			return [NSString stringWithFormat:@"[(%.1f, %.1f), (%.1f, %.1f)]", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
			}
		else if([ident isEqual: @"flags"])
			{ // show some standard attributes
				NSMutableString *s;
				s=[NSMutableString stringWithFormat:@"autores=%08x", [item autoresizingMask]];
				if([item autoresizesSubviews])
					[s appendFormat:@", autoSubviews"];
				if([item isFlipped])
					[s appendFormat:@", isFlipped"];
				if([item isOpaque])
					[s appendFormat:@", isOpaque"];
				return s;
			}
		}
	return ident;
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if(outlineView == styleSheets)
		{
		id oitem=item;
		if(item == nil)
			item=[self styleSheet];
		if([item respondsToSelector:@selector(item:)])
			item=[(DOMStyleSheetList *) item item:index];
		else if([item respondsToSelector:@selector(cssRules)])
			item=[[(DOMCSSStyleSheet *) item cssRules] item:index];	// style sheet or @media rule
		else if([item respondsToSelector:@selector(styleSheet)])
			{
			item=[(DOMCSSImportRule *) item styleSheet];	// @import rule
			if(!item)
				item=@"@import with nil styleSheet";
			}
		else
			item=@"unknown";
#if 0
		NSLog(@"adding %@ %p", item, item);
#endif
		if(item == nil)
			NSLog(@"oitem %@ %p", oitem, oitem);
		else
			[styleNodes addObject:item];
		return item;
		}
	if(outlineView == domTree)
		{
		id obj;
#if 0
		NSLog(@"4 document=%p", [[webView mainFrame] DOMDocument]);
#endif
		if (item == nil)
			obj=[[webView mainFrame] DOMDocument];
		else
			obj = [[(DOMNode *) item childNodes] item:index];
		[domNodes addObject:obj];	// retain them whatever happens
		return obj;
		}
	else if(outlineView == viewTree)
		{
		if (item == nil)
			item=[[[webView window] contentView] superview];
		if (item == nil)
			item=[[webView window] contentView];	// system has no private superview
		return [[item subviews] objectAtIndex:index];
		}
	return nil;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	[self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if(outlineView == styleSheets)
		{
		if(item == nil)
			{
			[styleNodes release];
			styleNodes=[[NSMutableArray alloc] initWithCapacity:30];
			item=[self styleSheet];
			}
		if([item isKindOfClass:[NSString class]])
			return 0;	// error handling
		if([item respondsToSelector:@selector(length)])
			return [(DOMStyleSheetList *) item length];
		if([item respondsToSelector:@selector(cssRules)])
			return [[(DOMCSSStyleSheet *) item cssRules] length];	// style sheet or @import rule
		if([item respondsToSelector:@selector(styleSheet)])
			return 1;	// @media rule
		return 0;
		}
	if(outlineView == domTree)
		{
		if (item == nil)
			{
			[domNodes release];
			domNodes=[[NSMutableArray alloc] initWithCapacity:30];
			return 1;
			}
		else
			return [[(DOMNode *) item childNodes] length];
		}
	else if(outlineView == viewTree)
		{
		if (item == nil)
			item=[[[webView window] contentView] superview];
		if (item == nil)
			item=[[webView window] contentView];	// system has no private superview
		return [[item subviews] count];
		}
	return 0;
}

- (void) outlineViewSelectionDidChange:(NSNotification *)notification
{ 
	NSOutlineView *outlineView = [notification object];
	int selectedRow = [outlineView selectedRow];
	id selectedItem = [outlineView itemAtRow:selectedRow];
	if(outlineView == domTree)
		{
		DOMCSSStyleDeclaration *css;
		if([selectedItem isKindOfClass:[DOMText class]])
			{
			[domSource setString:[selectedItem nodeValue]];
			[currentItem release];
			currentItem=nil;
			[currentCSS release];
			currentCSS=nil;
			}
		else 
			{
			if([selectedItem respondsToSelector:@selector(outerHTML)])
				{
				[domSource setString:[selectedItem outerHTML]];
				[currentItem release];
				currentItem=[selectedItem retain];
				}
			else if([selectedItem respondsToSelector:@selector(innerHTML)])
				{
				[domSource setString:[selectedItem innerHTML]];
				[currentItem release];
				currentItem=[selectedItem retain];
				}
			[currentCSS release];
			currentCSS=[webView computedStyleForElement:currentItem pseudoElement:@""];
			[currentCSS retain];
			}
		[domAttribs reloadData];
		[domCSS reloadData];
		}
	else if(outlineView == viewTree)
		{
		currentView=selectedItem;
		[viewAttribs reloadData];
		}
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(aTableView == backForwardTable)
		{
		return [[webView backForwardList] backListCount] + [[webView backForwardList] forwardListCount] + 1; 
		}
	if(aTableView == historyTable)
		{
		int nitems=0;
		NSEnumerator *e=[[[WebHistory optionalSharedHistory] orderedLastVisitedDays] objectEnumerator];
		NSCalendarDate *day;
		while((day=[e nextObject]))
			{
			nitems+=[[[WebHistory optionalSharedHistory] orderedItemsLastVisitedOnDay:day] count];
			}
		return nitems;
		}
	if(aTableView == domAttribs)
		{
		if([currentItem respondsToSelector:@selector(attributes)])
			return [[(DOMElement *) currentItem attributes] length];
		return 1;
		}
	if(aTableView == domCSS)
		{
		return [currentCSS length];
		}
	if(aTableView == viewAttribs)
		{
		if(!currentView)
			return;
		if(!viewAttribNames)
			{
			[currentView class];
			// check currentView for attributes and convert into two arrays
			// this either needs a table for each class or a generic walk through all available getters!
			}
		return [viewAttribNames	count];
		}
	return 0;
}

- (IBAction) singleClick:(id) sender;
{
}

- (IBAction) doubleClick:(id) sender;
{ // open URL if double click into CSS url
	if(sender == domTree)
		{ // click onto DOM tree node
		DOMNode *refNode=[sender itemAtRow:[sender clickedRow]];
		NS_DURING
			// can't -init a DOMRange since it is connected to a DOMDocument!
			DOMRange *rng=[[[webView mainFrame] DOMDocument] createRange];
			[rng selectNode:refNode];
			[webView setSelectedDOMRange:rng affinity:NSSelectionAffinityDownstream];
		NS_HANDLER
			NSLog(@"can't select: %@", localException);
		NS_ENDHANDLER
		}
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *ident=[aTableColumn identifier];
	if(aTableView == backForwardTable)
		{
		int idx=rowIndex-[[webView backForwardList] backListCount];
		NSString *title;
		WebHistoryItem *item;
		if([ident isEqual: @"number"])
			return [NSString stringWithFormat:@"%d", idx];
		item=[[webView backForwardList] itemAtIndex:idx];
		title=[item alternateTitle];
		if(!title)
			title=[item title];	// no alternate title
		if(!title)
			title=[item URLString];	// no title
		if(!title)
			title=@"?";
		return title;
		}
	if(aTableView == historyTable)
		{
		// return date / title
		return @"?";
		}
	if(aTableView == domAttribs)
		{
		if([currentItem respondsToSelector:@selector(attributes)])
			{
			if([ident isEqual: @"attribute"])
				return [(DOMAttr *) [[(DOMElement *) currentItem attributes] item:rowIndex] name];
			else if([ident isEqual: @"value"])
				return [(DOMAttr *) [[(DOMElement *) currentItem attributes] item:rowIndex] value];			
			}
		return @"can't display";
		}
	if(aTableView == domCSS)
		{
		NSString *prop=[(DOMCSSStyleDeclaration *) currentCSS item:rowIndex];
		if([ident isEqual: @"property"])
			return prop;
		else if([ident isEqual: @"value"])
			return [(DOMCSSStyleDeclaration *) currentCSS getPropertyValue:prop];
		return @"can't display";
		}
	if(aTableView == viewAttribs)
		{
		//				NSMutableArray *viewAttribNames;
		//			NSMutableArray *viewAttribValues;				
		}
	return @"";
}

- (IBAction) cancelBookmark:(id) sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	[addBookmarkWindow orderOut:sender];
}

- (IBAction) saveBookmark:(id) sender
{
	[NSApp stopModalWithCode:NSOKButton];
	[addBookmarkWindow orderOut:sender];
}

- (IBAction) addBookmark:(id) sender;
{
	NSString *title=[[[webView mainFrame] dataSource] pageTitle];
	[bookmarkURL setStringValue:[currentURL stringValue]];
	if(title)
		[bookmarkTitle setStringValue:title]; 
	if([NSApp runModalForWindow:addBookmarkWindow] == NSOKButton)
		[[NSApp delegate] addBookmark:[bookmarkTitle stringValue] forURL:[bookmarkURL stringValue]];
}

@end
