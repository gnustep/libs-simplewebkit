/* simplewebkit
   WebView.h

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
#import <Foundation/NSURLRequest.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebResourceLoadDelegate.h>
#import <WebKit/WebDownload.h>
// #import <WebKit/WebEditingDelegate.h>
// #import <WebKit/WebPolicyDelegate.h>
#import <WebKit/WebUIDelegate.h>

@class WebBackForwardList, WebHistoryItem;
@class WebPreferences;
@class WebView;
@class WebFrame;
@class WebArchive;
@class WebScriptObject;

@class DOMCSSStyleDeclaration;
@class DOMElement;
@class DOMNode;
@class DOMRange;

extern NSString *WebElementDOMNodeKey;
extern NSString *WebElementFrameKey;
extern NSString *WebElementImageAltStringKey;
extern NSString *WebElementImageKey;
extern NSString *WebElementImageRectKey;
extern NSString *WebElementImageURLKey;
extern NSString *WebElementIsSelectedKey;
extern NSString *WebElementLinkURLKey;
extern NSString *WebElementLinkTargetFrameKey;
extern NSString *WebElementLinkTitleKey;
extern NSString *WebElementLinkLabelKey;

extern NSString *WebViewDidBeginEditingNotification;
extern NSString *WebViewDidChangeNotification;
extern NSString *WebViewDidChangeSelectionNotification;
extern NSString *WebViewDidChangeTypingStyleNotification;
extern NSString *WebViewDidEndEditingNotification;
extern NSString *WebViewProgressEstimateChangedNotification;
extern NSString *WebViewProgressFinishedNotification;
extern NSString *WebViewProgressStartedNotification;

@interface WebView : NSView
{
	WebFrame *_mainFrame;
	NSString *_groupName;
	WebBackForwardList *_backForwardList;
	WebPreferences *_preferences;
	NSWindow *_hostWindow;
	NSString *_applicationName;
	NSString *_customTextEncoding;
	NSString *_customAgent;
	NSString *_mediaStyle;
	NSString *_preferencesIdentifier;
	DOMCSSStyleDeclaration *_typingStyle;
	id _downloadDelegate;
	id _editingDelegate;
	id /*<WebFrameLoadDelegate>*/ _frameLoadDelegate;
	id _policyDelegate;
	id /*<WebResourceLoadDelegate>*/_resourceLoadDelegate;
	id /*<WebUIDelegate>*/ _uiDelegate;
	float _textSizeMultiplier;
	BOOL _continuousSpellChecking;
	BOOL _editable;
	BOOL _smartInsertDelete;
	BOOL _maintainsBackForwardList;
	BOOL _drawsBackground;
}

+ (BOOL) canShowMIMEType:(NSString *) type;
+ (BOOL) canShowMIMETypeAsHTML:(NSString *) type;
+ (NSArray *) MIMETypesShownAsHTML;
+ (void) registerViewClass:(Class) class representationClass:(Class) repClass forMIMEType:(NSString *) type;
+ (void) setMIMETypesShownAsHTML:(NSArray *) type;
+ (NSURL *) URLFromPasteboard:(NSPasteboard *) pasteboard;
+ (NSString *) URLTitleFromPasteboard:(NSPasteboard *) pasteboard;

- (void) alignCenter:(id) sender;
- (void) alignJustified:(id) sender;
- (void) alignLeft:(id) sender;
- (void) alignRight:(id) sender;
- (NSString *) applicationNameForUserAgent;
- (void) applyStyle:(DOMCSSStyleDeclaration *) style;
- (WebBackForwardList *) backForwardList;
- (BOOL) canGoBack;
- (BOOL) canGoForward;
- (BOOL) canMakeTextLarger;
- (BOOL) canMakeTextSmaller;
- (void) changeAttributes:(id) sender;
- (void) changeColor:(id) sender;
- (void) changeDocumentBackgroundColor:(id) sender;
- (void) changeFont:(id) sender;
- (void) checkSpelling:(id) sender;
- (DOMCSSStyleDeclaration *) computedStyleForElement:(DOMElement *) element
									   pseudoElement:(NSString *) pseudoElement;
- (void) copy:(id) sender;
- (void) copyFont:(id) sender;
- (NSString *) customTextEncodingName;
- (NSString *) customUserAgent;
- (void) cut:(id) sender;
- (void) delete:(id) sender;
- (void) deleteSelection;
- (id) downloadDelegate;
- (DOMRange *) editableDOMRangeForPoint:(NSPoint) point;
- (id) editingDelegate;
- (NSDictionary *) elementAtPoint:(NSPoint) point;
- (double) estimatedProgress;
- (id) frameLoadDelegate;	// uses informal WebFrameLoadDelegate protocol
- (void) goBack;
- (IBAction) goBack:(id) sender;
- (void) goForward;
- (IBAction) goForward:(id) sender;
- (BOOL) goToBackForwardItem:(WebHistoryItem *) item;
- (NSString *) groupName;
- (NSWindow *) hostWindow;
- (id) initWithFrame:(NSRect) rect frameName:(NSString *) name groupName:(NSString *) group;
- (BOOL) isContinuousSpellCheckingEnabled;
- (BOOL) isEditable;
- (WebFrame *) mainFrame;
- (IBAction) makeTextLarger:(id) sender;
- (IBAction) makeTextSmaller:(id) sender;
- (NSString *) mediaStyle;
- (void) moveDragCaretToPoint:(NSPoint) point;
- (void) paste:(id) sender;
- (void) pasteAsPlainText:(id) sender;
- (void) pasteAsRichText:(id) sender;
- (NSArray *) pasteboardTypesForElement:(NSDictionary *) element;
- (NSArray *) pasteboardTypesForSelection;
- (void) pasteFont:(id) sender;
- (void) performFindPanelAction:(id) sender;
- (id) policyDelegate;
- (WebPreferences *) preferences;
- (NSString *) preferencesIdentifier;
- (IBAction) reload:(id) sender;
- (void) removeDragCaret;
- (void) replaceSelectionWithArchive:(WebArchive *) archive;
- (void) replaceSelectionWithMarkupString:(NSString *) string;
- (void) replaceSelectionWithNode:(DOMNode *) node;
- (void) replaceSelectionWithText:(NSString *) text;
- (id) resourceLoadDelegate;
- (BOOL) searchFor:(NSString *) string direction:(BOOL) forward caseSensitive:(BOOL) flag wrap:(BOOL) wrap;
- (DOMRange *) selectedDOMRange;
- (NSSelectionAffinity) selectionAffinity;
- (void) setApplicationNameForUserAgent:(NSString *) name;
- (void) setContinuousSpellCheckingEnabled:(BOOL) flag;
- (void) setCustomTextEncodingName:(NSString *) name;
- (void) setCustomUserAgent:(NSString *) agent;
- (void) setDownloadDelegate:(id) delegate;
- (void) setEditable:(BOOL) flag;
- (void) setEditingDelegate:(id) delegate;
- (void) setFrameLoadDelegate:(id) delegate;
- (void) setGroupName:(NSString *) str;
- (void) setHostWindow:(NSWindow *) window;
- (void) setMaintainsBackForwardList:(BOOL) flag;
- (void) setMediaStyle:(NSString *) style;
- (void) setPolicyDelegate:(id) delegate;
- (void) setPreferences:(WebPreferences *) prefs;
- (void) setPreferencesIdentifier:(NSString *) ident;
- (void) setResourceLoadDelegate:(id) delegate;
- (void) setSelectedDOMRange:(DOMRange *) range affinity:(NSSelectionAffinity) affinity;
- (void) setSmartInsertDeleteEnabled:(BOOL) flag;
- (void) setTextSizeMultiplier:(float) multiplier;
- (void) setTypingStyle:(DOMCSSStyleDeclaration *) style;
- (void) setUIDelegate:(id) delegate;
- (void) showGuessPanel:(id) sender;
- (BOOL) smartInsertDeleteEnabled;
- (int) spellCheckerDocumentTag;
- (void) startSpeaking:(id) sender;
- (IBAction) stopLoading:(id) sender;
- (void) stopSpeaking:(id) sender;
- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script;
- (DOMCSSStyleDeclaration *) styleDeclarationWithText:(NSString *) text;
- (BOOL) supportsTextEncoding;
- (IBAction) takeStringURLFrom:(id) sender; // anything responding to -stringValue
- (float) textSizeMultiplier;
- (DOMCSSStyleDeclaration *) typingStyle;
- (id) UIDelegate;
- (NSUndoManager *) undoManager;
- (NSString *) userAgentForURL:(NSURL *) URL;
- (WebScriptObject *) windowScriptObject;
- (void) writeElement:(NSDictionary *) element
  withPasteboardTypes:(NSArray *) types
		 toPasteboard:(NSPasteboard *) pasteboard;
- (void) writeSelectionWithPasteboardTypes:(NSArray *) types
							  toPasteboard:(NSPasteboard *) pasteboard;

@end
