/* simplewebkit
   WebBackForwardList.m

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
#import <WebKit/WebBackForwardList.h>
#import <WebKit/WebHistoryItem.h>

@implementation WebBackForwardList

- (void) addItem:(WebHistoryItem *) item;
{
	if(!item)
		[NSException raise:NSInvalidArgumentException format:@"nil item"];
	if(item == _currentItem)
		[NSException raise:NSInvalidArgumentException format:@"can't add current item"];
	[_forwardList removeAllObjects];
	if(_currentItem)
		{ // move current item to the backList
		[_backList insertObject:_currentItem atIndex:0];
		[_currentItem release];
		if(_capacity > 0)
			{
			while([_backList count] > _capacity)	// beyond capacity
				[_backList removeLastObject];
			}
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
- (BOOL) containsItem:(WebHistoryItem *) item; { return item == _currentItem || [_backList indexOfObjectIdenticalTo:item] != NSNotFound || [_forwardList indexOfObjectIdenticalTo:item] != NSNotFound; }
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
		_currentItem=[item retain];
		while(idx-- > 0)
			{ // move items from backList to forwardList
			[_forwardList insertObject:[_backList objectAtIndex:0] atIndex:0];
			[_backList removeObjectAtIndex:0];
			}
		[_backList removeObjectAtIndex:0];	// now current item
		return;
		}
	idx=[_forwardList indexOfObjectIdenticalTo:item];	// is it here?
	if(idx != NSNotFound)
		{ // moving backwards
		[_backList insertObject:_currentItem atIndex:0];
		[_currentItem release];
		_currentItem=[item retain];
		while(idx-- > 0)
			{ // move items from forwardList to backList
				[_backList insertObject:[_forwardList objectAtIndex:0] atIndex:0];
				[_forwardList removeObjectAtIndex:0];
			};
		[_forwardList removeObjectAtIndex:0];	// now current item
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
		_capacity=0;		// unlimited capacity
		_pageCacheSize=10;	// default - should depend on available memory
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
