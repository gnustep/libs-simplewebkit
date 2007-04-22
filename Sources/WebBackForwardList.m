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
	if(!item)
		[NSException raise:NSInvalidArgumentException format:@"nil item"];
	[_forwardList removeAllObjects];
	if(_currentItem)
		{ // move current item to the backList
		[_backList addObject:_currentItem];
		[_currentItem release];
		if(_capacity > 0 && [_backList count] > _capacity)	// beyond capacity
			[_backList removeObjectAtIndex:0];
		}
	_currentItem=[item retain];
}

- (WebHistoryItem *) backItem; { return [_backList count] > 0?[_backList objectAtIndex:0]:nil; }
- (int) backListCount; { return [_backList count]; }

- (NSArray *) backListWithLimit:(int) limit;
{
	if([_backList count] < limit)
		limit=[_backList count];
	return [_backList subarrayWithRange:NSMakeRange(0, limit)];
}

- (int) capacity; { return _capacity; }
- (BOOL) containsItem:(WebHistoryItem *) item; { return item == _currentItem || [_backList indexOfObjectIdenticalTo:item] || [_forwardList indexOfObjectIdenticalTo:item]; }
- (WebHistoryItem *) currentItem; { return _currentItem; }
- (WebHistoryItem *) forwardItem; { return [_forwardList count] > 0?[_forwardList objectAtIndex:0]:nil; }
- (int) forwardListCount; { return [_forwardList count]; }

- (NSArray *) forwardListWithLimit:(int) limit;
{
	if([_forwardList count] < limit)
		limit=[_forwardList count];
	return [_forwardList subarrayWithRange:NSMakeRange(0, limit)];
}

- (void) goBack; { [self goToItem:[self backItem]]; }
- (void) goForward; { [self goToItem:[self forwardItem]]; }

- (void) goToItem:(WebHistoryItem *) item;
{
	unsigned idx;
	if(item == _currentItem)
		return;	// already there!
	idx=[_backList indexOfObjectIdenticalTo:item];	// is it here?
	if(idx != NSNotFound)
		{ // moving backwards
		[_forwardList insertObject:_currentItem atIndex:0];
		[_currentItem release];
		do
			{ // move items from backList to forwardList
			[_forwardList insertObject:[_backList objectAtIndex:0] atIndex:0];
			[_backList removeObjectAtIndex:0];
			} while(idx-- > 0);
		_currentItem=[item retain];
		return;
		}
	idx=[_forwardList indexOfObjectIdenticalTo:item];	// is it here?
	if(idx != NSNotFound)
		{ // moving backwards
		[_backList insertObject:_currentItem atIndex:0];
		[_currentItem release];
		do
			{ // move items from forwardList to backList
				[_backList insertObject:[_forwardList objectAtIndex:0] atIndex:0];
				[_forwardList removeObjectAtIndex:0];
			} while(idx-- > 0);
		_currentItem=[item retain];
		return;
		}
	[NSException raise:NSInvalidArgumentException format:@"item unknown"];
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