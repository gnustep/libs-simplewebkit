/* All Rights reserved */

#include <AppKit/AppKit.h>
#include <WebKit/WebKit.h>

#include "SWKPalette.h"

@implementation SWKPalette

- (void)finishInstantiate
{
  [self associateObject: [[WebView alloc] 
			   initWithFrame: NSMakeRect(0,0,200,200)]
	type: IBViewPboardType
	with: image];

}

@end
