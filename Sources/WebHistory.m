/* simplewebkit
   WebHistory.m

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
#import <Foundation/Foundation.h>
#import <WebKit/WebHistory.h>

NSString *WebHistoryItemsKey=@"WebHistoryItemsKey";

NSString *WebHistoryAllItemsRemovedNotification=@"WebHistoryAllItemsRemovedNotification";
NSString *WebHistoryItemsAddedNotification=@"WebHistoryItemsAddedNotification";
NSString *WebHistoryItemsRemovedNotification=@"WebHistoryItemsRemovedNotification";
NSString *WebHistoryLoadedNotification=@"WebHistoryLoadedNotification";
NSString *WebHistorySavedNotification=@"WebHistorySavedNotification";

@implementation WebHistory

{
	NSMutableDictionary *_itemsByURL;		// all items indexed by URL
	NSMutableDictionary *_itemGroupsByDates;	// all items grouped (&ordered?) on a single day, indexed by date 
	int _historyAgeInDaysLimit;
	int _historyItemLimit;
}

static WebHistory *_optionalSharedHistory;

+ (WebHistory *) optionalSharedHistory; { return _optionalSharedHistory; }

+ (void) setOptionalSharedHistory:(WebHistory *) history; { ASSIGN(_optionalSharedHistory, history); }

- (void) addItems:(NSArray *) items;
{
	// add to history
	// replace&update if it already exists -> search by [item URL] and [NSCalendarDate dateWithInterval:[item interval]]
	// create links
	// take _historyAgeInDaysLimit and _historyItemLimit into account (ignore if 0)
	// post notification of all sucessful additions
	NIMP;
}

- (int) historyAgeInDaysLimit; { return _historyAgeInDaysLimit; }
- (int) historyItemLimit; { return _historyItemLimit; }

- (id) init;
{ // create empty web history
	if((self=[super init]))
		{
		_itemsByURL=[[NSMutableDictionary alloc] initWithCapacity:10];
		_itemGroupsByDates=[[NSMutableDictionary alloc] initWithCapacity:10];
		}
	return self;
}

- (void) dealloc;
{
	[_itemsByURL release];
	[_itemGroupsByDates release];
	[super dealloc];
}

- (WebHistoryItem *) itemForURL:(NSURL *) url;
{
	return [_itemsByURL objectForKey:url];
}

- (BOOL) loadFromURL:(NSURL *) url error:(NSError **) error;
{
	NIMP;
	return NO;
}

- (NSArray *) orderedItemsLastVisitedOnDay:(NSCalendarDate *) date;
{
	NSArray *a=[_itemGroupsByDates objectForKey:date];
	// sort
	return a;
}

- (NSArray *) orderedLastVisitedDays;
{
	NSArray *a=[_itemGroupsByDates allKeys];
	// sort
	return a;
}

- (void) removeAllItems;
{
	[_itemsByURL removeAllObjects];
	[_itemGroupsByDates removeAllObjects];
}

- (void) removeItems:(NSArray *) items;
{
	NSEnumerator *e=[_itemGroupsByDates keyEnumerator];
	NSCalendarDate *key;
	// FIXME: shouldn't we remove items for any key???
	[_itemsByURL removeObjectsForKeys:items];	// remove from url index
	while((key=[e nextObject]))
		[[_itemGroupsByDates objectForKey:key] removeItems:items];	// remove from all days
}

- (BOOL) saveToURL:(NSURL *) url error:(NSError **) error;
{
	NIMP;
	return NO;
}

- (void) setHistoryAgeInDaysLimit:(int) limit; { _historyAgeInDaysLimit=limit; }
- (void) setHistoryItemLimit:(int) limit; { _historyItemLimit=limit; }

@end
