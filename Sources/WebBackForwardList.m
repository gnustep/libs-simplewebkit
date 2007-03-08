/* simplewebkit
   WebBackForwardList.m

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
