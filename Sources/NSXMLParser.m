/* simplewebkit
NSXMLParser.m

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

#ifndef __WebKit__	// allows us to disable parts when we #include into WebKit

#import <Foundation/NSXMLParser.h>
#import "../../Foundation/Sources/NSPrivate.h"	// this is for mySTEP source tree compatibility only!

NSString *const NSXMLParserErrorDomain=@"NSXMLParserErrorDomain";

#else

@interface NSString (NSPrivate)
+ (NSString *) _string:(void *) bytes withEncoding:(NSStringEncoding) encoding length:(int) len;	// would have been declared in NSPrivate.h
@end

#endif

@implementation NSString (NSXMLParser)

- (NSString *) _stringByExpandingXMLEntities;
{
	NSMutableString *t=[NSMutableString stringWithString:self];
	[t replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [t length])];	// must be first!
	[t replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0, [t length])];
	return t;
}

+ (NSString *) _string:(void *) bytes withEncoding:(NSStringEncoding) encoding length:(int) len;
{ // convert tags, values, etc.
	NSData *d;
	NSString *str;
	if(len < 0)
		return nil;	// may occur with incomplete html files
	d=[NSData dataWithBytesNoCopy:(char *) bytes length:len freeWhenDone:NO];
	//	NSLog(@"%p:%@", d, d);
	str=[[NSString alloc] initWithData:d encoding:encoding];
	if(!str)
		str=[[NSString alloc] initWithData:d encoding:NSMacOSRomanStringEncoding];	// system default
	return [str autorelease];
}

@end

@implementation NSXMLParser

static NSDictionary *entitiesTable;

- (id) init;
{
	if((self=[super init]))
		{
		tagPath=[[NSMutableArray alloc] init];
		encoding=NSUTF8StringEncoding;	// default
		acceptHTML=YES;	// default
		}
	return self;
}

- (id) initWithData:(NSData *) d;
{
	if(!d)
		{
		[self release];
		return nil;
		}
	if((self=[self init]))
		{
		data=[d retain];
		}
	return self;
}

- (id) initWithContentsOfURL:(NSURL *) u;
{
	if(!u)
		{
		[self release];
		return nil;
		}
	if((self=[self init]))
		{
		url=[u retain];
		}
	return self;
}

- (void) dealloc;
{
#if 0
	NSLog(@"dealloc %@: %@", NSStringFromClass(isa), self);
#endif
	[data release];
	[buffer release];
	[error release];
	[tagPath release];
	[super dealloc];
}

- (BOOL) _parseError:(NSXMLParserError) err message:(NSString *) msg;
{
	NSError *e=[NSError errorWithDomain:NSXMLParserErrorDomain code:err userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msg, @"Message", nil]];
#if 0
	NSLog(@"XML parseError: %u - %@", err, msg);
#endif
	ASSIGN(error, e);
	if([delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
		[delegate parser:self parseErrorOccurred:error];	// pass error to delegate
	return NO;
}

- (void) abortParsing;
{
	[self _parseError:NSXMLParserDelegateAbortedParseError message:@"abortParsing called"];
}

- (int) columnNumber; { return column; }
- (int) lineNumber; { return line; }
- (id) delegate; { return delegate; }
- (void) setDelegate:(id) del; { delegate=del; }	// not retained!
- (NSError *) parserError; { return error; }

- (void) _processTag:(NSString *) tag isEnd:(BOOL) flag withAttributes:(NSDictionary *) attributes;
{
#if 0
	NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
	if(acceptHTML)
		tag=[tag lowercaseString];	// HTML is not case sensitive
	if(!flag)
		{
		if([tag isEqualToString:@"?xml"])
			{ // parse, i.e. check for UTF8 encoding and other attributes
			  // FIXME: check encoding
			  // check that it is the first tag of all
			acceptHTML=NO;	// enforce strict syntax
#if 0
			NSLog(@"parserDidStartDocument:");
#endif
			if([delegate respondsToSelector:@selector(parserDidStartDocument:)])
				[delegate parserDidStartDocument:self];
			return;
			}
		if([tag hasPrefix:@"?"])
			{
#if 0
			NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
			// parser:foundProcessingInstructionWithTarget:data:
			return;
			}
		if([tag hasPrefix:@"!"])
			{
			if([tag isEqualToString:@"!DOCTYPE"])
				{
#if 1	// we could even be strict if document pretends to be X(HT)ML
				if([attributes objectForKey:@"html"])
					{ // <!DOCTYPE html ...>
					acceptHTML=YES;	// switch back to HTML lazy mode because people don't really comply to XHTML...
					return;
					}
#endif
#if 0
				NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
				return;
				}
			if([tag isEqualToString:@"!ENTITY"])
				{ // parse
#if 0
				NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
				// [delegate parser:self foundEntity:data];
				return;
				}
			return;	// don't push
			}
		[tagPath addObject:tag];	// push on stack
									// FIXME: optimize speed by getting IMP when setting the delegate
		if([delegate respondsToSelector:@selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:)])
			[delegate parser:self didStartElement:tag namespaceURI:nil qualifiedName:nil attributes:attributes];
		}
	else
		{ // closing tag
		if(acceptHTML)
			{ // lazily close any missing intermediate tags on stack, i.e. <table><tr><td>Data</tr></tbl> -> insert </td>, ignore </tbl>
			if(![tagPath containsObject:tag])
				return;	// ignore closing tag without a matching open...
			while([tagPath count] > 0 && ![[tagPath lastObject] isEqualToString:tag])	// must be literally equal!
				{ // close all in between
				if([delegate respondsToSelector:@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
					[delegate parser:self didEndElement:[tagPath lastObject] namespaceURI:nil qualifiedName:nil];
				// FIXME: we don't stall here in between!!!
				[tagPath removeLastObject];	// pop from stack
				}
			}
		else if(![[tagPath lastObject] isEqualToString:tag])	// must be literally equal!
			{
			[self _parseError:NSXMLParserNotWellBalancedError message:[NSString stringWithFormat:@"tag nesting error (</%@> expected, </%@> found)", [tagPath lastObject], tag]];
			return;
			}
		if([delegate respondsToSelector:@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
			[delegate parser:self didEndElement:tag namespaceURI:nil qualifiedName:nil];
		[tagPath removeLastObject];	// pop from stack
		}
}

- (void) _parseData:(NSData *) d;
{ // incremental parser - tries to do its best and reports/removes only complete elements; returns otherwise (or raises exceptions)
	const char *ep=NULL;
#if 0
	NSLog(@"parse data=%@", d);
#endif
	if(error)
		return;	// ignore this junk of input data if there was already a parse error
	if(!d)
		{ // notifies end of data
		done=YES;
		}
	if(!buffer || cp == ep)
		{ // first fragment or we have processed the current buffer completely (that should happen regularily when we end between tags
		[buffer release];	// for the second condition...
		buffer=[d copy];	// should make a copy only if really needed!
		cp=[buffer bytes];
		}
	else if([d length] > 0)
		{ // append to new buffer
		unsigned cpoff=cp-(char *)[buffer bytes];	// get current offset
		if(![buffer isKindOfClass:[NSMutableData class]])
			{ // make a mutable copy
			NSData *b=buffer;				// remember
			buffer=[buffer mutableCopy];	// replace previous buffer by a mutable copy
			[b release];					// release previous (immutable) buffer
			}
		[(NSMutableData *) buffer appendData:d];	// append new fragment
		cp=(const char *) [buffer bytes]+cpoff;
		}
	ep=(const char *) [buffer bytes]+[buffer length];
#if 0
	NSLog(@"[d length]=%d [buffer length]=%d buffer=%p cp=%p ep=%p", [d length], [buffer length], [buffer bytes], cp, ep);
#endif
	//
	// FIXME:
	// splitting up into special functions handling this and that part
	// makes the code more clear and robust
	// e.g. BOOL eat(&cp, ep, vp, '=') - does all checks and updates of cp against ep and resets to vp
	// => if(!eat(&cp, ep, vp, '=')) return;
	//
	while(!isStalled && cp < ep)
		{ // process as much as we can until isStalled is called or we have to wait for completion of the next segment
		const char *vp=cp;	// where we start to analyse in this iteration
		while(cp < ep)
			{ // get plain text
			if(*cp == '&' && readMode != _NSXMLParserPlainReadMode)
				break;	// take entity
			if(*cp == '<')
				{
				if(readMode == _NSXMLParserStandardReadMode)
					break;	// we are not scanning for end of current tag
				if(cp+1 == ep)
					{
					if(done)
						;
					cp=vp;
					return;	// we can't decide yet
					}
				if(cp[1] == '/')
					{ // candidate
					NSString *tag;
					const char *currentTag;
					int len;
					tag=[tagPath lastObject];
					currentTag=[tag UTF8String];
					len=strlen(currentTag);
					if(cp+len+3 >= ep)
						{
						if(done)
							; // error
						cp=vp;
						return;	// we can't decide yet
						}
					// NOTE: this is a C hack: it firstly selects between two function addresses by the ?: operator and then indirectly calls (*fnp)(args...)
					if((*(acceptHTML?strncasecmp:strncmp))((char *)cp+2, (char *)currentTag, len) == 0 && cp[len+2] == '>')
						{ // yes, this will be parsed as the matching closing tag
						readMode=_NSXMLParserStandardReadMode;	// switch back to standard read mode
						break;	// and process
						}
					} // else this is a < to be passed verbatim to the delegate
				}
			if(*cp == '\r')
				column=0;
			else if(*cp == '\n')
				line++;
			cp++;
			}
		if(cp != vp)
			{ // notify plain characters to delegate
			if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
				[delegate parser:self foundCharacters:[NSString _string:(char *)vp withEncoding:encoding length:cp-vp]];
			// FIXME: when can we notify parser:foundIgnorableWhitespace:?
			continue;
			}
		if(cp == ep)
			break;	// no (more) data in this loop
		if(*cp == '<')
			{ // tag starts
			NSString *tag;
			NSMutableDictionary *parameters;
			const char *tp=++cp;	// remember where tag started
			if(cp < ep-8 && strncmp((char *) cp, "![CDATA[", 8) == 0)
				{ // start of CDATA
				tp=cp+=8;
				while(cp < ep-3 && (*cp != ']' || strncmp((char *)cp, "]]>", 3) != 0))
					cp++; // scan up to ]]> without processing entities and other tags
				if(cp < ep-3)
					{
#if 0
					NSLog(@"found CDATA");
#endif
					if([delegate respondsToSelector:@selector(parser:foundCDATA:)])
						[delegate parser:self foundCDATA:[NSData dataWithBytes:tp length:cp-tp]];
					cp+=3;	// eat
					continue;
					}
				if(done)
					; // error
				cp=vp;
				return;	// still incomplete
				}					
			if(cp < ep-3 && strncmp((char *)cp, "!--", 3) == 0)
				{ // start of comment skip all characters until "-->"
				  // FIXME: comment already ends with -- and > should simply follow
				tp=cp+=3;
				// FIXME: locate the next - and strcmp only then
				while(cp < ep-3 && (*cp != '-' || strncmp((char *)cp, "-->", 3) != 0))
					cp++;	// search
				if(cp < ep-3)
					{
					if([delegate respondsToSelector:@selector(parser:foundComment:)])
						[delegate parser:self foundComment:[NSString _string:(char *)tp withEncoding:encoding length:cp-tp]];
					cp+=3;	// eat
					continue;
					}
				if(done)
					; // error
				cp=vp;
				return;	// still incomplete
				}
			if(cp == ep)
				{
				if(done)
					; // error
				cp=vp;
				return;	// incomplete
				}
			if(*cp == '/')
				cp++; // closing tag </tag begins
			else if(*cp == '?')
				{ // special tag <?tag begins
				cp++;	// include ? in tag string
						//	NSLog(@"special tag <? found");
						// FIXME: should process this tag also in a special way so that e.g. <?php any PHP script ?> is read as a single tag!
						// to do this properly, we need probably a notion of comments and quoted string constants...
				}
			while(cp < ep && !isspace(*cp) && *cp != '>' && (*cp != '/')  && (*cp != '?'))
				{
				if(*cp == '\n')
					line++, column=0;
				cp++;	
				}
			if(cp == ep)
				{
				if(done)
					; // error
				cp=vp;
				return;	// still incomplete
				}
			if(*tp == '/')
				tag=[NSString _string:(char *)tp+1 withEncoding:encoding length:cp-tp-1];	// don't include opening /
			else
				tag=[NSString _string:(char *)tp withEncoding:encoding length:cp-tp];
#if 0
			NSLog(@"tag=%@ - %02x %c", tag, c, isprint(c)?c:' ');
#endif
			parameters=[NSMutableDictionary dictionaryWithCapacity:5];
			while(cp < ep)
				{ // collect arguments
				BOOL sq, dq;
				NSString *arg=nil;
				const char *ap;
				while(cp < ep && isspace(*cp))	// also allows for line break and tabs...
					{
					if(*cp == '\n')
						line++, column=0;
					cp++;	
					}
				if(cp == ep)
					{
					if(done)
						; // error
					cp=vp;
					return;	// incomplete
					}
				if(*cp == '/' && *tp != '/')
					{ // strict XML: appears to be a /> (not valid in HTML: <a href=file:///somewhere/>)
					  // FIXME: can there be a space between the / and >?
					cp++;
					if(cp == ep)
						{
						if(done)
							; // error
						cp=vp;
						return;	// we don't know yet
						}
					if(*cp != '>')
						{
						[self _parseError:NSXMLParserLTRequiredError message:[NSString stringWithFormat:@"<%@: found / but no >", arg]];
						return;
						}
					cp++;
					[self _processTag:tag isEnd:NO withAttributes:parameters];	// notify a virtual opening tag
					if(isStalled)
						NSLog(@"unexpected stall!");
					[self _processTag:tag isEnd:YES withAttributes:nil];		// and a real closing tag
					readMode=_NSXMLParserStandardReadMode;						// force switch back to standard read mode (e.g. <script/>)
					break;	// done with this tag
					}
				if(*cp == '?' && *tp == '?')
					{ // appears to be a ?>
					cp++;
					if(cp >= ep)
						{
						if(done)
							; // error
						cp=vp;
						return;	// we don't know yet
						}
					if(*cp != '>')
						{
						[self _parseError:NSXMLParserLTRequiredError message:[NSString stringWithFormat:@"<%@: found ? but no >", arg]];
						return;
						}
					cp++;	// eat ?>
					[self _processTag:tag isEnd:NO withAttributes:parameters];	// single <?tag ...?>
					break; // done
					}
				if(*cp == '>')
					{
					cp++;	// eat >
					[self _processTag:tag isEnd:(*tp=='/') withAttributes:parameters];	// handle tag
					break;
					}
				sq=(*cp == '\'');	// single quoted argument
				dq=(*cp == '"');	// quoted argument
				if(sq || dq)
					cp++;
				ap=cp;
				while(cp < ep)
					{
					if(dq)
						{
						if(*cp == '"')
							break;
						}
					else if(sq)
						{
						if(*cp == '\'')
							break;
						}
					else
						{
						if(*cp == '>' || *cp == '=' || isspace(*cp))
							break;
						// if(acceptHTML && (*cp == '/' || *cp == '?'))
						//	break;
						}
					cp++;	// collect argument
					}
				if(cp == ep)
					{
					if(done)
						; // error
					cp=vp;
					return;	// incomplete
					}
				arg=[NSString _string:(char *)ap withEncoding:encoding length:cp-ap];
				if(sq || dq)
					cp++;
				else if(acceptHTML)
					arg=[arg lowercaseString];	// unquoted keys are case insensitive by default
#if 0
				NSLog(@"arg=%@", arg);
#endif
				if([arg length] == 0)
					{ // missing
					if(!acceptHTML)
						{
						[self _parseError:NSXMLParserAttributeNotStartedError message:[NSString stringWithFormat:@"<%@> attribute name is empty - attributes=%@", tag, parameters]];
						return;
						}
					[self _processTag:tag isEnd:(*tp=='/') withAttributes:parameters];	// handle tag
					break;
					}
				if(cp == ep)
					{
					if(done)
						; // error
					cp=vp;
					return;	// incomplete
					}
				if(*cp == '=')
					{ // explicit assignment
					NSString *val;
					cp++;
					if(cp == ep)
						{
						if(done)
							; // error
						cp=vp;
						return;	// incomplete
						}
					sq=(*cp == '\'');	// single quoted argument
					dq=(*cp == '"');	// quoted argument
					if(sq || dq)
						cp++;
					ap=cp;
					while(cp < ep)
						{
						if(dq)
							{
							if(*cp == '"')
								break;
							// FIXME: we might also have to check for embedded entities (e.g. <input value="&nbsp;X">)
							}
						else if(sq)
							{
							if(*cp == '\'')
								break;
							}
						else
							{
							if(*cp == '>' || isspace(*cp))
								break;
							//	if(acceptHTML && (*cp == '/' || *cp == '?'))
							//		break;
							}
						cp++;	// collect argument
						}
					if(cp == ep)
						{
						if(done)
							; // error
						cp=vp;
						return;	// incomplete
						}
					val=[NSString _string:(char *)ap withEncoding:encoding length:cp-ap];
					if(sq || dq)
						cp++;
					if(!val)
						NSLog(@"invalid key=%@ val=%@", arg, val);
					else
						[parameters setObject:val forKey:arg];
					}
				else	// implicit
					{ // XML does not allow "singletons" ecxept if *tp == '!'
					if(!acceptHTML && ![tag hasPrefix:@"!"])
						{
						[self _parseError:NSXMLParserAttributeHasNoValueError message:[NSString stringWithFormat:@"<%@> attribute %@ has no value - attributes", tag, arg, parameters]];
						return;
						}
					if(!arg)
						NSLog(@"invalid key=%@", arg);
					else
						[parameters setObject:[NSNull null] forKey:arg];
					}
				if(cp == ep)
					{
					if(done)
						; // error
					cp=vp;
					return;	// incomplete
					}
				}
			continue;	// try next fragment unless we are stalling
			}
		if(*cp == '&')
			{ // entity starts
			NSString *entity;
			cp++;
			while(cp < ep && (isalnum(*cp) || *cp == '#'))
				cp++;
			if(cp == ep)
				{ // still incomplete
				if(!d && !acceptHTML)
					[self _parseError:NSXMLParserEntityBoundaryError message:@"missing ;"];
				if(done)
					; // error
				cp=vp;
				return;	// still incomplete - try again on next call
				}
			if(*cp != ';')
				{ // invalid entity
				if(!acceptHTML)
					{
					[self _parseError:NSXMLParserEntityBoundaryError message:@"missing ; for entity"];
					return;
					}
				if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
					[delegate parser:self foundCharacters:[NSString _string:(char *)vp withEncoding:encoding length:cp-vp]];	// pass unchanged
				continue;	// just notify as plain characters
				}
			if(vp[1] == '#')
				{ // &#ddd; or &#xhh; --- NOTE: vp+1 is usually not 0-terminated - but by ;
				unsigned int val;
				if(sscanf((char *)vp+3, "x%x;", &val))
					entity=[NSString stringWithFormat:@"%C", val];	// &#xhh; hex value
				else if(sscanf((char *)vp+2, "%d;", &val))
					entity=[NSString stringWithFormat:@"%C", val];	// &ddd; decimal value
				else
					entity=[NSString _string:(char *)vp withEncoding:encoding length:cp-vp];
				}
			else
				{ // check the five predefined entities
				if(strncmp((char *)vp+1, "amp;", 4) == 0)
					entity=@"&";
				else if(strncmp((char *)vp+1, "lt;", 3) == 0)
					entity=@"<";
				else if(strncmp((char *)vp+1, "gt;", 3) == 0)
					entity=@">";
				else if(strncmp((char *)ep+1, "quot;", 5) == 0)
					entity=@"\"";
				else if(strncmp((char *)ep+1, "apos;", 5) == 0)
					entity=@"'";
				else
					{ // other entity
					entity=[NSString _string:(char *)vp+1 withEncoding:encoding length:cp-vp-1];
					if(acceptHTML)
						{
						NSString *e;
						if(!entitiesTable)
							{ // dynamically load entity translation table on first use
							NSAutoreleasePool *arp=[NSAutoreleasePool new];
							NSBundle *b=[NSBundle bundleForClass:[self class]];
							NSString *path=[b pathForResource:@"HTMLEntities" ofType:@"strings"];
//							NSEnumerator *e;
//							NSString *key;
							NSString *s;
							NSDictionary *d;
							NSAssert(path, @"could not locate file HTMLEntities.strings");
							//			entitiesTable=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
							s = [NSString stringWithContentsOfFile: path];
#if 1
							NSLog(@"HTMLEntities: %@", s);
#endif
							d = [s propertyListFromStringsFileFormat];
							entitiesTable = [d mutableCopy];
							NSAssert(entitiesTable, ([NSString stringWithFormat:@"could not load and parse file %@", path]));
#if OLD
							e=[entitiesTable keyEnumerator];
							while((key=[e nextObject]))
								{ // translate U+xxxx and #&ddd sequences to "real" Unicode characters
								NSString *val=[entitiesTable objectForKey:key];
								NSScanner *sc=[NSScanner scannerWithString:val];
								unsigned code;
								unichar chars[1];
								if([sc scanString:@"U+" intoString:NULL] && [sc scanHexInt:&code])
									{ // replace entry U+xxxx in table with unicode character
									chars[0]=code;
									[(NSMutableDictionary *) entitiesTable setObject:[NSString stringWithCharacters:chars length:1] forKey:key];
									}
								else if([sc scanString:@"&#" intoString:NULL] && [sc scanInt:(int *)&code])
									{ // replace entry &#ddd in table with unicode character
									chars[0]=code;
									[(NSMutableDictionary *) entitiesTable setObject:[NSString stringWithCharacters:chars length:1] forKey:key];
									}
								}
#endif
#if 0
							NSLog(@"bundle=%@", b);
							NSLog(@"path=%@", path);
							NSLog(@"entitiesTable=%@", entitiesTable);
#endif
							[arp release];
							}
						e=[entitiesTable objectForKey:entity];	// look up string in entity translation table
						if(e)
							entity=e;	// replace
						}
					else if(!entity)
						{
						[self _parseError:NSXMLParserParsedEntityRefNoNameError message:@"empty entity"];
						return;
						}
					}
				}
			if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
				[delegate parser:self foundCharacters:entity];	// send entity
			cp++;	// skip ;
			continue;
			}
		}
	if(done)
		[buffer release], buffer=nil;
	if([tagPath count] != 0)
		; // error
}

- (BOOL) _acceptsHTML; { return acceptHTML; }
- (NSStringEncoding) _encoding; { return encoding; }
- (BOOL) _isStalled; { return isStalled; }
- (void) _setEncoding:(NSStringEncoding) enc; { encoding=enc; }
- (_NSXMLParserReadMode) _readMode; { return readMode; }
- (void) _setReadMode:(_NSXMLParserReadMode) mode; { readMode=mode; }

- (void) _stall:(BOOL) flag;
{ // stall - i.e. queue up calls to delegate method
#if 1
	NSLog(@"stall: %d", flag);
#endif
	if(flag != isStalled)
		{
		isStalled=flag;
		if(!isStalled)
			[self performSelector:@selector(_parseData:) withObject:[NSData data] afterDelay:0.0];	// continue processing as soon as possible
		}
}

- (NSArray *) _tagPath; { return tagPath; }

- (BOOL) parse;
{
	if(url)
		{
		// open NSURLConnection to read fragments
		// run loop until we have finished
		}
	if(!data)
		return NO;	// not initialized for complete data
	[self _parseData:data];	// process complete data segment
	if(isStalled)
		NSLog(@"%@: don't call _stall in a delegate method for -parse", NSStringFromClass(isa));
	[data release];
	data=nil;
	if(!error)
		[self _parseData:nil];	// notify end of data
#if 0
	NSLog(@"parse done %d", !error);
#endif
	return !error;
}

- (BOOL) shouldProcessNamespaces; { return shouldProcessNamespaces; }
- (BOOL) shouldReportNamespacePrefixes; { return shouldReportNamespacePrefixes; }
- (BOOL) shouldResolveExternalEntities; { return shouldResolveExternalEntities; }
- (void) setShouldProcessNamespaces:(BOOL) flag; { shouldProcessNamespaces=flag; }
- (void) setShouldReportNamespacePrefixes:(BOOL) flag; { shouldReportNamespacePrefixes=flag; }
- (void) setShouldResolveExternalEntities:(BOOL) flag; { shouldProcessNamespaces=flag; }

- (NSString *) publicID; { return NIMP; }
- (NSString *) systemID; { return NIMP; }

@end
