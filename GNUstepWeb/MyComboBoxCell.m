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

- (void) awakeFromNib;
{
	[self setDrawsBackground:NO];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// FIXME: this is currently broken!
	WebView *webView=[self target];
//	float progress=webView?[webView estimatedProgress]:0.0;
	float progress=0.5;
	if(progress == 1.0)
		progress=0.0;	// don't show
	if(progress > 0)
		{
		[[NSColor blueColor] set];
		NSRectFill(NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width*progress, cellFrame.size.height));
		}
	[[self backgroundColor] set];	// as defined in IB
	NSRectFill(NSMakeRect(cellFrame.origin.x+cellFrame.size.width*progress, cellFrame.origin.y, cellFrame.size.width*(1.0-progress), cellFrame.size.height));
	[self setDrawsBackground:NO];	// already done
	[super drawWithFrame:cellFrame inView:controlView];
}

@end

