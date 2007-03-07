//
//  WebBackForwardList.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue May 16 2006.
//  Copyright (c) 2006 DSITRI. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebBackForwardList.h>
#import <WebKit/WebHistoryItem.h>

@implementation WebBackForwardList

- (void) addItem:(WebHistoryItem *) item;
{
	// limit to capacity
	// if first on forward list - keep
	NIMP;
}

- (WebHistoryItem *) backItem; { return [_backList count] > 0?[_backList objectAtIndex:0]:nil; }
- (int) backListCount; { return [_backList count]; }
- (NSArray *) backListWithLimit:(int) limit; { return NIMP; }
- (int) capacity; { return _capacity; }
- (BOOL) containsItem:(WebHistoryItem *) item; { return item==_currentItem || [_backList indexOfObjectIdenticalTo:item] || [_forwardList indexOfObjectIdenticalTo:item]; }
- (WebHistoryItem *) currentItem; { return _currentItem; }
- (WebHistoryItem *) forwardItem; { return [_forwardList count] > 0?[_forwardList objectAtIndex:0]:nil; }
- (int) forwardListCount; { return [_forwardList count]; }
- (NSArray *) forwardListWithLimit:(int) limit; { return NIMP; }
- (void) goBack; { [self goToItem:[self backItem]]; }
- (void) goForward; { [self goToItem:[self forwardItem]]; }

- (void) goToItem:(WebHistoryItem *) item;
{
	// make it the current
	NIMP;
}

- (id) init;
{
	if((self=[super init]))
		{
		_backList=[[NSMutableArray alloc] initWithCapacity:10];
		_forwardList=[[NSMutableArray alloc] initWithCapacity:10];
		}
	return self;
}

- (void) dealloc;
{
	[_backList release];
	[_forwardList release];
	[_currentItem release];
	[super dealloc];
}

- (WebHistoryItem *) itemAtIndex:(int) index;
{
	if(index == 0)
		return _currentItem;
	if(index > 0)
		{
		if(index > [_forwardList count])
			return nil;
		return [_forwardList objectAtIndex:index-1];
		}
	else
		{
		if(-index > [_backList count])
			return nil;
		return [_backList objectAtIndex:-index-1];
		}
}

- (unsigned) pageCacheSize; { return _pageCacheSize; }
- (void) setCapacity:(int) size; { _capacity=size; }
- (void) setPageCacheSize:(unsigned) size; { _pageCacheSize=size; }

@end