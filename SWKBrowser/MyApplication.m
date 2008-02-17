//
//  MyApplication.m
//
//  Created by Dr. H. Nikolaus Schaller on Sun Aug 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "MyApplication.h"
#import "MyDocument.h"

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

@end

@implementation MyApplication

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
			id <NSMenuItem> m;
			NSString *title=[item alternateTitle];
			if(!title)
				title=[item title];	// no alternate title
			if(!title)
				title=[item URLString];	// no title
			if(idx < end)
				{ // replace existing entries
				m=(id <NSMenuItem>) [menu itemAtIndex:idx++];
				[m setTitle:title];
				[m setAction:@selector(loadPageFromHistoryItem:)];
				}
			else	// add a new one
				m=[menu insertItemWithTitle:title action:@selector(loadPageFromHistoryItem:) keyEquivalent:@"" atIndex:idx], end=++idx;	// target=nil, i.e. first responder
			[m setRepresentedObject:item];
			}
		// may handle group-by-day by creating submenus
		}
	while(idx < end)
		[menu removeItemAtIndex:idx], end--;	// if new list is shorter
}

- (void) saveHistory;
{
	NSError *error;
	[[NSFileManager defaultManager] createDirectoryAtPath:[HISTORY_PATH stringByDeletingLastPathComponent] attributes:nil];	// create directory (ignore errors)
	if(![[WebHistory optionalSharedHistory] saveToURL:[NSURL fileURLWithPath:HISTORY_PATH] error:&error])
		;	// silently ignore errors
}

- (void) awakeFromNib
{
	NSError *error;
    WebHistory *myHistory = [[[WebHistory alloc] init] autorelease];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
#if 1
	NSLog(@"AppController awakeFromNib");
//	NSLog(@"%@", [[NSDocumentController sharedDocumentController] defaultType]);
#endif
    [WebHistory setOptionalSharedHistory:myHistory];
	if(![myHistory loadFromURL:[NSURL fileURLWithPath:HISTORY_PATH] error:&error])
		; // siltently ignore errors
	[self updateHistoryMenu];
    [nc addObserver:self selector:@selector(historyDidRemoveAllItems:)
               name:WebHistoryAllItemsRemovedNotification object:myHistory];
    [nc addObserver:self selector:@selector(historyDidAddItems:)
               name:WebHistoryItemsAddedNotification object:myHistory];
    [nc addObserver:self selector:@selector(historyDidRemoveItems:)
               name:WebHistoryItemsRemovedNotification object:myHistory];
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
	NSLog(@"%@ identifierForInitialRequest: %@", src, request);
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
	NSLog(@"%@ subres %@ didFailLoadingWithError: %@", src, ident, error);
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didFinishLoadingFromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didFinishLoadingFromDataSource];
	NSLog(@"%@ subres %@ didFinishLoadingFromDataSource", src, ident);
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didReceiveContentLength:(unsigned) len fromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didReceiveContentLength:len];
	NSLog(@"%@ subres %@ didReceiveContentLength: %u", src, ident, len);
	[self updateActivity];
}

- (void) webView:(WebView *) sender resource:(id) ident didReceiveResponse:(NSURLResponse *) resp fromDataSource:(WebDataSource *) src;
{
	[(SubResource *) ident didReceiveResponse:resp];
	NSLog(@"%@ subres %@ didReceiveResponse: %@", src, ident, resp);
	[self updateActivity];
}

// Activity window

// FIXME - handle close of document windows - the oulineview needs to reload data!!!

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
#if 0
	NSLog(@"child:%u %@", index, item);
#endif
	if(item == nil)
		{
		return [[[[[NSDocumentController sharedDocumentController] documents] objectAtIndex:index] webView] mainFrame];
		}
	if([item isKindOfClass:[WebFrame class]])
		{
		unsigned children=[[(WebFrame *) item childFrames] count];
		if(index < children)
			return [[(WebFrame *) item childFrames] objectAtIndex:index];
		return [activities objectAtIndex:index-children]; // get i-th data source
		}
	return nil;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if(item == nil)
		{
		return [[[NSDocumentController sharedDocumentController] documents] count];
		}
	if([item isKindOfClass:[WebFrame class]])
		{
		return [[(WebFrame *) item childFrames] count] +									// subframes
						[activities count];	// and our subresources
		}
	return 0;
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *ident=[tableColumn identifier];
#if 0
	NSLog(@"display %@", item);
#endif
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

@end
