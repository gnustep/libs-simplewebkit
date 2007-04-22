//
//  WebUIDelegate.h
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Sat Jan 27 2007.
//  Copyright (c) 2007 DSITRI. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView;
@class WebFrame;

@protocol WebOpenPanelResultListener
- (void) dummy;
@end

// used as UIDelegate of WebView

extern NSString *WebMenuItemTagCopy;
extern NSString *WebMenuItemTagCut;
extern NSString *WebMenuItemTagCopyImageToClipboard;
extern NSString *WebMenuItemTagCopyLinkToClipboard;
extern NSString *WebMenuItemTagDownloadImageToDisk;
extern NSString *WebMenuItemTagDownloadLinkToDisk;
extern NSString *WebMenuItemTagGoBack;
extern NSString *WebMenuItemTagGoForward;
extern NSString *WebMenuItemTagIgnoreSpelling;
extern NSString *WebMenuItemTagLearnSpelling;
extern NSString *WebMenuItemTagNoGuessesFound;
extern NSString *WebMenuItemTagOpenImageInNewWindow;
extern NSString *WebMenuItemTagOpenLinkInNewWindow;
extern NSString *WebMenuItemTagOpenFrameInNewWindow;
extern NSString *WebMenuItemTagOther;
extern NSString *WebMenuItemTagPaste;
extern NSString *WebMenuItemTagReload;
extern NSString *WebMenuItemTagSpellingGuess;
extern NSString *WebMenuItemTagStop;

typedef enum _WebDragDestination
{
	WebDragDestinationActionNone=0x0000,
	WebDragDestinationActionDHTML=0x0001,
	WebDragDestinationActionEdit=0x0002,
	WebDragDestinationActionLoad=0x0004,
	WebDragDestinationActionAny=0xffff
} WebDragDestinationAction;

typedef enum _WebDragSource
{
	WebDragSourceActionNone=0x0000,
	WebDragSourceActionDHTML=0x0001,
	WebDragSourceActionImage=0x0002,
	WebDragSourceActionLink=0x0004,
	WebDragSourceActionSelection=0x0008,	
	WebDragSourceActionAny=0xffff
} WebDragSourceAction;

@interface NSObject (WebUIDelegate)

- (WebView *) webView:(WebView *) sender createWebViewWithRequest:(NSURLRequest *) request;
- (void) webViewShow:(WebView *) sender;

// not yet called (many of them are methods to implement the JavaScript engine's 'window' object)

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) menu;
- (unsigned) webView:(WebView *) sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>) mask;
- (unsigned) webView:(WebView *) sender dragSourceActionMaskForPoint:(NSPoint) point;
- (void) webView:(WebView *) sender mouseDidMoveOverElement:(NSDictionary *) element modifierFlags:(unsigned int) flags;
- (void) webView:(WebView *) sender runJavaScriptAlertPanelWithMessage:(NSString *) message;
- (BOOL) webView:(WebView *) sender runJavaScriptConfirmPanelWithMessage:(NSString *) message;
- (NSString *) webView:(WebView *) sender runJavaScriptTextInputPanelWithPrompt:(NSString *) prompt defaultText:(NSString *) text;
- (void) webView:(WebView *) sender runOpenPanelForFileButtonWithResultListener:(id <WebOpenPanelResultListener>) listener;
- (void) webView:(WebView *) sender setContentRect:(NSRect) rect;
- (void) webView:(WebView *) sender setFrame:(NSRect) frame;
- (void) webView:(WebView *) sender setResizable:(BOOL) flag;
- (void) webView:(WebView *) sender setStatusBarVisible:(BOOL) flag;
- (void) webView:(WebView *) sender setStatusText:(NSString *) text;
- (void) webView:(WebView *) sender setToolbarsVisible:(BOOL) flag;
- (BOOL) webView:(WebView *) sender shouldPerformAction:(SEL) action fromSender:(id) sender;
- (BOOL) webView:(WebView *) sender validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>) item defaultValidation:(BOOL) flag;
- (void) webView:(WebView *) sender willPerformDragDestinationAction:(WebDragDestinationAction) action forDraggingInfo:(id <NSDraggingInfo>) info;
- (void) webView:(WebView *) sender willPerformDragSourceAction:(WebDragSourceAction) action fromPoint:(NSPoint) point withPasteboard:(NSPasteboard *) pasteboard;
- (BOOL) webViewAreToolbarsVisible:(WebView *) sender;
- (void) webViewClose:(WebView *) sender;
- (NSRect) webViewContentRect:(WebView *) sender;
- (NSResponder *) webViewFirstResponder:(WebView *) sender;
- (void) webViewFocus:(WebView *) sender;
- (NSRect) webViewFrame:(WebView *) sender;
- (BOOL) webViewIsResizable:(WebView *) sender;
- (BOOL) webViewIsStatusBarVisible:(WebView *) sender;
- (NSString *) webViewStatusText:(WebView *) sender;
- (void ) webViewUnfocus:(WebView *) sender;

@end
