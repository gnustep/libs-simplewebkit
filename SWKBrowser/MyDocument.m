//
//  MyDocument.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 07.04.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"

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
#if 1
	NSLog(@"isflipped=%d %@", [[domTree superview] isFlipped], [domTree superview]);	// is a split view flipped?
	NSLog(@"isflipped=%d %@", [[[domTree superview] superview] isFlipped], [[domTree superview] superview]);	// is a split view flipped?
	NSLog(@"isflipped=%d %@", [[[[domTree superview] superview] superview] isFlipped], [[[domTree superview] superview] superview]);	// is a split view flipped?
#endif
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressStartedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressEstimateChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:WebViewProgressFinishedNotification object:nil];
	[webView setResourceLoadDelegate:[NSApp delegate]];
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
}

- (void) setLocation:(NSURL *) url;
{
	if(!url)
		return;
	[currentURL setStringValue:[url absoluteString]];
}

- (IBAction) home:(id) Sender;
{
#if 1
	[self setLocationAndLoad:[NSURL URLWithString:@"about:blank"]];
#else
	[[webView mainFrame] loadHTMLString:@"<html><head><title>Document Title</title></head><body bgcolor=\"#f0f0f0f0\">Welcome to the GNUstep Web Browser</body></html>" baseURL:nil];
#endif
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
	NSLog(@"status: %@", str);
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
		u=[NSURL URLWithString:str];
	if([[u scheme] length] == 0)
		u=[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", str]];	// try to prefix
#if 1
		NSLog(@"loadPageFromComboBox %@ -> %@", str, u);
#endif
		[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:u]];
}

- (IBAction) loadPageFromMenuItem:(id) sender
{
	NSString *str;
	NSURL *u;
	str=[sender title];
	u=[NSURL URLWithString:str];
	if([[u scheme] length] == 0)
		u=[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", str]];	// try to prefix
#if 1
		NSLog(@"loadPageFromMenuItem %@ -> %@", str, u);
#endif
		[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:u]];
}

- (IBAction) scriptFromMenuItem:(id) sender;
{
	[command setStringValue:[sender title]];
	[self script:command];
}

- (IBAction) showSource:(id) sender
{
	[[docSource window] makeKeyAndOrderFront:sender];
}

- (IBAction) showDOMTree:(id) sender;
{
	[[domTree window] makeKeyAndOrderFront:sender];
	[domNodes release];
	domNodes=nil;
	[domTree reloadData];
}

- (IBAction) openJavaScriptConsole:(id) sender
{
	[[command window] makeKeyAndOrderFront:sender];
}

- (IBAction) script:(id) sender
{ // evaluate java script
	NSString *r=[webView stringByEvaluatingJavaScriptFromString:[sender stringValue]];
	if(!r)
		r=@"<nil>";
	[result setStringValue:r];
	[sender setStringValue:@""];	// clear
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
{
	id myDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"Hypertext Markup Language" display:YES];
	// should we delay displaying until first response is coming in?
	[[[myDocument webView] mainFrame] loadRequest:request];
	return [myDocument webView];
}

- (void) webViewShow:(WebView *)sender
{
	id myDocument = [[NSDocumentController sharedDocumentController] documentForWindow:[sender window]];
	NSLog(@"webViewShow=%@", sender);
	[myDocument showWindows];
}

- (void) webView:(WebView *) sender setFrame:(NSRect) frame;
{
}

- (void) webView:(WebView *) sender setResizable:(BOOL) flag;
{
}

- (void) webView:(WebView *) sender setStatusBarVisible:(BOOL) flag;
{
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
}

- (void) webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	NSURL *url=[[[frame provisionalDataSource] request] URL];
#if 1
	NSLog(@"didStartProvisionalLoadForFrame:%@", frame);
#endif
	if(frame == [sender mainFrame])
		{
		if(url)
			{
			[currentURL setStringValue:[url absoluteString]];
			[self showStatus:@"Loading..."];
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
		NSURL *url=[[[frame provisionalDataSource] request] URL];
		[self setFileName:title];
		if(url)
			[currentURL setStringValue:[url absoluteString]];
		else
			NSLog(@"nil URL?");
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
#if 0	// check JavaScript DOM integration
	NSLog(@"webView JavaScript=%@", [[frame webView] stringByEvaluatingJavaScriptFromString:@"document.documentElement.offsetWidth"]);
	NSLog(@"frame DOMDocument WebScript=%@", [[frame DOMDocument] evaluateWebScript:@"document.documentElement.offsetWidth"]);
	NSLog(@"windowScriptObject=%@", [sender windowScriptObject]);
	NSLog(@"windowScriptObject document=%@", [[sender windowScriptObject] valueForKeyPath:@"document"]);
	NSLog(@"windowScriptObject document.documentElement=%@", [[sender windowScriptObject] valueForKeyPath:@"document.documentElement"]);
	NSLog(@"windowScriptObject document.documentElement.offsetWidth=%@", [[sender windowScriptObject] valueForKeyPath:@"document.documentElement.offsetWidth"]);
#endif
	// and... print subviews hierarchy
#endif
	if(frame == [sender mainFrame])
		{
		[self showStatus:@"Main Frame Done."];
		[domNodes release];
		domNodes=nil;
		[domTree reloadData];
		}
	else
		{
		[self showStatus:@"Subframe Done."];
		}
	// could be moved to showSource
	src=[[[frame dataSource] representation] documentSource];
	if(!src)
		src=@"<no document source available>";
	[docSource setString:src];
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
		[destinations addObject:@"http://www.quantum-step.com"];
		[destinations addObject:@"http://www.gnustep.org"];
		[destinations addObject:@"http://wiki.gnustep.org/index.php/SimpleWebKit"];
		[destinations addObject:@"ftp://ftp.gnu.org/pub/gnu"];
		[destinations addObject:@"http://pda.leo.org/"];
		[destinations addObject:@"http://www.w3.org/"];
		[destinations addObject:@"http://www.google.com"];
		[destinations addObject:@"http://www.google.de"];
		[destinations addObject:@"http://www.apple.com"];
		[destinations addObject:@"http://www.apple.de"];
		[destinations addObject:@"http://www.yahoo.de"];
		[destinations addObject:@"http://carduus.chanet.de/"];
		[destinations addObject:@"http://gutenberg.chanet.de/eindex.html"];
		[destinations addObject:@"http://www.w3schools.com/xml/plant_catalog.xml"];
		[destinations addObject:@"http://www.osxentwicklerforum.de/mobile/"];
		[destinations addObject:@"file:///Developer/ADC%20Reference%20Library/index.html"];
		[destinations addObject:@"http://www.hixie.ch/tests/adhoc/perf/dom/artificial/core/001.html"];
		[destinations addObject:@"http://andrewdupont.net/test/double-dollar/"];
		[destinations addObject:@"http://maps.google.com/maps?z=16&ll=48.137583,11.57444&spn=0.009465,0.029998&t=k&om=1"];
		dir=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"DemoHTML"];
		e=[[[NSFileManager defaultManager] directoryContentsAtPath:dir] objectEnumerator];
		while((f=[e nextObject]))
			[destinations addObject:[NSString stringWithFormat:@"test:%@", f]];
		[destinations addObject:@""];
		}
	return [destinations count];
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *ident=[tableColumn identifier];
    if([ident isEqual: @"name"])
        return [item nodeName];
    else if([ident isEqual: @"class"])
        return NSStringFromClass([item class]);
    else if([ident isEqual: @"value"])
        return [item nodeValue];
    return @"";
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    id obj;
	if (item == nil)
        return [[webView mainFrame] DOMDocument];	
	obj = [[item childNodes] item:index];
	[domNodes addObject:obj];
	return obj;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (item == nil)
        item=[[webView mainFrame] DOMDocument];	// replace by root
    return [[item childNodes] length] > 0;
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil)
        return 1;
    return [[item childNodes] length];
}

- (void) outlineViewSelectionDidChange:(NSNotification *)notification
{ 	
	int selectedRow = [[notification object] selectedRow];
	id selectedItem = [[notification object] itemAtRow:selectedRow];
	if([selectedItem isKindOfClass:[DOMText class]])
		{
		[domSource setString:[selectedItem nodeValue]];
		currentItem=nil;
		}
	else 
		{
		if([selectedItem respondsToSelector:@selector(outerHTML)])
			{
			[domSource setString:[selectedItem outerHTML]];
			currentItem=selectedItem;
			}
		else if([selectedItem respondsToSelector:@selector(innerHTML)])
			{
			[domSource setString:[selectedItem innerHTML]];
			currentItem=selectedItem;
			}
		}
	[domAttribs reloadData];
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	if([currentItem respondsToSelector:@selector(_attributes)])
		return [[(DOMElement *) currentItem _attributes] count];
	return 0;
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *ident=[aTableColumn identifier];
    if([ident isEqual: @"attribute"])
		return [(DOMAttr *) [[(DOMElement *) currentItem _attributes] objectAtIndex:rowIndex] name];
    else if([ident isEqual: @"value"])
		return [(DOMAttr *) [[(DOMElement *) currentItem _attributes] objectAtIndex:rowIndex] value];
	return @"";
}

@end
