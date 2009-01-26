//
//  WebPreferences.h
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 18.11.07.
//  Copyright 2007 Golden Delicious Computers GmbH&Co. KG. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum
{
	WebCacheModelDocumentViewer=0,
	WebCacheModelDocumentBrowser,
	WebCacheModelPrimaryWebBrowser
};

typedef NSUInteger WebCacheModel;

@interface WebPreferences : NSObject <NSCoding>	// this is a proxy into NSUserDefaults
{
	NSMutableDictionary *_dict;
	NSString *_identifier;
	BOOL _autosaves;
}

+ (WebPreferences *) standardPreferences;

- (BOOL) allowsAnimatedImageLooping;
- (BOOL) allowsAnimatedImages;
- (BOOL) arePlugInsEnabled;
- (BOOL) autosaves;
- (WebCacheModel) cacheModel;
- (NSString *) cursiveFontFamily;
- (int) defaultFixedFontSize;
- (int) defaultFontSize;
- (NSString *) defaultTextEncodingName;
- (NSString *) fantasyFontFamily;
- (NSString *) fixedFontFamily;
- (NSString *) identifier;
- (id) initWithIdentifier:(NSString *) ident;
- (BOOL) isJavaEnabled;
- (BOOL) isJavaScriptEnabled;
- (BOOL) javaScriptCanOpenWindowsAutomatically;
- (BOOL) loadsImagesAutomatically;
- (int) minimumFontSize;
- (int) minimumLogicalFontSize;
- (BOOL) privateBrowsingEnabled;
- (NSString *) sansSerifFontFamily;
- (NSString *) serifFontFamily;
- (void) setAllowsAnimatedImageLooping:(BOOL) flag;
- (void) setAllowsAnimatedImages:(BOOL) flag;
- (void) setAutosaves:(BOOL) flag;
- (void) setCacheModel:(WebCacheModel) model;
- (void) setCursiveFontFamily:(NSString *) family;
- (void) setDefaultFixedFontSize:(int) size;
- (void) setDefaultFontSize:(int) size;
- (void) setDefaultTextEncodingName:(NSString *) enc;
- (void) setFantasyFontFamily:(NSString *) family;
- (void) setFixedFontFamily:(NSString *) family;
- (void) setJavaEnabled:(BOOL) flag;
- (void) setJavaScriptCanOpenWindowsAutomatically:(BOOL) flag;
- (void) setJavaScriptEnabled:(BOOL) flag;
- (void) setLoadsImagesAutomatically:(BOOL) flag;
- (void) setMinimumFontSize:(int) size;
- (void) setMinimumLogicalFontSize:(int) size;
- (void) setPlugInsEnabled:(BOOL) flag;
- (void) setPrivateBrowsingEnabled:(BOOL) flag;
- (void) setSansSerifFontFamily:(NSString *) family;
- (void) setSerifFontFamily:(NSString *) family;
- (void) setShouldPrintBackgrounds:(BOOL) flag;
- (void) setStandardFontFamily:(NSString *) family;
- (void) setTabsToLinks:(BOOL) flag;
- (void) setUserStyleSheetEnabled:(BOOL) flag;
- (void) setUserStyleSheetLocation:(NSURL *) url;
- (void) setUsesPageCache:(BOOL) flag;
- (BOOL) shouldPrintBackgrounds;
- (NSString *) standardFontFamily;
- (BOOL) tabsToLinks;
- (BOOL) userStyleSheetEnabled;
- (NSURL *) userStyleSheetLocation;
- (BOOL) usesPageCache;

@end

extern NSString *WebPreferencesChangedNotification;

