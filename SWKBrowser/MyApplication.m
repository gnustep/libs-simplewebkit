//
//  MyApplication.m
//
//  Created by Dr. H. Nikolaus Schaller on Sun Aug 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "MyApplication.h"
#import "MyDocument.h"

@interface WebPreferences (Private)

- (BOOL) authorAndUserStylesEnabled;
- (void) setAuthorAndUserStylesEnabled:(BOOL) flag;
- (BOOL) developerExtrasEnabled;
- (void) setDeveloperExtrasEnabled:(BOOL) flag;

@end

// this is used to track subresources
// we carry an array of these objects to show the Activity window

@interface SubResource : NSObject
{
	WebDataSource *datasrc;		// this is always the main resource!
	NSURLRequest *req;
	NSURLResponse *resp;
	NSError *error;
	long long totalBytesExpected;
	unsigned bytesReceived;
	BOOL done;
}

- (id) initWithDataSource:(WebDataSource *) src andRequest:(NSURLRequest *) r;
- (void) didFailLoadingWithError:(NSError *) error;
- (void) didFinishLoadingFromDataSource;
- (void) didReceiveContentLength:(unsigned) len;
- (void) didReceiveResponse:(NSURLResponse *) resp;
- (NSString *) objectValueForKey:(NSString *) ident;
- (BOOL) isForWebFrame:(WebFrame *) frame;

@end

@implementation SubResource

- (id) initWithDataSource:(WebDataSource *) src andRequest:(NSURLRequest *) r;
{
	if((self=[super init]))
		{
		datasrc=[src retain];
		req=[r retain];
		totalBytesExpected=-1;
		}
	return self;
}

- (void) dealloc;
{
	[resp release];
	[req release];
	[datasrc release];
	[error release];
	[super dealloc];
}

- (NSString *) description;
{
	NSURL *url=[resp URL];
	if(!url)
		url=[req URL];
	return [NSString stringWithFormat:@"%u of %d for %@%@", bytesReceived, (int) totalBytesExpected, url, done?@" done":@""];
}

- (void) didFailLoadingWithError:(NSError *) e;
{
	error=[e retain];
}

- (void) didFinishLoadingFromDataSource;
{
	done=YES;
}

- (void) didReceiveContentLength:(unsigned) len;
{
	bytesReceived += len;
}

- (void) didReceiveResponse:(NSURLResponse *) r;
{
	resp=[r retain];
	totalBytesExpected=[r expectedContentLength];
}

- (NSString *) bytes:(unsigned) val;
{
	if(val < 100)
		return [NSString stringWithFormat:@"%u Byte", val];
	if(val < 100000)
		return [NSString stringWithFormat:@"%.1f kB", val/1024.0];
	return [NSString stringWithFormat:@"%.1f MB", val/(1024.0*1024.0)];
}

- (NSString *) objectValueForKey:(NSString *) ident;
{
#if 0
	NSLog(@"key %@ of %@", ident, self);
#endif
	if([ident isEqualToString:@"address"])
		{
		if(resp)
			return [[resp URL] absoluteString];
		return [[req URL] absoluteString];
		}
	else
		{ // status
		if(error)
			return [error localizedDescription];
		if(![datasrc response])
			return @"no response";
		if(done)
			return [NSString stringWithFormat:@"%@", [self bytes:bytesReceived]];
		if(totalBytesExpected >= 0)
			return [NSString stringWithFormat:@"%@ of %@", [self bytes:bytesReceived], [self bytes:(unsigned) totalBytesExpected]];
		return [NSString stringWithFormat:@"%@ bytes of ?", [self bytes:bytesReceived]];	// still unknown
		}
}

- (BOOL) isForWebFrame:(WebFrame *) frame;
{
	return [datasrc webFrame] == frame;
}

@end

@implementation MyApplication

- (NSString *) plistPath:(NSString *) database	// History.plist, Bookmarks.plist, Downloads.plist
{
	return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]] stringByAppendingPathComponent:database];
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *) sender;
{
	return YES;
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *) app;
{
	return NO;
}

- (void) applicationDidFinishLaunching:(NSNotification *) n
{
#if 1
	NSLog(@"AppController applicationDidFinishLaunching");
#endif
	[[activity window] makeKeyAndOrderFront:nil];
}

- (void) updateHistoryMenu;
{
	NSEnumerator *e=[[[WebHistory optionalSharedHistory] orderedLastVisitedDays] objectEnumerator];
	NSMenu *menu=[separatorAfterHistory menu];
	int end=[menu indexOfItem:separatorAfterHistory];
	int idx=[menu indexOfItem:separatorBeforeHistory]+1;
	NSCalendarDate *day;
	while((day=[e nextObject]))
		{
		NSEnumerator *f=[[[WebHistory optionalSharedHistory] orderedItemsLastVisitedOnDay:day] objectEnumerator];
		WebHistoryItem *item;
		while((item=[f nextObject]))
			{
			NSMenuItem *m;
			NSString *title=[item alternateTitle];
			if(!title)
				title=[item title];	// no alternate title
			if(!title)
				title=[item URLString];	// no title
			if(idx < end)
				{ // replace existing entries
				m=[menu itemAtIndex:idx++];
				[m setTitle:title];
				[m setAction:@selector(loadPageFromHistoryItem:)];
				}
			else
				{ // add a new one
				m=[menu insertItemWithTitle:title action:@selector(loadPageFromHistoryItem:) keyEquivalent:@"" atIndex:idx];
				end=++idx;	// target=nil, i.e. first responder
				}
			[m setRepresentedObject:item];
			}
		// may/should handle group-by-day by creating submenus
		}
	while(idx < end)
		[menu removeItemAtIndex:idx], end--;	// if new list is shorter
}

- (void) saveHistory;
{
	NSError *error;
	[[NSFileManager defaultManager] createDirectoryAtPath:[[self plistPath:@"History.plist"] stringByDeletingLastPathComponent] attributes:nil];	// create directory (ignore errors)
	if(![[WebHistory optionalSharedHistory] saveToURL:[NSURL fileURLWithPath:[self plistPath:@"History.plist"]] error:&error])
		;	// silently ignore errors
}

- (void) updateBookmarksMenuItem:(NSMenuItem *) item forBookmark:(NSDictionary *) bm;
{
	if([bm objectForKey:@"Children"])
			{ // has children
				// make item have a sumbenu
				// populate submenu
			}
}

- (void) updateBookmarksMenu
{
//	NSMenu *menu=[separatorAfterBookmarks menu];
	// go through all root element children
	// start behind separator
	[self updateBookmarksMenuItem:nil forBookmark:bookmarks];
	// make list longer/shorter
}

- (void) saveBookmarks;
{
	[self updateBookmarksMenu];
	[bookmarks writeToFile:[self plistPath:@"Bookmarks.plist"] atomically:YES];
	[bookmarksTable reloadData];
}

- (void) awakeFromNib
{
	NSError *error;
	WebHistory *myHistory = [[[WebHistory alloc] init] autorelease];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
#if 1
	NSLog(@"AppController awakeFromNib");
	//	NSLog(@"%@", [[NSDocumentController sharedDocumentController] defaultType]);
	NSLog(@"AppController bookmarks %@", [self plistPath:@"Bookmarks.plist"]);
	NSLog(@"AppController history %@", [self plistPath:@"History.plist"]);
#endif
	[[WebPreferences standardPreferences] setPrivateBrowsingEnabled:NO];	// disable whatever it was set to on relaunch...
	[WebHistory setOptionalSharedHistory:myHistory];
	if(![myHistory loadFromURL:[NSURL fileURLWithPath:[self plistPath:@"History.plist"]] error:&error])
		; // silently ignore errors
	[self updateHistoryMenu];
	[nc addObserver:self selector:@selector(historyDidRemoveAllItems:)
						 name:WebHistoryAllItemsRemovedNotification object:myHistory];
	[nc addObserver:self selector:@selector(historyDidAddItems:)
						 name:WebHistoryItemsAddedNotification object:myHistory];
	[nc addObserver:self selector:@selector(historyDidRemoveItems:)
						 name:WebHistoryItemsRemovedNotification object:myHistory];
	bookmarks=[[NSDictionary alloc] initWithContentsOfFile:[self plistPath:@"Bookmarks.plist"]];
	[bookmarksTable reloadData];
}

/*
	dealloc
		[activities release];
*/

- (void) historyDidRemoveAllItems:(NSNotification *) n
{
	[self updateHistoryMenu];
	[self saveHistory];
}

- (void) historyDidAddItems:(NSNotification *) n
{
	[self updateHistoryMenu];
	[self saveHistory];
}

- (void) historyDidRemoveItems:(NSNotification *) n
{
	[self updateHistoryMenu];
	[self saveHistory];
}

- (IBAction) loadPageFromHistoryItem:(id) historyItem
{ // no active document!
	id myDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"" display:YES];
	[myDocument loadPageFromHistoryItem:historyItem];
}

- (IBAction) clearHistory:(id) sender
{
    [[WebHistory optionalSharedHistory] removeAllItems];	// will post a notification
}

- (void) updateActivity
{
#if 1
	NSLog(@"activities=%@", activities);
#endif
	[activity reloadData];
//	[[currentURL controlView] setNeedsDisplay:YES];	// update to show progress
}

// use these to track resource loading!

- (id) webView:(WebView *) sender identifierForInitialRequest:(NSURLRequest *) request fromDataSource:(WebDataSource *) src;
{
	SubResource *s=[[[SubResource alloc] initWithDataSource:src andRequest:request] autorelease];
#if 1
	NSLog(@"%@ identifierForInitialRequest: %@", src, request);
#endif
	if(!activities)
			activities=[[NSMutableArray arrayWithCapacity:10] retain];
	[activities addObject:s];
	[self updateActivity];
	return s;	// new activity tracker
}

// update Load... (%u of %u objects)

- (void) webView:(WebView *) sender resource:(id) ident didFailLoadingWithError:(NSError *) error fromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didFailLoadingWithError:error];
#if 1
	NSLog(@"%@ subres %@ didFailLoadingWithError: %@", src, ident, error);
#endif
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didFinishLoadingFromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didFinishLoadingFromDataSource];
#if 1
	NSLog(@"%@ subres %@ didFinishLoadingFromDataSource", src, ident);
#endif
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didReceiveContentLength:(unsigned) len fromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didReceiveContentLength:len];
#if 1
	NSLog(@"%@ subres %@ didReceiveContentLength: %u", src, ident, len);
#endif
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didReceiveResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didReceiveResponse:resp];
#if 1
	NSLog(@"%@ subres %@ didReceiveResponse: %@", src, ident, resp);
#endif
	[self updateActivity];
}

// forwarded from MyDocument:

- (void) removeSubresourcesForFrame:(WebFrame *) frame
{
	int i=[activities count];
	while(i-- > 0)
			{ // delete all subresources that refer to the same frame
				SubResource *r=[activities objectAtIndex:i];
				if([r isForWebFrame:frame])
					[activities removeObjectAtIndex:i];
			}
	[self updateActivity];
}

// Activity window

// FIXME - handle close of document windows - the outlineview needs to reload data!!!
//
// FIXME: we should use a completely different approach!
// first level are all WebViews (Documents)
// next level(s) are all WebFrames
// wnd there we list the webFrame provisionalSource or dataSource
// and all its subresources (whether loading or not loading)
// i.e. we simply query the WebKit model

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
#if 0
	NSLog(@"child:%u %@", index, item);
#endif
	if(outlineView == activity)
			{
				if(item == nil)
						{
							return [[[[[NSDocumentController sharedDocumentController] documents] objectAtIndex:index] webView] mainFrame];
						}
				if([item isKindOfClass:[WebDataSource class]])
						{
							return [[(WebDataSource *) item subresources] objectAtIndex:index];
						}
				if([item isKindOfClass:[WebFrame class]])
						{
							unsigned children=[[(WebFrame *) item childFrames] count];
							if(index < children)
								return [[(WebFrame *) item childFrames] objectAtIndex:index];
							return [activities objectAtIndex:index-children]; // get i-th data source
						}
			}
	if(outlineView == bookmarksTable)
			{
				if(item == nil)
					item=bookmarks;	// root object
				return [[item objectForKey:@"Children"] objectAtIndex:index];
			}
	return nil;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
		return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if(outlineView == activity)
			{
				if(item == nil)
						{
							return [[[NSDocumentController sharedDocumentController] documents] count];
						}
				if([item isKindOfClass:[WebDataSource class]])
						{
							return [[(WebDataSource *) item subresources] count];
						}
				if([item isKindOfClass:[WebFrame class]])
						{
							return [[(WebFrame *) item childFrames] count] +									// subframes
							[activities count];	// and our subresources
						}
			}
	if(outlineView == bookmarksTable)
			{
				if(item == nil)
					item=bookmarks;	// root object
				return [[item objectForKey:@"Children"] count];
			}
	return 0;
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *ident=[tableColumn identifier];
#if 0
	NSLog(@"display %@", item);
#endif
	if(outlineView == activity)
			{
				if([item isKindOfClass:[WebDataSource class]])
						{
							WebDataSource *src=(WebDataSource *) item;
							if([ident isEqualToString:@"address"])
									{
										if([src response])
											return [[[src response] URL] absoluteString];
										return [[[src request] URL] absoluteString];
									}
							else
									{ // status
										// error status???
										return [NSString stringWithFormat:@"%@", [[src data] length]];
									}
						}
				if([item isKindOfClass:[WebFrame class]])
						{
							WebDataSource *src=[(WebFrame *) item dataSource];
							if([ident isEqualToString:@"address"])
									{
										NSString *title=[src pageTitle];
										if(!title)
											title=[[[src response] URL] absoluteString];
										if(!title)
											title=[[[src initialRequest] URL] absoluteString];
										if(!title)
											title=@"unknown";
										return title;
									}
							else
									{
										return [NSString stringWithFormat:@"%u Objects", 1+[[src subresources] count]];
									}
						}
				if([item isKindOfClass:[SubResource class]])
					return [(SubResource *) item objectValueForKey:ident];
				return NSStringFromClass([item class]);
			}
	if(outlineView == bookmarksTable)
			{
				if(!ident) ident=@"";
				if([[item objectForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeLeaf"])
					return [[item objectForKey:@"URIDictionary"] objectForKey:ident];	// @"" or @"title"
				if([[item objectForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeList"])
						{
							if([ident isEqualToString:@"title"])
								return [item objectForKey:@"Title"];
							return @"";
						}
			}
	return @"?";
}

- (void) outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *ident=[tableColumn identifier];
	if(outlineView == bookmarksTable)
			{
				if(!ident) ident=@"";
				if([[item objectForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeLeaf"])
						{
							[[item objectForKey:@"URIDictionary"] setObject:object forKey:ident];	// @"" or @"title"
							[self saveBookmarks];
						}
				else if([[item objectForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeList"])
						{
							if([ident isEqualToString:@"title"])
									{
										[item setObject:object forKey:@"Title"];
										[self saveBookmarks];
									}
						}
			}
}

// double click -> go to link
// single click -> select
// 2 single clicks -> start editing

- (IBAction) singleClick:(id) sender;
{
#if 1
	NSLog(@"single clicked item=%@", [sender itemAtRow:[sender clickedRow]]);
#endif
	if([sender clickedRow] < 0)
		return;	// outside
	if(sender == bookmarksTable)
			{ // click on item
				if([sender clickedRow] == [sender selectedRow])
						{ // was already selected: start editing
							[sender editColumn:[sender clickedColumn] row:[sender clickedRow] withEvent:nil select:NO];
						}
			}
}

- (IBAction) doubleClick:(id) sender;
{
	NSString *url=[[[sender itemAtRow:[sender clickedRow]] objectForKey:@"URIDictionary"] objectForKey:@""];
#if 1
	NSLog(@"double clicked item=%@", [sender itemAtRow:[sender clickedRow]]);
#endif
	if([sender clickedRow] < 0)
		return;	// outside
// get clicked item
// if leaf - extract url
// and open
}

- (IBAction) showBookmarks:(id) sender;
{
	[bookmarksPanel orderFront:sender]; 
}

// addBookmarkToRecord

- (void) addBookmarkChild:(NSMutableDictionary *) child toRecord:(NSMutableDictionary *) list;
{ // add a node
	NSMutableArray *children=[list objectForKey:@"Children"];
	if(!children)
			{
				[list setObject:children=[NSMutableArray arrayWithCapacity:5] forKey:@"Children"];
				[list setObject:@"WebBookmarkTypeList" forKey:@"WebBookmarkType"];
			}
	[children addObject:child];
}

- (void) addList:(NSString *) title toRecord:(NSMutableDictionary *) list;
{ // add a title node
	NSMutableDictionary *record=[NSMutableDictionary dictionaryWithObjectsAndKeys:
															 title, @"Title",
															 @"WebBookmarkTypeList", @"WebBookmarkType",
															 [[NSProcessInfo processInfo] globallyUniqueString], @"WebBookmarkUUID",
															 nil];
	[self addBookmarkChild:record toRecord:list];
}

- (void) addBookmark:(NSString *) title forURL:(NSString *) str toRecord:(NSMutableDictionary *) list;
{ // add a leaf node
	NSMutableDictionary *record=[NSMutableDictionary dictionaryWithObjectsAndKeys:
															 [NSMutableDictionary dictionaryWithObjectsAndKeys:title, @"title", str, @"", nil], @"URIDictionary",
															 str, @"URLString",
															 @"WebBookmarkTypeLeaf", @"WebBookmarkType",
															 [[NSProcessInfo processInfo] globallyUniqueString], @"WebBookmarkUUID",
															 nil];
	[self addBookmarkChild:record toRecord:list];
}

- (void) addBookmark:(NSString *) title forURL:(NSString *) str;
{
	title=[title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if([title length] == 0)
		return;	// no title
	if(!bookmarks)
			{ // create root object
				bookmarks=[[NSMutableDictionary alloc] initWithCapacity:10];
				[bookmarks setObject:[NSNumber numberWithInt:1] forKey:@"WebBookmarkFileVersion"];
				[bookmarks setObject:@"Root" forKey:@"WebBookmarkUUID"];
				[bookmarks setObject:@"" forKey:@"Title"];
			}
	[self addBookmark:title forURL:str toRecord:bookmarks];
	[bookmarksPanel orderFront:nil];
	[self saveBookmarks];
}

// could we implement this through KVB?

- (IBAction) showPreferences:(id) sender;
{
	WebPreferences *pref=[WebPreferences standardPreferences];	// all windows share this
	NSString *home=[[NSUserDefaults standardUserDefaults] objectForKey:@"HomePage"];
#if 0
	NSLog(@"prefs = %@: %@", [pref identifier], pref);
	pref=[[WebPreferences alloc] initWithIdentifier:@"test"];
	[pref setAutosaves:YES];
	[pref setJavaScriptEnabled:YES];	// should autosave
	NSLog(@"prefs = %@: %@", [pref identifier], pref);
	NSLog(@"prefs fantasyFontFamily: %@", [pref fantasyFontFamily]);
	pref=[WebPreferences standardPreferences]
#endif
	if(!home) home=@"about:blank";
	[homePref setStringValue:home];
	[loadImagesPref setState:[pref loadsImagesAutomatically]?NSOnState:NSOffState];
	[enableJavaScriptPref setState:[pref isJavaScriptEnabled]?NSOnState:NSOffState];
	[popupBlockerPref setState:![pref javaScriptCanOpenWindowsAutomatically]?NSOnState:NSOffState];
	[privateBrowsingPref setState:[pref privateBrowsingEnabled]?NSOnState:NSOffState];
	[enableCSSPref setState:[pref authorAndUserStylesEnabled]?NSOnState:NSOffState];
	[prefsWindow makeKeyAndOrderFront:sender];
}

// FIXME: this is not called for FormCells if the window is closed!

- (IBAction) prefChanged:(id) sender;
{
	WebPreferences *pref=[WebPreferences standardPreferences];	// all windows share this
	if(sender == [homePref controlView])
			{ // text field
				[[NSUserDefaults standardUserDefaults] setObject:[sender stringValue] forKey:@"HomePage"];
			}
	// this is a little inefficient since it writes unchanged values - we should connect the outlets of the individual checkboxes and change only single attributes
	else if(sender == [loadImagesPref controlView])
			{ // checkbox
				[pref setLoadsImagesAutomatically:[loadImagesPref state] == NSOnState];
				[pref setJavaScriptEnabled:[enableJavaScriptPref state] == NSOnState];
				[pref setJavaScriptCanOpenWindowsAutomatically:[popupBlockerPref state] != NSOnState];
				[pref setPrivateBrowsingEnabled:[privateBrowsingPref state] == NSOnState];
				[pref setAuthorAndUserStylesEnabled:[enableCSSPref state] == NSOnState];
			}
}

- (IBAction) openLocation:(id) sender;
{
	// allow to type an URL and open a new document with this URL
}

@end
