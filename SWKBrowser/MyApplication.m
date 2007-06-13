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

#if OLD
if([ident isEqualToString:@"address"])
{ // title
		return [[[item mainFrame] dataSource] pageTitle];
}
else
{ // status
		NSArray *subs=[[[item mainFrame] dataSource] subresources];
		unsigned count=[subs count];
		unsigned loaded=0;
		int i;
		for(i=0; i<count; i++)
			if(![[subs objectAtIndex:i] isLoading] && [(WebDataSource *) [subs objectAtIndex:i] data])
				loaded++;	// has data and finished loading
		if(loaded == count)
			return [NSString stringWithFormat:@"%u objects", count];
		return [NSString stringWithFormat:@"%u of %u objects", loaded, count];
}
		}
else if([item isKindOfClass:[WebDataSource class]])
{ // assume to be a WebDataSource
		if([ident isEqualToString:@"address"])
			{ // URL
			return [[[item response] URL] absoluteString];
			}
		else
			{ // status
			NSData *data=[[[item webFrame] dataSource] data];
			unsigned len=[data length];	// laoded
			if([item isLoading])
				{
				long long exp=[[[[item webFrame] dataSource] response] expectedContentLength];	// expected
				if(exp > 0)
					return [NSString stringWithFormat:@"%u bytes of %u", len, (unsigned) exp];
				return [NSString stringWithFormat:@"%u bytes of ?", len];	// still unknown
				}
			else if(!data)
				return @"Timeout";	// is not loading but has no data
			return [NSString stringWithFormat:@"%u bytes", len];
			}
}
else
{ // WebResource
		if([ident isEqualToString:@"address"])
			{ // URL
			return [[item URL] absoluteString];
			}
		return [NSString stringWithFormat:@"%u bytes", [[(WebDataSource *) item data] length]];
}
#endif

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
	NSLog(@"AppController applicationDidFinishLaunching");
	[[activity window] makeKeyAndOrderFront:nil];
}

- (void) awakeFromNib
{
	NSLog(@"AppController awakeFromNib");
//	NSLog(@"%@", [[NSDocumentController sharedDocumentController] defaultType]);
}

/* dealloc
	[activities release];
*/

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
