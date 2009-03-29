/* simplewebkit
   ECMAScriptParser.m

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

//  syntax for parser is based on overview http://en.wikipedia.org/wiki/WebScript_syntax
//  and ECMAScript specification http://www.ecma-international.org/publications/standards/Ecma-262.htm
//  here are some basics how DOM interaction works and can be tested: http://www.howtocreate.co.uk/tutorials/javascript/dombasics

#import <WebKit/WebDOMOperations.h>
#import <WebKit/WebUndefined.h>
#import <WebKit/WebScriptObject.h>
#import "ECMAScriptParser.h"
#import "ECMAScriptEvaluator.h"

#import "Private.h"

@implementation NSObject (_WebScriptParsing)

- (BOOL) _isIdentifier; { return NO; }
- (BOOL) _isReference; { return NO; }

@end

@interface NSScanner (_WebScriptTreeNode)

// special look-forward scanners for tokens

- (BOOL) _scanToken:(NSString *) str;
- (BOOL) _scanMultiToken:(NSString *) str;	// does not match e.g. "&" with "&="
- (BOOL) _scanIdentifier:(NSString **) str;
- (BOOL) _scanKeyword:(NSString *) str;	// does not match "in" with "int"
- (void) _scanError:(NSString *) message;
- (NSString *) _scanEscape;

@end

@implementation NSScanner (_WebScriptTreeNode)

- (BOOL) _scanToken:(NSString *) str;	// would match "&" with "&="
{
	if(![self scanString:str intoString:NULL])
		return NO;	// no verbatim prefix match
#if 0
	NSLog(@"token scanned: %@", str);
#endif
	return YES;
}

- (BOOL) _scanMultiToken:(NSString *) str;	// does not match "&" with "&="
{
	unsigned back=[self scanLocation];
	if(![self scanString:str intoString:NULL])
		return NO;	// no verbatim prefix match
	if(![self isAtEnd])
		{ // check that next character is a non-token (blank, letter, digit, quote etc.)
		static NSCharacterSet *multi;
		unichar c=[[self string] characterAtIndex:[self scanLocation]];	// next character after token
		if(!multi)
			multi=[[NSCharacterSet characterSetWithCharactersInString:@"+-=&|><"] retain];
		if([multi characterIsMember:c])
			{ // there is a multi-character token but we are looking for the first part only (e.g. we search for "&" but there is "&=")
			[self setScanLocation:back];
			return NO;
			}
		}
#if 0
	NSLog(@"multi token scanned: %@", str);
#endif
	return YES;
}

- (BOOL) _scanIdentifier:(NSString **) str;
{ // get the next identifier - optimize if we have already scanned
	static NSScanner *cachedScanner;
	static unsigned cache=NSNotFound;
	static unsigned cacheEnd=NSNotFound;
	static NSString *cachedIdentifier=nil;
	static NSCharacterSet *symbolCharacterSet=nil;
	unsigned loc=[self scanLocation];
	if(cachedScanner == self && loc == cache && cachedIdentifier)
		{ // was simply backed up since last call
		*str=cachedIdentifier;
		[self setScanLocation:cacheEnd];	// pretend that we have really scanned
#if 0
		NSLog(@"identifier: %@", *str);
#endif
		return YES;
		}
	if(!symbolCharacterSet)
		{ // FIXME: we must allow any Unicode letter or digit (7.6) or _ or $ or \Unicode escape + some punctuation...
		symbolCharacterSet=[[NSCharacterSet characterSetWithCharactersInString:@"_$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] retain];
		}
	[cachedIdentifier release];
	cache=loc;	// remember new position
	cachedIdentifier=@"";
	cachedScanner=self;
	if(![self scanCharactersFromSet:symbolCharacterSet intoString:&cachedIdentifier] || [cachedIdentifier length] == 0)
		{
		cachedIdentifier=nil;
		return NO;
		}
	*str=cachedIdentifier;
	[cachedIdentifier retain];	// store
	cacheEnd=[self scanLocation];	// where to go forward
#if 0
	NSLog(@"identifier cached: %@", *str);
#endif
	return YES;
}

- (BOOL) _scanKeyword:(NSString *) str;	// does not match "in" with "int"
{
	unsigned back=[self scanLocation];
	NSString *ident=@"";
	if([self _scanIdentifier:&ident] && [ident isEqualToString:str])
		{
#if 0
		NSLog(@"keyword scanned: %@", str);
#endif
		return YES;	// ok!
		}
	[self setScanLocation:back];	// back up (and keep in identifier cache)
	return NO;
}

- (void) _scanError:(NSString *) message;
{
	NSString *str=[self string];
	int pos=[self scanLocation];
	unsigned from=MAX(0, pos-10);
	unsigned length=MIN(20, [str length]-pos);
	message=[NSString stringWithFormat:@"%@\n%@\n%@^",
		message,
		[str substringWithRange:NSMakeRange(from, length)],
		// FIXME: pad only as much as from the last \n or \r
		// count characters from last \n before pos
		[@"" stringByPaddingToLength:(from<pos?(pos-from):0) withString:@" " startingAtIndex:0]
		];
	[[NSException exceptionWithName:@"WebScriptSyntaxErrorException" reason:message userInfo:nil] raise];
}

- (NSString *) _scanEscape;
{
	int cnt=4;	// for \uhhhh
	unichar c;
	NSString *str=[self string];
	int pos=[self scanLocation];
	if([self isAtEnd]) return @"";
	c=[str characterAtIndex:pos];
	switch(c)
		{
		case '\n':	return @"";	// ignore
		case 'b':	c=0x0008; break;	// translate
		case 't':	c=0x0009; break;
		case 'n':	c=0x000a; break;
		case 'v':	c=0x000b; break;
		case 'f':	c=0x000c; break;
		case 'r':	c=0x000d; break;
		case '0':	c=0x0000; break;
		case 'x':	cnt=2;
		case 'u':
			{ // \xhh or \uhhhh
				unichar d, v;
				int eof=[str length];
				int i;
				v=0;
				for(i=1; i<=cnt; i++)
					{ // next 2 or 4 must be hex digits
					if(pos+i >= eof)
						break;	// unexpected EOF
					d=[str characterAtIndex:pos+i];
					if(d >= '0' && d <= '9')
						d-='0';
					else if(d >= 'A' && d <= 'F')
						d=(d-'A'+10);
					else if(d >= 'a' && d <= 'f')
						d=(d-'a'+10);
					else
						break;	// return the x or u
					v=(v<<4)+d;
					}
				if(i > cnt)
					{ // valid
					c=v;
					pos+=cnt;
					}
				break;
			}
		}
	[self setScanLocation:pos+1];	// skip character (s)
	return [NSString stringWithCharacters:&c length:1];	// escaped character
}

@end

#if !defined(__mySTEP__) && MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4 

@interface NSCharacterSet (NewlineExtension)
+ (id) newlineCharacterSet;
@end

@implementation NSCharacterSet (NewlineExtension)

+ (id) newlineCharacterSet;
{
	static NSCharacterSet *newline;
	if(!newline)
		newline=[[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] retain];	// FIXME: should also include U+0085
	return newline;
}

@end

#endif

@implementation _WebScriptTreeNode

// parser

+ (void) _skipComments:(NSScanner *) sc;
{ // 7.4
	static NSString *cComment=@"/*";
	 static NSString *cCommentEnd=@"*/";
	 static NSString *cPlusPlusComment=@"//";
										 // switch scanner to skip whitespace
		 while(YES)
			 {
			 [sc setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];	// initially eat all whitespace (but no new lines)
			 if([sc scanString:cPlusPlusComment intoString:NULL])
				 { // until end of line
				 [sc setCharactersToBeSkipped:nil];	// don't end at first whitespace
				 [sc scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
				 }
			 else if([sc scanString:cComment intoString:NULL])
				 {
				 [sc setCharactersToBeSkipped:nil];	// don't end at first whitespace
				 [sc scanUpToString:cCommentEnd intoString:NULL];
				 [sc scanString:cCommentEnd intoString:NULL];	// and eat stop string
																// how to handle the multiline comment rule that inserts a virtual \n?
				 }
			 else
				 return;	// neither
			 }
}

/* expressions 11. */

+ (id) _primaryExpressionWithScanner:(NSScanner *) sc;
{ // PrimaryExpression 11.1
	id r;
	NSString *string;
	unsigned int ui;
	double d;
	[self _skipComments:sc];
	if([sc isAtEnd])
		{
		[sc _scanError:@"unexpected end of file"];
		return nil;	// unexpected EOF
		}
    if([sc _scanToken:@"("])
		{ // grouping operator 11.1.6
		[self _skipComments:sc];
		r=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"syntax error - missing )"];
		}
	else if([sc _scanToken:@"["])
		{ // ArrayLiteral 11.1.4
		NSMutableArray *values=[[NSMutableArray alloc] initWithCapacity:5];
		[self _skipComments:sc];
		if(![sc _scanToken:@"]"])
			{ // not an empty array
			int idx=0;
			for(idx=0; ; idx++)
				{ // collect properties for given indexes
				[self _skipComments:sc];
				if([sc _scanToken:@","])
					{
					[values addObject:[WebUndefined undefined]];	// "hole"
					continue;	// next index
					}
				if([sc _scanToken:@"]"])
					break;
				if([sc isAtEnd])
					{ // error
					[sc _scanError:@"unexpected end of file in [ ... ]"];
					}
				[values addObject:[self _assignmentExpressionWithScanner:sc noIn:NO]];
				[self _skipComments:sc];
				[sc _scanToken:@","];	// skip if present
				}
			}
		r=[_WebScriptTreeNodeArrayLiteralConstructor node:nil :values];	// should call constructor on the Array object like "new Array()"
		[values release];
		}
	else if([sc _scanToken:@"{"])
		{ // ObjectLiteral 11.1.5
		NSMutableArray *keys=[[NSMutableArray alloc] initWithCapacity:5];
		NSMutableArray *values=[[NSMutableArray alloc] initWithCapacity:5];
		[self _skipComments:sc];
		if(![sc _scanToken:@"}"])
			{ // not an empty dictionary
			while(YES)
				{ // collect properties for given indexes
				if([sc isAtEnd])
					break;	// error...
				[keys addObject:[self _assignmentExpressionWithScanner:sc noIn:NO]];
				[self _skipComments:sc];
				if(![sc _scanToken:@":"])
					[sc _scanError:@"missing : in { ... }"];
				[values addObject:[self _assignmentExpressionWithScanner:sc noIn:NO]];
				[self _skipComments:sc];
				if([sc isAtEnd])
					[sc _scanError:@"unexpected end of file in { ... }"];
				if([sc _scanToken:@","])
					continue;	// next index
				if([sc _scanToken:@"}"])
					break;
				}
			}
		r=[_WebScriptTreeNodeObjectLiteralConstructor node:keys :values];	// should call constructor on the Object object like "new Object()"
		[keys release];
		[values release];
		}
	else if([sc _scanToken:@"\""])
		{ // 7.8.4
		static NSCharacterSet *doubleQuoteStopCharacterSet=nil;
		[sc setCharactersToBeSkipped:nil];
		string=@"";
		if(!doubleQuoteStopCharacterSet)
			doubleQuoteStopCharacterSet=[[NSCharacterSet characterSetWithCharactersInString:@"\"\\\n"] retain];
		while(YES)
			{
			NSString *fragment=@"";	// if we immediately hit a stop character
			[sc scanUpToCharactersFromSet:doubleQuoteStopCharacterSet intoString:&fragment];
			string=[string stringByAppendingString:fragment];
			if([sc scanString:@"\\" intoString:NULL])
				string=[string stringByAppendingString:[sc _scanEscape]];	// handle escape sequence
			else
				break;	// stop character (or EOF)
			}
		[sc _scanToken:@"\""];	// should have been a double quote
#if 0
		NSLog(@"parsed string \"%@\"", string);
//		if([string isEqualToString:@"[B]"])
//			NSLog(@"");
#endif
		r=string;
		}
	else if([sc _scanToken:@"'"])
		{ // 7.8.4 string
		static NSCharacterSet *quoteStopCharacterSet=nil;
		[sc setCharactersToBeSkipped:nil];
		string=@"";	// if we immediately hit a stop character
		if(!quoteStopCharacterSet)
			quoteStopCharacterSet=[[NSCharacterSet characterSetWithCharactersInString:@"'\\\n"] retain];
		while(YES)
			{
			NSString *fragment=@"";	// if we immediately hit a stop character
			[sc scanUpToCharactersFromSet:quoteStopCharacterSet intoString:&fragment];
			string=[string stringByAppendingString:fragment];
			if([sc scanString:@"\\" intoString:NULL])
				string=[string stringByAppendingString:[sc _scanEscape]];	// handle escape sequence
			else
				break;	// stop character (or EOF)
			}
		[sc _scanToken:@"'"];	// should be a single quote
		// FIXME: if we need to allow to glue strings together, i.e. "abc"   "def", then check for a second quote and glue fragments together
#if 0
		NSLog(@"parsed string '%@'", string);
#endif
		r=string;
		}
	else if([sc _scanToken:@"/"])
		{ // regexp literal 7.8.5   /pattern/flags
		static NSCharacterSet *slashStopCharacterSet=nil;
		NSString *flags;
		[sc setCharactersToBeSkipped:nil];
		string=@"";	// if we immediately hit a stop character (should never occur since // is a comment)
		if(!slashStopCharacterSet)
			slashStopCharacterSet=[[NSCharacterSet characterSetWithCharactersInString:@"/\\\n"] retain];
		while(YES)
			{
			NSString *fragment=@"";	// if we immediately hit a stop character
			[sc scanUpToCharactersFromSet:slashStopCharacterSet intoString:&fragment];
			string=[string stringByAppendingString:fragment];
			if([sc scanString:@"\\" intoString:NULL])
				string=[string stringByAppendingString:[sc _scanEscape]];	// handle escape sequence
			else
				break;	// stop character (or EOF)
			}
		[sc _scanToken:@"/"];	// should have been a single quote
		if(![sc _scanIdentifier:&flags])	// regexp flags
			flags=@"";
#if 0
		NSLog(@"parsed regexp /%@/%@", string, flags);
#endif
		// r=new RegExp(string, flags)
		r=string;
		}
	else if([sc _scanToken:@"0x"])	// we have setCaseSensitive:NO - which does not harm parsing of identifiers
		{ // 7.8.3
		if(![sc scanHexInt:&ui])
            [sc _scanError:[NSString stringWithFormat:@"invalid hex constant"]];
        r=[NSNumber numberWithDouble:(double) ui];  // Hex ints are converted to double
		}
	else if([sc scanDouble:&d])
		{ // 7.8.3
		r=[NSNumber numberWithDouble:d];
		}
	else
		{ // must be an identifier 7.6
		NSString *string;
		if([sc _scanIdentifier:&string])
			{
			// literals 7.8.1 and 7.8.2
			if([string isEqualToString:@"null"])
				r=[NSNull null];
			else if([string isEqualToString:@"true"])
				r=[NSNumber numberWithBool:YES];
			else if([string isEqualToString:@"false"])
				r=[NSNumber numberWithBool:NO];
			else if([string isEqualToString:@"this"])
				r=[_WebScriptTreeNodeThis node:nil :nil];
			else
				{ // either keyword or a variable/method reference
				static NSArray *reservedWords;
				if(!reservedWords)
					{ // inhibit any other use of reserved words 
					reservedWords=[[NSArray alloc] initWithObjects:
						/* reserved 7.5.2 */
						@"break",
						@"case",
						@"catch",
						@"continue",
						@"default",
						@"delete",
						@"do",
						@"else",
						@"finally",
						@"for",
						@"function",
						@"if",
						@"in",
						@"instanceof",
						@"new",
						@"return",
						@"switch",
						@"this",
						@"throw", 
						@"try", 
						@"typeof", 
						@"var",
						@"void", 
						@"while",
						@"with",
						/* future reserved 7.5.3 */
						@"abstract",
						@"boolean",
						@"byte",
						@"char",
						@"class",
						@"const",
						@"debugger",
						@"double",
						@"enum",
						@"export",
						@"extends",
						@"final",
						@"float",
						@"goto",
						@"implements",
						@"import",
						@"int",
						@"interface",
						@"long",
						@"native",
						@"package",
						@"private",
						@"protected",
						@"public",
						@"short", 
						@"static", 
						@"super", 
						@"synchronized", 
						@"throws", 
						@"transient", 
						@"volatile",
						nil];
					}
				if([reservedWords containsObject:string])
					[sc _scanError:[NSString stringWithFormat:@"unexpected keyword: %@", string]];	// raises exception
				r=[_WebScriptTreeNodeIdentifier node:nil :string];	// return the identifier (evaluation will form a reference)
				}
			}
		else
			{ // invalid symbol
			[sc _scanError:[NSString stringWithFormat:@"unexpected character %C (%04x)",
					[[sc string] characterAtIndex:[sc scanLocation]],
					[[sc string] characterAtIndex:[sc scanLocation]]
					]];
			r=nil;
			}
		}
	return r;
}

+ (id) _lhsExpressionWithScanner:(NSScanner *) sc forNew:(BOOL) flag;
{ // Left Hand Side Expression 11.2
	id l;
	if([sc _scanKeyword:@"new"])
		{ // new xxx (arguments)
		[self _skipComments:sc];
		l=[self _lhsExpressionWithScanner:sc forNew:YES];
		if([l isKindOfClass:[_WebScriptTreeNodeCall class]])
			l=[_WebScriptTreeNodeNew node:((_WebScriptTreeNodeCall*)l)->left :((_WebScriptTreeNodeCall *)l)->right];
		else
			l=[_WebScriptTreeNodeNew node:l :nil];	// no arguments
		}
	else if([sc _scanKeyword:@"function"])
		{ // function xx (arguments) { body }
		l=[self _functionExpressionWithScanner:sc optIdentifier:YES]; // allow anonymous functions
		}
	else
		l=[self _primaryExpressionWithScanner:sc];
	while(![sc isAtEnd])
		{ // suffix operators may follow
		[self _skipComments:sc];
		if([sc _scanToken:@"("])
			{ // function call
			NSMutableArray *arglist=[[NSMutableArray alloc] initWithCapacity:5];	// argument list - 11.2.4
			[self _skipComments:sc];
			if(![sc _scanToken:@")"])
				{
				do
					{
					[self _skipComments:sc];
					[arglist addObject:[self _assignmentExpressionWithScanner:sc noIn:flag]];
					[self _skipComments:sc];
					} while([sc _scanToken:@","]);
				if(![sc _scanToken:@")"])
					[sc _scanError:@"missing ) in function(arguments)"];
				}
			l=[_WebScriptTreeNodeCall node:l :arglist];
			[arglist release];
			if(flag)
				break;	// only one argument list for each new
			}
		else if([sc _scanToken:@"["])
			{ // array/object indexing - 11.2.1
			[self _skipComments:sc];
			l=[_WebScriptTreeNodeIndex node:l :[self _expressionWithScanner:sc noIn:NO]];
			[self _skipComments:sc];
			if(![sc _scanToken:@"]"])
				[sc _scanError:@"missing ] in object[index]"];
			}
		else if([sc _scanToken:@"."])
			{ // apply and make a reference
			id r;
			[self _skipComments:sc];
			r=[self _primaryExpressionWithScanner:sc];
			if(![r _isIdentifier])
				[sc _scanError:@"not an identifier in object.identifier"];
			l=[_WebScriptTreeNodeIndex node:l :[r getIdentifier]];	// convert to index expression
			}
		else
			break;
		}
	return l;
}

+ (id) _postfixExpressionWithScanner:(NSScanner *) sc;
{ // 11.3
	id l;
	l=[self _lhsExpressionWithScanner:sc forNew:NO];	// allow any number of function evaluations
	// no new line allowed here but comments...
	if([sc _scanToken:@"++"])
		{ // 11.3.1
		l=[_WebScriptTreeNodePostfix node:l :nil];
		((_WebScriptTreeNodePostfix *)l)->op=PlusPlus;
		}
	else if([sc _scanToken:@"--"])
		{ // 11.3.2
		l=[_WebScriptTreeNodePostfix node:l :nil];
		((_WebScriptTreeNodePostfix *)l)->op=MinusMinus;
		}
	return l;
}

+ (id) _unaryExpressionWithScanner:(NSScanner *) sc;
{
	id r;
	[self _skipComments:sc];
	if([sc _scanKeyword:@"delete"])
		{ // 11.4.1
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Delete;
		}
	else if([sc _scanKeyword:@"void"])
		{ // 11.4.2
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Void;
		}
	else if([sc _scanKeyword:@"typeof"])
		{ // 11.4.3
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Typeof;
		}
	else if([sc _scanToken:@"++"])
		{ // 11.4.4
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=UPlusPlus;
		}
	else if([sc _scanToken:@"--"])
		{ // 11.4.5
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=UMinusMinus;
		}
	else if([sc _scanMultiToken:@"+"])
		{ // 11.4.6
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Plus;
		}
	else if([sc _scanMultiToken:@"-"])
		{ // 11.4.7
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Minus;
		}
	else if([sc _scanMultiToken:@"~"])
		{ // 11.4.8
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Neg;
		}
	else if([sc _scanMultiToken:@"!"])
		{ // logical not
		r=[_WebScriptTreeNodeUnary node:nil :[self _unaryExpressionWithScanner:sc]];
		((_WebScriptTreeNodeUnary *)r)->op=Not;
		}
	else
		r=[self _postfixExpressionWithScanner:sc];
	return r;
}

+ (id) _multiplicativeExpressionWithScanner:(NSScanner *) sc;
{ // 11.5
	id l;
	l=[self _unaryExpressionWithScanner:sc];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"*"])
			{ // 11.5.1
			l=[_WebScriptTreeNodeMultiplicative node:l :[self _unaryExpressionWithScanner:sc]];
			((_WebScriptTreeNodeMultiplicative *)l)->op=Mult;
			}
		else if([sc _scanMultiToken:@"/"])
			{ // 11.5.2
			l=[_WebScriptTreeNodeMultiplicative node:l :[self _unaryExpressionWithScanner:sc]];
			((_WebScriptTreeNodeMultiplicative *)l)->op=Div;
			}
		else if([sc _scanMultiToken:@"%"])
			{ // 11.5.3
			l=[_WebScriptTreeNodeMultiplicative node:l :[self _unaryExpressionWithScanner:sc]];
			((_WebScriptTreeNodeMultiplicative *)l)->op=Mod;
			}
		else
			break;
		}
	return l;
}

+ (id) _additiveExpressionWithScanner:(NSScanner *) sc;
{ // 11.6
	id l;
	l=[self _multiplicativeExpressionWithScanner:sc];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"+"])
			{ // 11.6.1
			l=[_WebScriptTreeNodeAdditive node:l :[self _multiplicativeExpressionWithScanner:sc]];
			((_WebScriptTreeNodeAdditive *)l)->op=Add;
			}
		else if([sc _scanMultiToken:@"-"])
			{ // 11.6.2
			l=[_WebScriptTreeNodeAdditive node:l :[self _multiplicativeExpressionWithScanner:sc]];
			((_WebScriptTreeNodeAdditive *)l)->op=Sub;
			}
		else
			break;
		}
	return l;
}

+ (id) _shiftExpressionWithScanner:(NSScanner *) sc;
{ // 11.7
	id l;
	l=[self _additiveExpressionWithScanner:sc];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"<<"])
			{ // 11.7.1
			l=[_WebScriptTreeNodeShift node:l :[self _additiveExpressionWithScanner:sc]];
			((_WebScriptTreeNodeShift *)l)->op=Shl;
			}
		else if([sc _scanMultiToken:@">>>"])
			{ // 11.7.3
			l=[_WebScriptTreeNodeShift node:l :[self _additiveExpressionWithScanner:sc]];
			((_WebScriptTreeNodeShift *)l)->op=UShr;
			}
		else if([sc _scanMultiToken:@">>"])
			{ // 11.7.2
			l=[_WebScriptTreeNodeShift node:l :[self _additiveExpressionWithScanner:sc]];
			((_WebScriptTreeNodeShift *)l)->op=Shr;
			}
		else
			break;
		}
	return l;
}

+ (id) _relationalExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.8
	id l;
	l=[self _shiftExpressionWithScanner:sc];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanToken:@"<="])
			{ // 11.8.3
			l=[_WebScriptTreeNodeRelational node:l :[self _shiftExpressionWithScanner:sc]];
			((_WebScriptTreeNodeRelational *)l)->op=LessEqual;
			}
		else if([sc _scanToken:@">="])
			{ // 11.8.4
			l=[_WebScriptTreeNodeRelational node:[self _shiftExpressionWithScanner:sc] :l];	// swapped operands
			((_WebScriptTreeNodeRelational *)l)->op=LessEqual;
			}
		else if([sc _scanMultiToken:@"<"])
			{ // 11.8.1
			l=[_WebScriptTreeNodeRelational node:l :[self _shiftExpressionWithScanner:sc]];
			((_WebScriptTreeNodeRelational *)l)->op=LessThan;
			}
		else if([sc _scanMultiToken:@">"])
			{ // 11.8.2
			l=[_WebScriptTreeNodeRelational node:[self _shiftExpressionWithScanner:sc] :l];	// swapped operands
			((_WebScriptTreeNodeRelational *)l)->op=LessThan;
			}
		else if([sc _scanKeyword:@"instanceof"])
			{ // 11.8.6
			l=[_WebScriptTreeNodeRelational node:l :[self _shiftExpressionWithScanner:sc]];
			((_WebScriptTreeNodeRelational *)l)->op=InstanceOf;
			}
		else if(!flag && [sc _scanKeyword:@"in"])
			{ // 11.8.7
			l=[_WebScriptTreeNodeRelational node:l :[self _shiftExpressionWithScanner:sc]];
			((_WebScriptTreeNodeRelational *)l)->op=In;
			}
		else 
			break;
		}
	return l;
}

+ (id) _equalityExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.9
	id l;
	l=[self _relationalExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanToken:@"==="])
			{ // 11.9.4
			l=[_WebScriptTreeNodeEquality node:l :[self _relationalExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeEquality *)l)->equal=YES;
			((_WebScriptTreeNodeEquality *)l)->strict=YES;
			}
		else if([sc _scanToken:@"!=="])
			{ // 11.9.5
			l=[_WebScriptTreeNodeEquality node:l :[self _relationalExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeEquality *)l)->strict=YES;
			}
		else if([sc _scanMultiToken:@"=="])
			{ // 11.9.1
			l=[_WebScriptTreeNodeEquality node:l :[self _relationalExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeEquality *)l)->equal=YES;
			}
		else if([sc _scanMultiToken:@"!="])
			{ // 11.9.2
			l=[_WebScriptTreeNodeEquality node:l :[self _relationalExpressionWithScanner:sc noIn:flag]];
			}
		else
			break;
		}
	return l;
}

+ (id) _bitwiseAndExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.10 (a)
	id l;
	l=[self _equalityExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"&"])
			{
			l=[_WebScriptTreeNodeBitwise node:l :[self _equalityExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeBitwise *)l)->op=And;
			}
		else
			break;
		}
	return l;
}

+ (id) _bitwiseXorExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.10 (b)
	id l;
	l=[self _bitwiseAndExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"^"])
			{
			l=[_WebScriptTreeNodeBitwise node:l :[self _bitwiseAndExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeBitwise *)l)->op=Xor;
			}
		else
			break;
		}
	return l;
}

+ (id) _bitwiseOrExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.10 (c)
	id l;
	l=[self _bitwiseXorExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanMultiToken:@"|"])
			{
			l=[_WebScriptTreeNodeBitwise node:l :[self _bitwiseXorExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeBitwise *)l)->op=Or;
			}
		else
			break;
		}
	return l;
}

+ (id) _logicalAndExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.11 (a)
	id l;
	l=[self _bitwiseOrExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanToken:@"&&"])
			{ // logical and operator
			l=[_WebScriptTreeNodeLogical node:l :[self _bitwiseOrExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeLogical *)l)->op=LAnd;
			}
		else
			break;	// done
		}
	return l;
}

+ (id) _logicalOrExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.11 (b)
	id l;
	l=[self _logicalAndExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanToken:@"||"])
			{ // logical or operator
			l=[_WebScriptTreeNodeLogical node:l :[self _logicalAndExpressionWithScanner:sc noIn:flag]];
			((_WebScriptTreeNodeLogical *)l)->op=LOr;
			}
		else
			break;	// done
		}
	return l;
}

+ (id) _conditionalExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.12
	id l, r;
	l=[self _logicalOrExpressionWithScanner:sc noIn:flag];
	[self _skipComments:sc];
	if([sc _scanToken:@"?"])
		{ // conditional operator
		r=[self _assignmentExpressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@":"])
			[sc _scanError:@"missing : in c?a:b"];
		l=[_WebScriptTreeNodeConditional node:l :r];
		((_WebScriptTreeNodeConditional *)l)->otherwise=[[self _assignmentExpressionWithScanner:sc noIn:flag] retain];
		}
	return l;
}

+ (id) _assignmentExpressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.13
	id l;
	l=[self _conditionalExpressionWithScanner:sc noIn:flag];
	[self _skipComments:sc];
	if([sc _scanToken:@"="])
		{ // assignment operator - right associative
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=Assign;
		}
	else if([sc _scanToken:@"*="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=MultAssign;
		}
	else if([sc _scanToken:@"/="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=DivAssign;
		}
	else if([sc _scanToken:@"%="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=ModAssign;
		}
	else if([sc _scanToken:@"+="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=PlusAssign;
		}
	else if([sc _scanToken:@"-="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=MinusAssign;
		}
	else if([sc _scanToken:@"<<="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=ShlAssign;
		}
	else if([sc _scanToken:@">>>="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=UShrAssign;
		}
	else if([sc _scanToken:@">>="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=ShrAssign;
		}
	else if([sc _scanToken:@"&="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=AndAssign;
		}
	else if([sc _scanToken:@"^="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=XorAssign;
		}
	else if([sc _scanToken:@"|="])
		{
		l=[_WebScriptTreeNodeAssignment node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeAssignment *)l)->op=OrAssign;
		}
	// etc.
	return l;
}

+ (id) _expressionWithScanner:(NSScanner *) sc noIn:(BOOL) flag;
{ // 11.14
	id l;
	l=[self _assignmentExpressionWithScanner:sc noIn:flag];
	while(YES)
		{
		[self _skipComments:sc];
		if([sc _scanToken:@","])
			{ // comma operator
			[self _skipComments:sc];
			l=[_WebScriptTreeNodeComma node:l :[self _assignmentExpressionWithScanner:sc noIn:flag]];
			}
		else
			break;
		}
	return l;
}

/* statements 12. */

+ (id) _statementWithScanner:(NSScanner *) sc;
{
	id r=nil;
	[self _skipComments:sc];
	if([sc _scanToken:@"{"])
		{ // statement list
		r=[self _statementWithScanner:sc];
		[self _skipComments:sc];
		while(![sc _scanToken:@"}"])
			{
			if([sc isAtEnd])
				[sc _scanError:@"missing } in { statement block }"];
			if([sc _scanToken:@";"])
				continue;	// ignore empty statements
			r=[_WebScriptTreeNodeStatementList node:r :[self _statementWithScanner:sc]];
			[self _skipComments:sc];
			}
		return r;
		}
	if([sc _scanToken:@";"])
		return nil;	// empty statement if we can't avoid...
	if([sc _scanKeyword:@"var"])
		{ // 12.2 - variable declaration (list)
		r=nil;
		[self _skipComments:sc];
		while(YES)
			{
			id l=[self _primaryExpressionWithScanner:sc];
			if(![l isKindOfClass:[_WebScriptTreeNodeIdentifier class]])
				[sc _scanError:@"missing identifier in var statement"];
			[self _skipComments:sc];
			if([sc _scanToken:@"="])
				l=[_WebScriptTreeNodeVar node:l :[self _assignmentExpressionWithScanner:sc noIn:NO]];
			else
				l=[_WebScriptTreeNodeVar node:l :nil];	// will assign undefined
			[self _skipComments:sc];
			if(![sc _scanToken:@","])
				break;
			if(r)
				r=[_WebScriptTreeNodeStatementList node:r :l];	// chain
			else
				r=l;
			}
		}
	else if([sc _scanKeyword:@"if"])
		{ // 12.5
		id l;
		[self _skipComments:sc];
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in if(expr) statement"];
		[self _skipComments:sc];
		l=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in if(expr) statement"];
		r=[_WebScriptTreeNodeIf node:l :[self _statementWithScanner:sc]];
		[self _skipComments:sc];
		if([sc _scanKeyword:@"else"])
			{
			[self _skipComments:sc];
			((_WebScriptTreeNodeIf *) r)->otherwise=[[self _statementWithScanner:sc] retain];
			}
		}
	else if([sc _scanKeyword:@"do"])
		{ // 12.6.1
		id l;
		[self _skipComments:sc];
		r=[self _statementWithScanner:sc];
		[self _skipComments:sc];
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in do statement while(expr)"];
		[self _skipComments:sc];
		l=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in do statement while(expr)"];
		r=[_WebScriptTreeNodeIteration node:l :r];
		((_WebScriptTreeNodeIteration *)r)->op=Do;
		}
	else if([sc _scanKeyword:@"while"])
		{ // 12,6,2
		id l;
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in while(expr) statement"];
		[self _skipComments:sc];
		l=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in while(expr) statement"];
		[self _skipComments:sc];
		r=[_WebScriptTreeNodeIteration node:l :[self _statementWithScanner:sc]];
		((_WebScriptTreeNodeIteration *)r)->op=While;
		}
	else if([sc _scanKeyword:@"for"])
		{ // 12.6.4 & 12.6.4 - for(a; b; c) statement or for(d in e) statement
		id init=nil;	// initialization
		id cond=nil;	// condition
		id inc=nil;		// continue & increment part
		BOOL forIn=NO;
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in for(...) statement"];
		[self _skipComments:sc];
		if(![sc _scanToken:@";"])
			{ // for(x in ...
			if([sc _scanKeyword:@"var"])
				{ // with var declaration list - move declaration outside of the for loop
				NIMP;
				}
			init=[self _expressionWithScanner:sc noIn:YES];	// first expression - no in!
			[self _skipComments:sc];
			if([sc _scanKeyword:@"in"])
				{ // for(variable in expression)
				forIn=YES;
				// init must be an lhs, i.e. a WebTreeReference
				// setup the enumerator
				// make loop enumerate into the lhs variable
				// condition becomes false if there isn't anything more to get
				[self _skipComments:sc];
				cond=[self _expressionWithScanner:sc noIn:NO];	// object to enumerate
				[self _skipComments:sc];
				if(![sc _scanToken:@")"])
					[sc _scanError:@"missing ) in for(x in expr) statement"];
				[self _skipComments:sc];
				r=[_WebScriptTreeNodeIteration node:cond :[self _statementWithScanner:sc]];
				((_WebScriptTreeNodeIteration *)r)->op=ForIn;	// make virtual while loop with inc part
				}
			else if(![sc _scanToken:@";"])
				[sc _scanError:@"missing first ; in for(...) statement"];
			}
		if(!forIn)
			{ // in-version already tried
			if(![sc _scanToken:@";"])
				{ // not an empty condition
				cond=[self _expressionWithScanner:sc noIn:NO];	// second expression
				[self _skipComments:sc];
				if(![sc _scanToken:@";"])
					[sc _scanError:@"missing second ; in for(...) statement"];
				}
			if(![sc _scanToken:@")"])
				{ // not an empty increment
				inc=[self _expressionWithScanner:sc noIn:NO];	// second expression
				[self _skipComments:sc];
				if(![sc _scanToken:@")"])
					[sc _scanError:@"missing ) in for(...) statement"];
				}
			[self _skipComments:sc];
			r=[_WebScriptTreeNodeIteration node:cond :[self _statementWithScanner:sc]];
			((_WebScriptTreeNodeIteration *)r)->op=While;	// make virtual while loop with inc part
			((_WebScriptTreeNodeIteration *)r)->inc=inc;
			}
		if(init)
			r=[_WebScriptTreeNodeIteration node:init :r];	// initialize first and then loop
		}
	else if([sc _scanKeyword:@"continue"])
		{ // 12.7
		r=nil;
		if(![sc _scanToken:@";"] && ![sc scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL])
			r=[self _primaryExpressionWithScanner:sc];
			// Check that it is really an identifier!
		r=[_WebScriptTreeNodeIteration node:nil :r];
		((_WebScriptTreeNodeIteration *)r)->op=Continue;		
		}
	else if([sc _scanKeyword:@"break"])
		{ // 12.8
		r=nil;
		if(![sc _scanToken:@";"] && ![sc scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL])
			r=[self _primaryExpressionWithScanner:sc];
		// Check that it is really an identifier!
		r=[_WebScriptTreeNodeIteration node:nil :r];
		((_WebScriptTreeNodeIteration *)r)->op=Break;		
		}
	else if([sc _scanKeyword:@"return"])
		{ // 12.9
		r=nil;
		if(![sc _scanToken:@";"] && ![sc scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL])
			r=[self _expressionWithScanner:sc noIn:NO];
		r=[_WebScriptTreeNodeReturn node:nil :r];
		((_WebScriptTreeNodeReturn *) r)->op=Return;
		}
	else if([sc _scanKeyword:@"with"])
		{ // 12.10
		id l;
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in with(object) expression"];
		[self _skipComments:sc];
		l=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in with(object) expression"];
		r=[_WebScriptTreeNodeWith node:l :[self _expressionWithScanner:sc noIn:NO]];
		}
	else if([sc _scanKeyword:@"switch"])
		{ // 12.11
		NSMutableArray *cases=[NSMutableArray new];
		NSMutableArray *statements=[NSMutableArray new];
		r=[_WebScriptTreeNodeSwitch node:cases :statements];
		[self _skipComments:sc];
		if(![sc _scanToken:@"("])
			[sc _scanError:@"missing ( in switch(expr) block"];
		[self _skipComments:sc];
		((_WebScriptTreeNodeSwitch *) r)->expr=[[self _expressionWithScanner:sc noIn:NO] retain];
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in switch(expr) block"];
		// go through statement block, collect case+statements and add them to the arrays
		// "default" is added to ((_WebScriptTreeNodeReturn *) r)->otherwise
		// can check for multiple defaults
			[cases release];
			[statements release];
		}
	else if([sc _scanKeyword:@"throw"])
		{ // 12.13
		[self _skipComments:sc];
		r=[_WebScriptTreeNodeReturn node:nil :[self _expressionWithScanner:sc noIn:NO]];
		((_WebScriptTreeNodeReturn *) r)->op=Throw;
		}
	else if([sc _scanKeyword:@"try"])
		{ // 12.13
		id ident=nil;	// if no catch block
		id catch=nil;
		[self _skipComments:sc];
		r=[self _statementWithScanner:sc];	// should enforce to be a block!
		[self _skipComments:sc];
		if([sc _scanKeyword:@"catch"])
			{ // has catch part
			[self _skipComments:sc];
			if(![sc _scanToken:@"("])
				[sc _scanError:@"missing ( in catch(ident) block"];
			if(![sc _scanIdentifier:&ident])
				[sc _scanError:@"missing identifier in catch(ident) block"];
			if(![sc _scanToken:@")"])
				[sc _scanError:@"missing ) in catch(ident) block"];
			catch=[self _statementWithScanner:sc];	// should enforce to be a block!
			}
		r=[_WebScriptTreeNodeTry node:ident :r];
		((_WebScriptTreeNodeTry *) r)->catch=[catch retain];
		[self _skipComments:sc];
		if([sc _scanKeyword:@"finally"])
			{ // has finally part
			[self _skipComments:sc];
			((_WebScriptTreeNodeTry *) r)->finally=[[self _statementWithScanner:sc] retain];	// should enforce to be a block!
			}
		if(!((_WebScriptTreeNodeTry *) r)->catch && !((_WebScriptTreeNodeTry *) r)->finally)
			[sc _scanError:@"try must have catch and/or finally"];
		}
	else
		{ // 12.4
		r=[self _expressionWithScanner:sc noIn:NO];
		[self _skipComments:sc];
		if([r isKindOfClass:[_WebScriptTreeNodeIdentifier class]] && [sc _scanToken:@":"])
			{ // label
			r=[_WebScriptTreeNodeLabel node:r :[self _statementWithScanner:sc]];
			}
		}
	[self _skipComments:sc];
	[sc _scanToken:@";"];	// skip if present
	return r;
}

/* functions 13. */

+ (id) _functionExpressionWithScanner:(NSScanner *) sc optIdentifier:(BOOL) flag; 
{
	id r;
	NSString *ident=nil;	// function name
	NSMutableArray *params=[NSMutableArray new];
	[self _skipComments:sc];
	if(![sc _scanIdentifier:&ident] && !flag)
		[sc _scanError:@"missing name in function name (parameters) { body }"];
	[self _skipComments:sc];
	if(![sc _scanToken:@"("])
		[sc _scanError:@"missing ( in function (parameters) { body }"];
	[self _skipComments:sc];
	if(![sc _scanToken:@")"])
		{
		while(YES)
			{
			NSString *param;
			[self _skipComments:sc];
			if([sc isAtEnd])
				[sc _scanError:@"unexpected EOF in function (parameters)"];
			if(![sc _scanIdentifier:&param])
				[sc _scanError:@"missing parameter name in function name (parameters) { body }"];
			[params addObject:param];
			[self _skipComments:sc];
			if(![sc _scanToken:@","])
				break;
			}
		[self _skipComments:sc];
		if(![sc _scanToken:@")"])
			[sc _scanError:@"missing ) in function (parameters) { body }"];
		}
	r=[_WebScriptTreeNodeFunction node:ident :[self _programWithScanner:sc block:YES]];	// return on closing }
	((_WebScriptTreeNodeFunction *)r)->params=params;
	return r;
}

/* program 14. */

+ (id) _programWithScanner:(NSScanner *) sc block:(BOOL) flag;
{
	id r=nil;
	if(flag)
		{
		if(![sc _scanToken:@"{"])
			[sc _scanError:@"missing { in function (parameters) { body }"];
		}
	while(YES)
		{
		id s;
		[self _skipComments:sc];
		if([sc scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL])
			continue;	// empty statement
		if(flag && [sc _scanToken:@"}"])
			break;
		if([sc isAtEnd])
			{
			if(flag)
				[sc _scanError:@"missing } in function (parameters) { body }"];
			break;
			}
		if([sc _scanKeyword:@"function"])
			{
			[self _skipComments:sc];
			s=[self _functionExpressionWithScanner:sc optIdentifier:NO];
			}
		else
			s=[self _statementWithScanner:sc];
		if(r)
			r=[_WebScriptTreeNodeStatementList node:r :s];	// concatentate
		else
			r=s;	// first
		}
	return r;
}

/* *** */

+ (id) node:(id) l :(id) r;
{ // create a new node (not released!)
	_WebScriptTreeNode *n=[self alloc];
	n->left=[l retain];
	n->right=[r retain];
	return n;
}

- (void) dealloc;
{
	[left release];
	[right release];
	[super dealloc];
}

- (NSString *) description;
{ // generates the tree
	return [NSString stringWithFormat:@"%@%@%@%@%@%@", NSStringFromClass(isa), left?@"(":@"", left?left:@"", right?left?@", ":@"(":@"", right?right:@"", left||right?@")":@""];
}

@end

@implementation _WebScriptTreeNodeArrayLiteralConstructor
@end

@implementation _WebScriptTreeNodeObjectLiteralConstructor
@end

@implementation _WebScriptTreeNodeThis
@end

@implementation _WebScriptTreeNodeIdentifier

- (BOOL) _isIdentifier; { return YES; }
- (NSString *) getIdentifier; { return right; }

@end

@implementation _WebScriptTreeNodeReference

- (NSString *) description;
{
	return [NSString stringWithFormat:@"%@: base.%@", [super description], right];
}

- (WebScriptObject *) getBase; { return left; }
- (NSString *) getPropertyName; { return right; }

- (BOOL) _isReference; { return YES; }

@end

@implementation _WebScriptTreeNodeNew
@end

@implementation _WebScriptTreeNodeCall
@end

@implementation _WebScriptTreeNodeIndex
@end

@implementation _WebScriptTreeNodePostfix
@end

@implementation _WebScriptTreeNodeUnary
@end

@implementation _WebScriptTreeNodeMultiplicative
@end

@implementation _WebScriptTreeNodeAdditive
@end

@implementation _WebScriptTreeNodeShift
@end

@implementation _WebScriptTreeNodeRelational
@end

@implementation _WebScriptTreeNodeEquality
@end

@implementation _WebScriptTreeNodeBitwise
@end

@implementation _WebScriptTreeNodeLogical
@end

@implementation _WebScriptTreeNodeConditional

- (void) dealloc;
{
	[otherwise release];
	[super dealloc];
}

@end

@implementation _WebScriptTreeNodeAssignment
@end

@implementation _WebScriptTreeNodeComma	// comma operator
@end

@implementation _WebScriptTreeNodeStatementList
@end

@implementation _WebScriptTreeNodeVar
@end

@implementation _WebScriptTreeNodeIf

- (void) dealloc;
{
	[otherwise release];
	[super dealloc];
}

@end

@implementation _WebScriptTreeNodeIteration : _WebScriptTreeNode

- (void) dealloc;
{
	[inc release];
	[super dealloc];
}

@end

@implementation _WebScriptTreeNodeReturn : _WebScriptTreeNode
@end

@implementation _WebScriptTreeNodeLabel : _WebScriptTreeNode
@end

@implementation _WebScriptTreeNodeSwitch : _WebScriptTreeNode

- (void) dealloc;
{
	[expr release];
	[otherwise release];
	[super dealloc];
}

@end

@implementation _WebScriptTreeNodeTry: _WebScriptTreeNode

- (void) dealloc;
{
	[catch release];
	[finally release];
	[super dealloc];
}

@end

@implementation _WebScriptTreeNodeWith
@end

@implementation _WebScriptTreeNodeFunction : _WebScriptTreeNode

- (void) dealloc;
{
	[params release];
	[super dealloc];
}

@end

