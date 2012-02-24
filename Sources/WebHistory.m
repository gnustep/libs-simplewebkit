/* simplewebkit
   WebHistory.m

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
#import <Foundation/Foundation.h>
#import <WebKit/WebHistory.h>

NSString *WebHistoryItemsKey=@"WebHistoryItemsKey";

NSString *WebHistoryAllItemsRemovedNotification=@"WebHistoryAllItemsRemovedNotification";
NSString *WebHistoryItemsAddedNotification=@"WebHistoryItemsAddedNotification";
NSString *WebHistoryItemsRemovedNotification=@"WebHistoryItemsRemovedNotification";
NSString *WebHistoryLoadedNotification=@"WebHistoryLoadedNotification";
NSString *WebHistorySavedNotification=@"WebHistorySavedNotification";

@interface NSDate (WebHistory)

- (NSComparisonResult) _reverseCompare:(id) other;

@end

@implementation NSDate (WebHistory)

- (NSComparisonResult) _reverseCompare:(id) other
{
	return -[self compare:other];
}

@end

@implementation WebHistory

static WebHistory *_optionalSharedHistory;

+ (WebHistory *) optionalSharedHistory; { return _optionalSharedHistory; }

+ (void) setOptionalSharedHistory:(WebHistory *) history; { ASSIGN(_optionalSharedHistory, history); }

- (void) addItems:(NSArray *) items;
{
	NSEnumerator *e=[items objectEnumerator];
	NSMutableArray *success=[NSMutableArray arrayWithCapacity:[items count]];
	WebHistoryItem *item;
	while((item=[e nextObject]))
		{
		WebHistoryItem *other=[_itemsByURL objectForKey:[item URLString]];
#if 0
		NSLog(@"add item: %@", item);
#endif
		if(other)
			{
			[other _setVisitCount:[other _visitCount]+1]; // already known
			[other _touch];
			}
		else if([item URLString])
			{
			// take _historyAgeInDaysLimit and _historyItemLimit into account (ignore if 0) if we have too many elements
			[_itemsByURL setObject:item forKey:[item URLString]];
			}
		// FIXME: update _itemGroups
		// replace&update if it already exists -> search by [item URL] and [NSCalendarDate dateWithInterval:[item interval]]
		if(_historyItemLimit > 0 && [_itemsByURL count] > _historyItemLimit)
			{ // remove oldest ones first
			}
		}
	[[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryItemsAddedNotification object:self userInfo:
		[NSDictionary dictionaryWithObject:success forKey:@"WebHistoryItemsKey"]];
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
	return [_itemsByURL objectForKey:[url absoluteString]];
}

- (BOOL) loadFromURL:(NSURL *) url error:(NSError **) error;
{
	NSDictionary *dict=[NSDictionary dictionaryWithContentsOfURL:url];
	NSEnumerator *e;
	NSDictionary *entry;
	if(error) *error=nil;
	if(!dict)
		return NO;
	e=[[dict objectForKey:@"WebHistoryDates"] objectEnumerator];
	if(!e)
		return NO;
	[_itemsByURL removeAllObjects];	// remove any items
	[_itemGroupsByDates removeAllObjects];
	while((entry=[e nextObject]))
		{
		WebHistoryItem *item=[[WebHistoryItem alloc] initWithURLString:[entry objectForKey:@""]
														 title:[entry objectForKey:@"title"]
									   lastVisitedTimeInterval:[[entry objectForKey:@"lastVisitedDate"] doubleValue]];
		[item _setVisitCount:[[entry objectForKey:@"visitCount"] intValue]];
		[_itemsByURL setObject:item forKey:[item URLString]];
		// update _itemGroupsByDates
		[item release];
		}
	[[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryLoadedNotification object:self];
	return YES;
}

// FIXME: grouping is not implemented!

- (NSArray *) orderedItemsLastVisitedOnDay:(NSCalendarDate *) date;
{
#if 0
	NSArray *a=[_itemGroupsByDates objectForKey:date];
	// should already be sorted...
	return a;
#else
	return [_itemsByURL allValues];
#endif
}

- (NSArray *) orderedLastVisitedDays;
{
#if 0
	NSArray *a=[_itemGroupsByDates allKeys];
	a=[a sortedArrayUsingSelector:@selector(_reverseCompare:)];
	return a;
#else
	return [NSArray arrayWithObject:[NSCalendarDate calendarDate]];
#endif
}

- (void) removeAllItems;
{
	NSArray *items=[[_itemsByURL allValues] retain];
	[_itemsByURL removeAllObjects];
	[_itemGroupsByDates removeAllObjects];
	[[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryAllItemsRemovedNotification object:self userInfo:
		[NSDictionary dictionaryWithObject:items forKey:@"WebHistoryItemsKey"]];
	[items release];
}

- (void) removeItems:(NSArray *) items;
{
	NSEnumerator *e=[_itemGroupsByDates keyEnumerator];
	NSCalendarDate *key;
	// FIXME: shouldn't we remove items for any key???
	[_itemsByURL removeObjectsForKeys:items];	// remove from url index
	while((key=[e nextObject]))
		[[_itemGroupsByDates objectForKey:key] removeItems:items];	// remove from all days
	// notify only those that have successfully been removed...
	[[NSNotificationCenter defaultCenter] postNotificationName:WebHistoryItemsRemovedNotification object:self userInfo:
		[NSDictionary dictionaryWithObject:items forKey:@"WebHistoryItemsKey"]];
}

- (BOOL) saveToURL:(NSURL *) url error:(NSError **) error;
{
	NSMutableArray *entries=[NSMutableArray arrayWithCapacity:[_itemsByURL count]];
	NSDictionary *root=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:1], @"WebHistoryFileVersion",
		entries, @"WebHistoryDates",
		nil];
	NSEnumerator *e=[_itemsByURL objectEnumerator];
	WebHistoryItem *item;
	while((item=[e nextObject]))
		{
		[entries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[item URLString], @"",
			[item title], @"title",
			[NSString stringWithFormat:@"%.1f", [item lastVisitedTimeInterval]], @"lastVisitedDate",
			[NSNumber numberWithInt:[item _visitCount]], @"visitCount",
			nil]];
		}
	if([root writeToURL:url atomically:YES])
		{
		[[NSNotificationCenter defaultCenter] postNotificationName:WebHistorySavedNotification object:self];
		return YES;
		}
	if(error) *error=nil;
	return NO;
}

- (void) setHistoryAgeInDaysLimit:(int) limit; { _historyAgeInDaysLimit=limit; }
- (void) setHistoryItemLimit:(int) limit; { _historyItemLimit=limit; }

@end
