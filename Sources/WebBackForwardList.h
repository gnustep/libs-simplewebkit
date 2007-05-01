/* simplewebkit
   WebBackForwardList.h

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

#import <Cocoa/Cocoa.h>

@class WebHistoryItem;

@interface WebBackForwardList : NSObject
{
	NSMutableArray *_backList;
	NSMutableArray *_forwardList;
	WebHistoryItem *_currentItem;
	int _capacity;
	unsigned _pageCacheSize;	// just stored here but not used internaly
}

- (void) addItem:(WebHistoryItem *) item;
- (WebHistoryItem *) backItem;
- (int) backListCount;
- (NSArray *) backListWithLimit:(int) limit;
- (int) capacity;
- (BOOL) containsItem:(WebHistoryItem *) item;
- (WebHistoryItem *) currentItem;
- (WebHistoryItem *) forwardItem;
- (int) forwardListCount;
- (NSArray *) forwardListWithLimit:(int) limit;
- (void) goBack;
- (void) goForward;
- (void) goToItem:(WebHistoryItem *) item;
- (id) init;
- (WebHistoryItem *) itemAtIndex:(int) index;
- (unsigned) pageCacheSize;
- (void) setCapacity:(int) size;
- (void) setPageCacheSize:(unsigned) size;

@end
