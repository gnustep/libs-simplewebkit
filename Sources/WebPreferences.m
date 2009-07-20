//
//  WebPreferences.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 18.11.07.
//  Copyright 2007 Golden Delicious Computers GmbH&Co. KG. All rights reserved.
//

#import "Private.h"
#import <WebKit/WebPreferences.h>

NSString *WebPreferencesChangedNotification=@"WebPreferencesChangedNotification";

static NSMutableDictionary *knownPrefs;

@implementation WebPreferences

+ (WebPreferences *) standardPreferences;
{
	static WebPreferences *prefs;
	if(!prefs)
		{
		prefs=[self new];
		[prefs setAutosaves:YES];
		}
	return prefs;
}

- (id) init; { return [self initWithIdentifier:nil]; }	// no identifier

- (id) initWithIdentifier:(NSString *) ident
{
	if((self=[super init]))
		{
			if([knownPrefs objectForKey:ident])
					{ // already known
						[self release];
						return [[knownPrefs objectForKey:ident] retain];
					}
			_identifier=[ident retain];
			if(ident)
					{
				if(!knownPrefs)
					knownPrefs=[[NSMutableDictionary alloc] initWithCapacity:3];
				[knownPrefs setObject:self forKey:ident];	// FIXME: this prevents that we ever receive a dealloc!
					}
		}
	return self;
}

- (void) dealloc;
{
	[_identifier release];
	[_dict release];
	[super dealloc];
}

- (NSString *) identifier; { return _identifier; }

- (BOOL) autosaves; { return _autosaves; }
- (void) setAutosaves:(BOOL) flag; { _autosaves=flag; /* copy any  values? */ }

- (id) valueForKey:(NSString *) key;
{
	if(!_autosaves)
		return [_dict objectForKey:key];	// stored local
	if(_identifier)
		key=[NSString stringWithFormat:@"%@WebKit%@", _identifier, key];	// specific
	else
		key=[NSString stringWithFormat:@"WebKit%@", key];	// standard
	return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void) setValue:(id) val forKey:(NSString *) key;
{ // set value
	NSUserDefaults *ud;
	if(!_autosaves)
			{
				if(!_dict)
					_dict=[[NSMutableDictionary alloc] initWithCapacity:10];
				if(val)
					[_dict setObject:val forKey:key];	// stored local
				else
					[_dict removeObjectForKey:key];
				return;
			}
	if(_identifier)
		key=[NSString stringWithFormat:@"%@WebKit%@", _identifier, key];	// specific
	else
		key=[NSString stringWithFormat:@"WebKit%@", key];	// standard
	ud=[NSUserDefaults standardUserDefaults];
	if([[ud objectForKey:key] isEqual:val])
		return;	// unchanged (val may be a different object but is considered same value) - does not handle the case where val==nil and already removed
	if(val)
		[ud setObject:val forKey:key];
	else
		[ud removeObjectForKey:key];
	[[NSNotificationCenter defaultCenter] postNotificationName:WebPreferencesChangedNotification object:self];	// FIXME - should be distributed notification
}

#define GETSET_OBJECT(TYPE, GETTER, SETTER, KEY, DEFAULT)\
- (TYPE *) GETTER;\
{ id val=[self valueForKey:KEY]; if(!val) return DEFAULT; return val; } \
- (void) SETTER:(TYPE *) val;\
{ [self setValue:val forKey:KEY]; }

#define GETSET_STRING(GETTER, SETTER, KEY, DEFAULT) GETSET_OBJECT(NSString, GETTER, SETTER, KEY, DEFAULT)

#define GETSET_BOOL(GETTER, SETTER, KEY, DEFAULT)\
- (BOOL) GETTER;\
{ id val=[self valueForKey:KEY]; if(!val) return DEFAULT; return [val boolValue]; } \
- (void) SETTER:(BOOL) val;\
{ if([self valueForKey:KEY] || val != DEFAULT) [self setValue:[NSNumber numberWithBool:val] forKey:KEY]; }

#define GETSET_TYPE(TYPE, GETTER, SETTER, KEY, DEFAULT)\
- (TYPE) GETTER;\
{ id val=[self valueForKey:KEY]; if(!val) return DEFAULT; return [val intValue]; } \
- (void) SETTER:(TYPE) val;\
{ if([self valueForKey:KEY] || val != DEFAULT) [self setValue:[NSNumber numberWithInt:val] forKey:KEY]; }

#define GETSET_INT(GETTER, SETTER, KEY, DEFAULT) GETSET_TYPE(int, GETTER, SETTER, KEY, DEFAULT)

GETSET_BOOL(allowsAnimatedImageLooping, setAllowsAnimatedImageLooping, @"AllowsAnimatedImageLooping", NO);
GETSET_BOOL(allowsAnimatedImages, setAllowsAnimatedImages, @"AllowsAnimatedImages", NO);
GETSET_BOOL(arePlugInsEnabled, setPlugInsEnabled, @"PluginsEnabled", NO);
GETSET_TYPE(WebCacheModel, cacheModel, setCacheModel, @"CacheModelPreferenceKey", 0);
GETSET_STRING(cursiveFontFamily, setCursiveFontFamily, @"CursiveFontFamily", @"Times-Italic");
GETSET_INT(defaultFixedFontSize, setDefaultFixedFontSize, @"DefaultFixedFontSize", 13);
GETSET_INT(defaultFontSize, setDefaultFontSize, @"DefaultFontSize", 16);
GETSET_STRING(defaultTextEncodingName, setDefaultTextEncodingName, @"DefaultTextEncodingName", @"UTF-8");
GETSET_STRING(fantasyFontFamily, setFantasyFontFamily, @"FantasyFontFamily", @"Fantasy");
GETSET_STRING(fixedFontFamily, setFixedFontFamily, @"FixedFontFamily", [[NSFont userFixedPitchFontOfSize:12.0] fontName]);
GETSET_BOOL(isJavaEnabled, setJavaEnabled, @"JavaEnabled", NO);
GETSET_BOOL(isJavaScriptEnabled, setJavaScriptEnabled, @"JavaScriptEnabled", YES);
GETSET_BOOL(javaScriptCanOpenWindowsAutomatically, setJavaScriptCanOpenWindowsAutomatically, @"JavaScriptCanOpenWindowsAutomatically", YES);	// popup blocker...
GETSET_BOOL(loadsImagesAutomatically, setLoadsImagesAutomatically, @"LoadsImagesAutomatically", YES);
GETSET_INT(minimumFontSize, setMinimumFontSize, @"MinimumFontSize", 1);
GETSET_INT(minimumLogicalFontSize, setMinimumLogicalFontSize, @"MinimumLogicalFontSize", 9);
GETSET_BOOL(privateBrowsingEnabled, setPrivateBrowsingEnabled, @"PrivateBrowsingEnabled", NO);
GETSET_STRING(sansSerifFontFamily, setSansSerifFontFamily, @"SansSerifFontFamily", [[NSFont systemFontOfSize:12.0] fontName]);
GETSET_STRING(serifFontFamily, setSerifFontFamily, @"SerifFontFamily", @"Times");
GETSET_BOOL(shouldPrintBackgrounds, setShouldPrintBackgrounds, @"ShouldPrintBackgroundsPreferenceKey", YES);
GETSET_STRING(standardFontFamily, setStandardFontFamily, @"StandardFontFamily", [[NSFont userFontOfSize:12.0] fontName]);
GETSET_BOOL(tabsToLinks, setTabsToLinks, @"TabsToLinks", NO);
GETSET_BOOL(userStyleSheetEnabled, setUserStyleSheetEnabled, @"UserStyleSheetEnabledPreferenceKey", NO);
GETSET_OBJECT(NSURL, userStyleSheetLocation, setUserStyleSheetLocation, @"UserStyleSheetLocation", nil);
GETSET_BOOL(usesPageCache, setUsesPageCache, @"UsesPageCache", NO);

- (void) encodeWithCoder:(NSCoder *) coder;
{
	NIMP;
}

- (id) initWithCoder:(NSCoder *) coder;
{
	[self release];
	return NIMP;
}

@end
