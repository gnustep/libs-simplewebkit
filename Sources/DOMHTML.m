/* simplewebkit
   DOMHTML.h

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

#import "DOMHTML.h"

static NSString *DOMHTMLElementAttribute=@"DOMHTMLElementAttribute";
static NSString *DOMHTMLAnchorElementTargetName=@"DOMHTMLAnchorElementTargetName";

@interface NSString (HTMLAttributes)
- (BOOL) htmlBoolValue;
- (NSColor *) htmlColor;
@end

@implementation NSString (HTMLAttributes)

- (BOOL) htmlBoolValue;
{
	if([self length] == 0)
		return YES;	// pure existence means YES
	if([self isEqualToString:@"YES"] || [self isEqualToString:@"yes"])
		return YES;
	return NO;
}

- (NSColor *) htmlColor;
{
	// handle #rrggbb and color names
	return [NSColor redColor];
}

@end

@implementation DOMHTMLElement

+ (BOOL) _closeNotRequired; { return NO; }	// default implementation
+ (BOOL) _goesToHead;		{ return NO; }
+ (BOOL) _ignore;			{ return NO; }
+ (BOOL) _streamline;		{ return NO; }

- (NSString *) outerHTML;
{
	NSString *str=[NSString stringWithFormat:@"<%@>\n%@", [self nodeName], [self innerHTML]];
	if(![isa _closeNotRequired])
		str=[str stringByAppendingFormat:@"</%@>\n", [self nodeName]];	// close
	return str;
}

- (NSString *) innerHTML;
{
	NSString *str=@"";
	int i;
	for(i=0; i<[_childNodes length]; i++)
		{
		NSString *d=[(DOMHTMLElement *) [_childNodes item:i] outerHTML];
		str=[str stringByAppendingString:d];
		}
	return str;
}

- (void) _trimSpaces:(NSMutableAttributedString *) str;
{
	// should trim spaces at the beginning or end
	// while([[str string] hasPrefix:@" "])
	//	[str replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];	// should remove first character
}

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=[[NSMutableAttributedString alloc] initWithString:@""];
	NSString *tag=[self nodeName];
	int i;
	for(i=0; i<[_childNodes length]; i++)
		// when do we have to insert a space character???
		[str appendAttributedString:[(DOMHTMLElement *) [_childNodes item:i] attributedString]];
	if([tag isEqualToString:@"B"])
		{ // make bold
		// should apply to individual attribute runs and not change font name and size
//		[str addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [str length])]	// set the link attribute
		}
	else if([tag isEqualToString:@"I"])
		{ // make italics
		}
	else if([tag isEqualToString:@"CENTER"])
		{ // set centered alignment
		[self _trimSpaces:str];
		}
	else if([tag hasPrefix:@"H"])
		{ // make header
		float size=12.0;
		int s=[[tag substringFromIndex:1] intValue];
		switch(s)
			{
			case 1:	size=24.0; break;
			case 2:	size=18.0; break;
			case 3:	size=14.0; break;
			case 4:	size=12.0; break;
			case 5:	size=10.0; break;
			case 6:	size=8.0; break;
			}
		[str appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease]];
		[str addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Bold" size:size] range:NSMakeRange(0, [str length])];	// set the link attribute
		}
	return [str autorelease];
}

- (void) _awakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep; { return; }	// ignore

@end

@implementation DOMCharacterData (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [self data];
}

- (NSString *) innerHTML;
{
	return [self data];
}

- (NSAttributedString *) attributedString;
{
	NSMutableString *str=[[[self data] mutableCopy] autorelease];
	[str replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [str length])];	// convert to space
	[str replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [str length])];	// trim multiple spaces
	return [[[NSMutableAttributedString alloc] initWithString:str] autorelease];	// using default font...
}

@end

@implementation DOMCDATASection (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<!CDATA>\n%@\n</!CDATA>", [(DOMHTMLElement *)self innerHTML]];
}

@end

@implementation DOMComment (DOMHTMLElement)

- (NSString *) outerHTML;
{
	return [NSString stringWithFormat:@"<!-- %@ -->\n", [(DOMHTMLElement *)self innerHTML]];
}

@end

@implementation DOMHTMLDocument
- (WebFrame *) webFrame; { return _webFrame; }
- (void) _setWebFrame:(WebFrame *) f; { _webFrame=f; }
- (WebDataSource *) _webDataSource; { return _dataSource; }
- (void) _setWebDataSource:(WebDataSource *) src; { _dataSource=src; }
@end

@implementation DOMHTMLHtmlElement
+ (BOOL) _ignore;	{ return YES; }
@end

@implementation DOMHTMLHeadElement
+ (BOOL) _ignore;	{ return YES; }
@end

@implementation DOMHTMLTitleElement
+ (BOOL) _goesToHead;	{ return YES; }
+ (BOOL) _streamline;	{ return YES; }
@end

@implementation DOMHTMLMetaElement
+ (BOOL) _closeNotRequired; { return YES; }
+ (BOOL) _goesToHead;	{ return YES; }
@end

@implementation DOMHTMLLinkElement

+ (BOOL) _closeNotRequired; { return YES; }
+ (BOOL) _goesToHead;	{ return YES; }

- (void) _awakeFromDocumentRepresentation:(_WebDocumentRepresentation *) rep;
{ // e.g. <link rel="stylesheet" type="text/css" href="test.css" />
	NSString *rel=[self getAttribute:@"rel"];
	if([rel isEqualToString:@"stylesheet"] && [[self getAttribute:@"type"] isEqualToString:@"text/css"])
		{ // load stylesheet
		[self _loadSubresourceWithAttributeString:@"href"];
		}
	else if([rel isEqualToString:@"home"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
 	else if([rel isEqualToString:@"alternate"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	else if([rel isEqualToString:@"index"])
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
	else
		{
		NSLog(@"<link>: %@", [self _attributes]);
		}
}

@end

@implementation DOMHTMLStyleElement
+ (BOOL) _goesToHead;	{ return YES; }
+ (BOOL) _streamline;	{ return YES; }
@end

@implementation DOMHTMLScriptElement

+ (BOOL) _streamline;	{ return YES; }

- (NSAttributedString *) attributedString;
{ // contents is script (may be inside a comment)
	return [[[NSAttributedString alloc] initWithString:@""] autorelease];
}

@end

@implementation DOMHTMLObjectElement

- (NSAttributedString *) attributedString;
{ // contents is script (may be inside a comment)
	return [[[NSAttributedString alloc] initWithString:@""] autorelease];
}

@end

@implementation DOMHTMLParamElement

@end

@implementation DOMHTMLFrameSetElement
@end

@implementation DOMHTMLFrameElement
+ (BOOL) _closeNotRequired; { return YES; }
@end

@implementation DOMHTMLIFrameElement
@end

@implementation DOMHTMLBodyElement
+ (BOOL) _ignore;	{ return YES; }
@end

@implementation DOMHTMLDivElement
@end

@implementation DOMHTMLSpanElement
@end

@implementation DOMHTMLFontElement

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];
	NSString *name=[self getAttribute:@"FACE"];	// is a comma separated list of names...
	NSString *size=[self getAttribute:@"SIZE"];
	NSString *color=[self getAttribute:@"COLOR"];
	NSLog(@"<font>: %@", [self _attributes]);
	// modify font, color etc. as specified
	// SIZE is in steps of 1..7, +1 or -1 means one level up or down
	return str;
}

@end

@implementation DOMHTMLAnchorElement

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];
	NSString *urlString=[self getAttribute:@"HREF"];
	NSLog(@"<a>: %@", [self _attributes]);
	if(urlString)
		{ // make it a link
		[str addAttribute:NSLinkAttributeName value:urlString range:NSMakeRange(0, [str length])];	// set the link attribute
		}
	return str;
}

@end

@implementation DOMHTMLImageElement
+ (BOOL) _closeNotRequired; { return YES; }
@end

@implementation DOMHTMLBRElement
+ (BOOL) _closeNotRequired; { return YES; }

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];
	[str appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease]];
	return str;
}

@end

@implementation DOMHTMLParagraphElement
+ (BOOL) _closeNotRequired; { return YES; }

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];
	[str appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease]];
	return str;
}

@end

@implementation DOMHTMLHRElement
+ (BOOL) _closeNotRequired; { return YES; }
@end

@implementation DOMHTMLTableElement
@end

@implementation DOMHTMLTableRowElement
+ (BOOL) _closeNotRequired; { return YES; }
@end

@implementation DOMHTMLTableCellElement

+ (BOOL) _closeNotRequired; { return YES; }

- (NSAttributedString *) attributedString;
{
	// search for enclosing <table>, <tbody> or <tr> element to know how to set target/action etc.
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];	// get content
	NSString *align=[self getAttribute:@"ALIGN"];
	NSLog(@"<td>: %@", [self _attributes]);
	return str;
}

@end

@implementation DOMHTMLFormElement
@end

@implementation DOMHTMLInputElement

+ (BOOL) _closeNotRequired; { return YES; }

- (NSAttributedString *) attributedString;
{
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"NAME"];
	NSString *value=[self getAttribute:@"VALUE"];
	NSString *placeholder=[self getAttribute:@"TITLE"];
	NSString *size=[self getAttribute:@"SIZE"];
	NSString *maxlen=[self getAttribute:@"MAXLENGTH"];
	NSString *type=[self getAttribute:@"TYPE"];
	if([type caseInsensitiveCompare:@"HIDDEN"] == NSOrderedSame)
		{ // ignore - will be collected when sending the <form>
		return [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
		}
	if([type caseInsensitiveCompare:@"SUBMIT"] == NSOrderedSame)
		{ // ignore - will be collected when sending the <form>
		// insert a NSButton
		return [[[NSMutableAttributedString alloc] initWithString:@" (Submit)"] autorelease];
		}
	if([type caseInsensitiveCompare:@"RADIO"] == NSOrderedSame)
		{
		NSString *ident=[self getAttribute:@"ID"];		// use to group elements
		BOOL checked=[[self getAttribute:@"CHECKED"] htmlBoolValue];
		// create NSRadio button
		// enable if checked
		// handle enabling/disabling by finding others with same id
		return [[[NSMutableAttributedString alloc] initWithString:@"(o)"] autorelease];
		}
	if(!value)
		value=@"";
	NSLog(@"<input>: %@", [self _attributes]);
	// we should create a NSTextAttachment which includes an NSTextField that is initialized with value, placeholder, etc. etc.
	return [[[NSMutableAttributedString alloc] initWithString:value] autorelease];	// using default font...
}

@end

@implementation DOMHTMLButtonElement

- (NSAttributedString *) attributedString;
{
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"NAME"];
	NSString *value=[self getAttribute:@"VALUE"];
	NSString *size=[self getAttribute:@"SIZE"];
	if(!value)
		value=@"";
	NSLog(@"<button>: %@", [self _attributes]);
	// we should create a NSTextAttachment which includes an NSButton that is initialized
	return [[[NSMutableAttributedString alloc] initWithString:value] autorelease];	// using default font...
}

@end

@implementation DOMHTMLSelectElement

- (NSAttributedString *) attributedString;
{
	NSMutableAttributedString *str;
	NSTextAttachment *attachment;
	NSCell *cell;
	// search for enclosing <form> element to know how to set target/action etc.
	NSString *name=[self getAttribute:@"name"];
	NSString *val=[self getAttribute:@"value"];
	NSString *size=[self getAttribute:@"size"];
	BOOL multiSelect=[self hasAttribute:@"multiple"];
	if(!val)
		val=@"";
#if 1
	NSLog(@"<button>: %@", [self _attributes]);
#endif
	if([size intValue] <= 1)
		{ // dropdown
		// how to handle multiSelect flag?
		attachment=[NSTextAttachmentCell textAttachmentWithCellOfClass:[NSPopUpButtonCell class]];
		cell=(NSCell *) [attachment attachmentCell];	// get the real cell
		[cell setTitle:val];
		[cell setTarget:self];
		[cell setAction:@selector(_formAction:)];
		}
	else
		{ // embed NSTableView with [size intValue] visible lines
		attachment=nil;
		cell=nil;
		}
#if 1
	NSLog(@"  cell: %@", cell);
#endif
	str=(NSMutableAttributedString *) [NSMutableAttributedString attributedStringWithAttachment:attachment];
	[str addAttribute:DOMHTMLElementAttribute value:self range:NSMakeRange(0, [str length])];
	return str;
}

@end

@implementation DOMHTMLOptionElement
@end

@implementation DOMHTMLOptGroupElement
@end

@implementation DOMHTMLLabelElement
@end

@implementation DOMHTMLTextAreaElement

- (NSAttributedString *) attributedString;
{
	// search for enclosing <form> element to know how to set target/action etc.
	NSMutableAttributedString *str=(NSMutableAttributedString *) [super attributedString];	// get content between <textarea> and </textarea>
	NSString *name=[self getAttribute:@"NAME"];
	NSString *size=[self getAttribute:@"COLS"];
	NSString *type=[self getAttribute:@"LINES"];
	NSLog(@"<textarea>: %@", [self _attributes]);
	// we should create a NSTextAttachment which includes an NSTextField that is initialized with str
	return str;
}

@end
