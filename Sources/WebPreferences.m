//
//  WebPreferences.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 18.11.07.
//  Copyright 2007 Golden Delicious Computers GmbH&Co. KG. All rights reserved.
//

#import "WebPreferences.h"
#import "Private.h"

NSString *WebPreferencesChangedNotification=@"WebPreferencesChangedNotification";

static NSString *PREF_DOMAIN=@"org.GNUstep.WebKit.WebPreferences";

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

- (id) init; { return [self initWithIdentifier:@"standardPreferences"]; }

- (id) initWithIdentifier:(NSString *) ident
{
	if((self=[super init]))
		{
			_identifier=[ident retain];
			_dict=[[[NSUserDefaults standardUserDefaults] persistentDomainForName:PREF_DOMAIN] mutableCopy];
			if(!_dict)
					{ // set defaults
						_dict=[[NSMutableDictionary alloc] initWithCapacity:30];
						/* FIXME:
#define DEFAULT_FONT_SIZE 16.0
#define DEFAULT_FONT @"Times"
#define DEFAULT_BOLD_FONT @"Times-Bold"
#define DEFAULT_TT_SIZE 13.0
#define DEFAULT_TT_FONT @"Courier"
						 */
						[_dict setObject:@"1" forKey:@"JavaScriptEnabled"];
						[_dict setObject:@"1" forKey:@"JavaScriptCanOpenWindowsAutomatically"];
						[_dict setObject:@"1" forKey:@"LoadsImagesAutomatically"];
						[_dict setObject:@"1" forKey:@"MinimumFontSize"];
						[_dict setObject:@"9" forKey:@"MinimumLogicalFontSize"];
						[_dict setObject:@"1" forKey:@"UsesPageCache"];
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
- (void) setAutosaves:(BOOL) flag; { _autosaves=flag; /* write any unsaved values? */ }

- (void) setValue:(id) val forKey:(NSString *) key;
{ // set value
	if([[_dict objectForKey:key] isEqual:val])
		return;	// unchanged (val may be a different object but is considered same value)
	if(val)
		[_dict setObject:val forKey:key];
	else
		[_dict removeObjectForKey:key];
	if(_autosaves)
		[[NSUserDefaults standardUserDefaults] setPersistentDomain:_dict forName:PREF_DOMAIN];
	[[NSNotificationCenter defaultCenter] postNotificationName:WebPreferencesChangedNotification object:self];	// FIXME - should be distributed notification
}

#define GETSET_OBJECT(TYPE, GETTER, SETTER, KEY)\
- (TYPE *) GETTER;\
{ return [_dict objectForKey:KEY]; } \
- (void) SETTER:(TYPE *) val;\
{ [self setValue:val forKey:KEY]; }

#define GETSET_STRING(GETTER, SETTER, KEY) GETSET_OBJECT(NSString, GETTER, SETTER, KEY)

#define GETSET_BOOL(GETTER, SETTER, KEY)\
- (BOOL) GETTER;\
{ return [[_dict objectForKey:KEY] boolValue]; } \
- (void) SETTER:(BOOL) val;\
{ [self setValue:[NSNumber numberWithBool:val] forKey:KEY]; }

#define GETSET_TYPE(TYPE, GETTER, SETTER, KEY)\
- (TYPE) GETTER;\
{ return [[_dict objectForKey:KEY] intValue]; } \
- (void) SETTER:(TYPE) val;\
{ [self setValue:[NSNumber numberWithInt:val] forKey:KEY]; }

#define GETSET_INT(GETTER, SETTER, KEY) GETSET_TYPE(int, GETTER, SETTER, KEY)

GETSET_BOOL(allowsAnimatedImageLooping, setAllowsAnimatedImageLooping, @"AllowsAnimatedImageLooping");
GETSET_BOOL(allowsAnimatedImages, setAllowsAnimatedImages, @"AllowsAnimatedImages");
GETSET_BOOL(arePlugInsEnabled, setPlugInsEnabled, @"PlugInsEnabled");
GETSET_TYPE(WebCacheModel, cacheModel, setCacheModel, @"CacheModel");
GETSET_STRING(cursiveFontFamily, setCursiveFontFamily, @"CursiveFontFamily");
GETSET_INT(defaultFixedFontSize, setDefaultFixedFontSize, @"DefaultFixedFontSize");
GETSET_INT(defaultFontSize, setDefaultFontSize, @"DefaultFontSize");
GETSET_STRING(defaultTextEncodingName, setDefaultTextEncodingName, @"DefaultTextEncoding");
GETSET_STRING(fantasyFontFamily, setFantasyFontFamily, @"FantasyFontFamily");
GETSET_STRING(fixedFontFamily, setFixedFontFamily, @"FixedFontFamily");
GETSET_BOOL(isJavaEnabled, setJavaEnabled, @"JavaEnabled");
GETSET_BOOL(isJavaScriptEnabled, setJavaScriptEnabled, @"JavaScriptEnabled");
GETSET_BOOL(javaScriptCanOpenWindowsAutomatically, setJavaScriptCanOpenWindowsAutomatically, @"JavaScriptCanOpenWindowsAutomatically");	// popup blocker...
GETSET_BOOL(loadsImagesAutomatically, setLoadsImagesAutomatically, @"LoadsImagesAutomatically");
GETSET_INT(minimumFontSize, setMinimumFontSize, @"MinimumFontSize");
GETSET_INT(minimumLogicalFontSize, setMinimumLogicalFontSize, @"MinimumLogicalFontSize");
GETSET_BOOL(privateBrowsingEnabled, setPrivateBrowsingEnabled, @"PrivateBrowsingEnabled");
GETSET_STRING(sansSerifFontFamily, setSansSerifFontFamily, @"SansSerifFontFamily");
GETSET_STRING(serifFontFamily, setSerifFontFamily, @"SerifFontFamily");
GETSET_BOOL(shouldPrintBackgrounds, setShouldPrintBackgrounds, @"ShouldPrintBackgrounds");
GETSET_STRING(standardFontFamily, setStandardFontFamily, @"StandardFontFamily");
GETSET_BOOL(tabsToLinks, setTabsToLinks, @"TabsToLinks");
GETSET_BOOL(userStyleSheetEnabled, setUserStyleSheetEnabled, @"UserStyleSheetEnabled");
GETSET_OBJECT(NSURL, userStyleSheetLocation, setUserStyleSheetLocation, @"UserStyleSheetLocation");
GETSET_BOOL(usesPageCache, setUsesPageCache, @"UsesPageCache");

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
