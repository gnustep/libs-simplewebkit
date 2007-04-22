//
//  NSXMLParser.m
//  mySTEP
//
//  Created by Dr. H. Nikolaus Schaller on Tue Oct 05 2004.
//  Copyright (c) 2004 DSITRI.
//
//  This file is part of the mySTEP Library and is provided
//  under the terms of the GNU Library General Public License.
//

#ifndef __WebKit__	// allows us to disable parts when we #include into WebKit

#import <Foundation/NSXMLParser.h>

#import "../Foundation/Sources/NSPrivate.h"

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

- (id) initWithData:(NSData *) data;
{
	if(!data)
		{
		[self release];
		return nil;
		}
	self=[super init];
	if(self)
		{
#if OLD
		if(!entitiesTable)
			{
			// could/should load from a file - WARNING: this will be recursive if we want to use a PList!!!
			// we should use a strings file format
			entitiesTable=[[NSDictionary alloc] initWithObjectsAndKeys:
				@"U+00A0", @"nbsp",
				@"ä", @"auml",
				@"ö", @"ouml",
				@"ü", @"uuml",
				@"Ä", @"Auml",
				@"Ö", @"Ouml",
				@"Ü", @"Uuml",
				@"©", @"copy",
				@"€", @"euro",
				@"»", @"raquo",

				@"U+2011", @"nonbreaking-hyphen",
				@"U+2028", @"newline",
				@"U+2029", @"newparagraph",
				nil];
			}
#endif
		tagPath=[[NSMutableArray alloc] init];
		cp=[data bytes];
		cend=cp+[data length];
		encoding=NSUTF8StringEncoding;	// default
		}
	return self;
}

- (id) initWithContentsOfURL:(NSURL *) url;
{
	return [self initWithData:[NSData dataWithContentsOfURL:url]];
}

- (void) dealloc;
{
#if 0
	NSLog(@"dealloc %@: %@", NSStringFromClass(isa), self);
#endif
	[error release];
	[tagPath release];
	[super dealloc];
}

- (void) abortParsing;	{ abort=YES; }
- (int) columnNumber; { return column; }
- (int) lineNumber; { return line; }
- (id) delegate; { return delegate; }
- (void) setDelegate:(id) del; { delegate=del; }	// not retained!
- (NSError *) parserError; { return error; }
- (NSArray *) _tagPath; { return tagPath; }

#define cget() ((cp<cend)?(column++, *cp++):EOF)	// similar semantics as with getchar()/getc()

- (BOOL) _parseError:(NSXMLParserError) err message:(NSString *) msg;
{
	NSError *e=[NSError errorWithDomain:NSXMLParserErrorDomain code:err userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msg, @"Message", nil]];
#if 0
	NSLog(@"XML parseError: %u - %@", err, msg);
#endif
	ASSIGN(error, e);
	abort=YES;	// break loop
	if([delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
		[delegate parser:self parseErrorOccurred:error];	// pass error
	return NO;
}

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
					acceptHTML=YES;	// switch to HTML lazy mode because people don't really comply to XHTML...
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

- (NSString *) _entity;
{ // parse &xxx; sequence
	int c;
	const unsigned char *ep=cp;	// should be position behind &
	int len;
	unsigned int val;
	NSString *entity, *e;
	do {
		c=cget();
		if(c == '\n')
			line++, column=0;
	} while(c == '#' || isalnum(c));
	if(c != ';')
		return acceptHTML?@"&":nil; // invalid sequence - missing ;
	len=cp-ep-1;
	if(*ep == '#')
		{ // &#ddd; or &#xhh; --- NOTE: ep+1 is not 0-terminated - but by ;
		if(sscanf((char *)ep+1, "x%x;", &val))
			return [NSString stringWithFormat:@"%C", val];	// &#xhh; hex value
		else if(sscanf((char *)ep+1, "%d;", &val))
			return [NSString stringWithFormat:@"%C", val];	// &ddd; decimal value
		}
	else
		{ // check the five predefined entities
		if(len == 3 && strncmp((char *)ep, "amp", len) == 0)
			return @"&";
		if(len == 2 && strncmp((char *)ep, "lt", len) == 0)
			return @"<";
		if(len == 2 && strncmp((char *)ep, "gt", len) == 0)
			return @">";
		if(len == 4 && strncmp((char *)ep, "quot", len) == 0)
			return @"\"";
		if(len == 4 && strncmp((char *)ep, "apos", len) == 0)
			return @"'";
		}
	entity=[NSString _string:(char *)ep withEncoding:encoding length:len];
	if(acceptHTML)
		{
		if(!entitiesTable)
			{ // dynamically load entity translation table on first use
			NSBundle *b=[NSBundle bundleForClass:[self class]];
			NSString *path=[b pathForResource:@"HTMLEntities" ofType:@"strings"];
			NSEnumerator *e;
			NSString *key;
			NSAutoreleasePool *arp=[NSAutoreleasePool new];
			NSAssert(path, @"could not locate file HTMLEntities.strings");
			entitiesTable=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
			NSAssert(entitiesTable, @"could not load file HTMLEntities.strings");
			e=[entitiesTable keyEnumerator];
			while((key=[e nextObject]))
				{ // translate U+xxxx sequences to "real" Unicode characters
				NSString *val=[entitiesTable objectForKey:key];
				NSScanner *sc=[NSScanner scannerWithString:val];
				unsigned code;
				unichar chars[1];
				if([sc scanString:@"U+" intoString:NULL] && [sc scanHexInt:&code])
					{ // replace entry U+xxxx in table with unicode character
					chars[0]=code;
					[(NSMutableDictionary *) entitiesTable setObject:[NSString stringWithCharacters:chars length:1] forKey:key];
					}
				}
#if 0
			NSLog(@"bundle=%@", b);
			NSLog(@"path=%@", path);
			NSLog(@"entitiesTable=%@", entitiesTable);
#endif
			[arp release];
			}
		e=[entitiesTable objectForKey:entity];	// look up string in entity translation table
		if(e)
			return e;
		}
#if 1
	NSLog(@"NSXMLParser: unrecognized entity: &%@;", entity);
#endif
	return [NSString _string:(char *)ep-1 withEncoding:encoding length:len+2];	// unknown entity
}

- (NSString *) _qarg:(BOOL) ignoreEQ;
{ // get argument (might be quoted)
	const unsigned char *ap=--cp;	// argument start pointer
	int c=cget();	// refetch first character
	NSString *val;
#if 0
	NSLog(@"_qarg: %02x %c", c, isprint(c)?c:' ');
#endif
	if(c == '\"')
		{ // quoted argument
		do {
			c=cget();
			if(c == '\n')
				line++, column=0;
		} while(c != '\"' && c != EOF);
		// if(c == EOF) - rescan until next for better error recovery
		val=[NSString _string:(char *)ap+1 withEncoding:encoding length:cp-ap-2];
#if 0
		if(val == nil)
			{
			NSLog(@"error? %@", val);
			NSLog(@"*ap=%s", ap);
			NSLog(@"*cp=%s", cp);
			NSLog(@"len=%d", cp-ap-2);
			}
#endif
		}
	else if(c == '\'')
		{ // apostrophed argument
		do {
			c=cget();
			if(c == '\n')
				line++, column=0;
		} while(c != '\'' && c != EOF);
		val=[NSString _string:(char *)ap+1 withEncoding:encoding length:cp-ap-2];
#if 0
		if(val == nil)
			NSLog(@"error? %@", val);
#endif
		}
	else
		{
		if(!acceptHTML)
			;	// strict XML requires quoting
		while(!isspace(c) && c != '>' && (ignoreEQ || c != '=') && (acceptHTML || (c != '/' && c != '?')) && c != EOF)
			c=cget();
		if(c == '\n')
			line++, column=0;
		cp--;	// go back to terminating character
		val=[NSString _string:(char *)ap withEncoding:encoding length:cp-ap];
		if(val == nil)
			NSLog(@"error? %@", [NSString _string:(char *)ap withEncoding:encoding length:cp-ap]);
		}
	if(val == nil)
		NSLog(@"error? %@", val);
	return val;
}

- (BOOL) parse;
{ // read XML (or HTML) file
	const unsigned char *vp=cp;	// value pointer
	int c;
	do
		{ // skip initial whitespace
		c=cget();	// get first character
		if(c == '\n')
			line++;
		} while(isspace(c));
	acceptHTML=(strncmp((char *) cp, "?xml ", 5) != 0);	// accept HTML unless we start with <?xml> token to denote strict X(HT)ML (and no conversion of tags to lowercase!)
	if(!acceptHTML && c != EOF && c != '<')
		{ // not a valid XML or HTML document start
		return [self _parseError:NSXMLParserDocumentStartError message:@"missing <"];
		}
#if 1
	if(acceptHTML)
		NSLog(@"accepting HTML");
#endif
	while(!abort)
		{ // parse next element
#if 0
		NSLog(@"_nextelement %02x %c", c, isprint(c)?c:' ');
#endif
		switch(c)
			{ // handle special situations where we must push the foundCharacters
			case EOF:
			case '<':
			case '&':
				{ // push out any characters that have been collected so far
				if(cp-vp > 1)
					{
					if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
						[delegate parser:self foundCharacters:[NSString _string:(char *)vp withEncoding:encoding length:cp-vp-1]];
					vp=cp;
					}
				}
			}
		switch(c)
			{
			case '\r':
				column=0;
				c=cget();
				continue;
			case '\n':
				line++;
				column=0;
			default:
				c=cget();	// just collect until we push out (again)
				continue;
			case EOF:	// end of file
				{
					if([tagPath count] != 0)
						{
						if(!acceptHTML)
							return [self _parseError:NSXMLParserPrematureDocumentEndError message:[NSString stringWithFormat:@"open tags: %@", [tagPath description]]];	// strict XML nesting error
						while([tagPath count] > 0)
							{ // lazily close all open tags
#if 0
							NSLog(@"lazily close %@", [tagPath lastObject]);
#endif
							if([delegate respondsToSelector:@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
								[delegate parser:self didEndElement:[tagPath lastObject] namespaceURI:nil qualifiedName:nil];
							[tagPath removeLastObject];	// pop from stack
							}
						}
#if 0
					NSLog(@"parserDidEndDocument:");
#endif
					if([delegate respondsToSelector:@selector(parserDidEndDocument:)])
						[delegate parserDidEndDocument:self];
					return YES;
				}
			case '&':
				{ // escape entity begins
					NSString *entity=[self _entity];
					if(!acceptHTML && !entity)
						return [self _parseError:NSXMLParserParsedEntityRefNoNameError message:@"empty entity"];
					if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
						[delegate parser:self foundCharacters:entity];
					vp=cp;	// next value sequence starts here
					c=cget();	// first character behind ;
					continue;
				}
			case '<':
				{ // tag begins
					NSString *tag;
					NSMutableDictionary *parameters;
					NSString *arg=nil;
					const unsigned char *tp=cp;	// tag pointer
					if(cp < cend-8 && strncmp((char *)cp, "![CDATA[", 8) == 0)
						{ // start of CDATA
						tp=cp+=8;
						while(cp < cend-3 && strncmp((char *)cp, "]]>", 3) != 0)
							cget(); // scan up to ]]> without processing entities and other tags
#if 0
						NSLog(@"found CDATA");
#endif
						if([delegate respondsToSelector:@selector(parser:foundCDATA:)])
							[delegate parser:self foundCDATA:[NSData dataWithBytes:tp length:cp-tp]];
						cp+=3;
						vp=cp;		// value might continue
						c=cget();	// get first character behind comment
						continue;
						}					
					if(cp < cend-3 && strncmp((char *)cp, "!--", 3) == 0)
						{ // start of comment skip all characters until "-->"
						// FIXME: comment already ends with -- and > should follow
						tp=cp+=3;
						while(cp < cend-3 && strncmp((char *)cp, "-->", 3) != 0)
							cget();	// search
						if([delegate respondsToSelector:@selector(parser:foundComment:)])
							[delegate parser:self foundComment:[NSString _string:(char *)tp withEncoding:encoding length:cp-tp]];
						cp+=3;
						vp=cp;		// value might continue
						c=cget();	// get first character behind comment
						continue;
						}
					c=cget(); // get first character of tag
					if(c == '/')
						c=cget(); // closing tag </tag begins
					else if(c == '?')
						{ // special tag <?tag begins
						c=cget();	// include in tag string
					//	NSLog(@"special tag <? found");
						// FIXME: should process this tag in a special way so that e.g. <?php any PHP script ?> is read as a single tag!
						// to do this properly, we need probably a notion of comments and quoted string constants...
						}
					while(!isspace(c) && c != '>' && (c != '/')  && (c != '?') && c != EOF)
						c=cget(); // scan tag until we find a delimiting character
					if(*tp == '/')
						tag=[NSString _string:(char *)tp+1 withEncoding:encoding length:cp-tp-2];	// don't include / and delimiting character
					else
						tag=[NSString _string:(char *)tp withEncoding:encoding length:cp-tp-1];	// don't include delimiting character
#if 0
					NSLog(@"tag=%@ - %02x %c", tag, c, isprint(c)?c:' ');
#endif
					parameters=[NSMutableDictionary dictionaryWithCapacity:5];
					while(c != EOF)
						{ // collect arguments
						while(isspace(c))	// also allows for line break and tabs...
							{
							if(c == '\n')
								line++, column=0;
							c=cget();
							}
						if(!acceptHTML && c == '/' && *tp != '/')
							{ // appears to be a /> (not valid in HTML: <a href=file:///somewhere/>)
							// FIXME: may there be a space between the / and >?
							c=cget();
							if(c != '>')
								return [self _parseError:NSXMLParserLTRequiredError message:[NSString stringWithFormat:@"<%@: found / but no >", arg]];
							[self _processTag:tag isEnd:NO withAttributes:parameters];	// notify a virtual opening tag
							[self _processTag:tag isEnd:YES withAttributes:nil];		// and a real closing tag
							break; // done
							}
						if(c == '?' && *tp == '?')
							{ // appears to be a ?>
							c=cget();
							if(c != '>')
								return [self _parseError:NSXMLParserLTRequiredError message:[NSString stringWithFormat:@"<%@ found ? but no >", arg]];
							// process ?>
							[self _processTag:tag isEnd:NO withAttributes:parameters];	// single <?tag ...?>
							break; // done
							}
						if(c == '>')
							{
							[self _processTag:tag isEnd:(*tp=='/') withAttributes:parameters];	// handle tag
							if(acceptHTML && *tp != '/')
								{ // special tags which allow embedded control characters until closing tag
									// FIXME: with a DTD we could know all tags with this behaviour
								if([tag isEqualToString:@"script"] || [tag isEqualToString:@"style"])
									{
									const unsigned char *dp=cp;	// data pointer
									unsigned len=[tag length];
									while(cp < cend-4 && (cp[0] != '<' || cp[1] != '/' || strncmp((char *)cp+2, (char *)tp, len) != 0))
										{
#if 0
										NSLog(@"*cp = %5.5s *tp = %8.8s len=%d", cp, tp, len);
#endif
										c=cget(); // scan until we find the </tag> without processing entities and other tags
										}
									if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
										[delegate parser:self foundCharacters:[NSString _string:(char *)dp withEncoding:encoding length:cp-dp]];
									}
								}
							break;
							}
						arg=[self _qarg:NO];	// get next argument (eats up to /, ?, >, =, space)
						if(acceptHTML)
							arg=[arg lowercaseString];	// unquoted keys are case insensitive by default
#if 0
						NSLog(@"arg=%@", arg);
#endif
						if([arg length] == 0)
							{ // missing
							if(!acceptHTML)
								return [self _parseError:NSXMLParserAttributeNotStartedError message:[NSString stringWithFormat:@"<%@> attribute name is empty - attributes=%@", tag, parameters]];
							[self _processTag:tag isEnd:(*tp=='/') withAttributes:parameters];	// handle tag
							break;
							}
						c=cget();	// get delimiting character
						if(c == '=')
							{ // explicit assignment
							NSString *val;
							c=cget();	// skip =
							val=[self _qarg:YES];
							if(!val)
								NSLog(@"invalid key=%@ val=%@", arg, val);
							else
								[parameters setObject:val forKey:arg];
							c=cget();	// get character behind qarg value
							}
						else	// implicit
							{ // XML does not allow "singletons" ecxept if *tp == '!'
							if(*tp != '!' && !acceptHTML)
								return [self _parseError:NSXMLParserAttributeHasNoValueError message:[NSString stringWithFormat:@"<%@> attribute %@ has no value - attributes", tag, arg, parameters]];
							if(!arg)
								NSLog(@"invalid key=%@", arg);
							else
								[parameters setObject:[NSNull null] forKey:arg];
							}
						}
					vp=cp;		// prepare for next value
					c=cget();	// skip > and fetch next character
				}
			}
		}
	return [self _parseError:NSXMLParserDelegateAbortedParseError message:@"aborted by delegate"];	// aborted
}

- (BOOL) _acceptsHTML; { return acceptHTML; }

- (BOOL) shouldProcessNamespaces; { return shouldProcessNamespaces; }
- (BOOL) shouldReportNamespacePrefixes; { return shouldReportNamespacePrefixes; }
- (BOOL) shouldResolveExternalEntities; { return shouldResolveExternalEntities; }
- (void) setShouldProcessNamespaces:(BOOL) flag; { shouldProcessNamespaces=flag; }
- (void) setShouldReportNamespacePrefixes:(BOOL) flag; { shouldReportNamespacePrefixes=flag; }
- (void) setShouldResolveExternalEntities:(BOOL) flag; { shouldProcessNamespaces=flag; }
- (void) _setEncoding:(NSStringEncoding) enc; { encoding=enc; }

- (NSString *) publicID; { return NIMP; }
- (NSString *) systemID; { return NIMP; }

@end
