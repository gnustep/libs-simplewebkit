//
//  MyComboBoxCell.m
//  SimpleWebKit
//
//  Created by H. Nikolaus Schaller on 07.04.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyComboBoxCell.h"
#import <WebKit/WebKit.h>

@implementation MyComboBoxCell	// can display progress background

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect frame=cellFrame;
	WebView *webView=[self target];
//	float progress=webView?[webView estimatedProgress]:0.0;
	float progress=0.5;
	[super drawWithFrame:cellFrame inView:controlView];	// draw combo box and popup button
	return;
	if(progress == 1.0)
		progress=0.0;	// don't show
	frame.size.width -= 3.0;	// IB specifies 3 px spacing on the right hand side
	frame.origin.y += 2.0;		// IB specifies 4px vertical (transparent!) spacing
	frame.size.height -= 4.0;
	if(progress > 0)
		{
		[[NSColor blueColor] set];
		NSRectFill(NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width*progress, frame.size.height));
		}
//	[[self backgroundColor] set];	// as defined in IB
//	NSRectFill(NSMakeRect(frame.origin.x+frame.size.width*progress, frame.origin.y, frame.size.width*(1.0-progress), frame.size.height));
	[super drawInteriorWithFrame:cellFrame inView:controlView];	// draw text again so that it is above blue bar
}

@end

