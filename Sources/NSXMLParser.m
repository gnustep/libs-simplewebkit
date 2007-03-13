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

#ifndef __WebKit__	// allows to disable since we #include into WebKit

#import "NSXMLParser.h"

#import "NSPrivate.h"

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
	NSData *d=[NSData dataWithBytesNoCopy:(char *) bytes length:len freeWhenDone:NO];
	//	NSLog(@"%p:%@", d, d);
	NSString *str;
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
	NSError *e=[NSError errorWithDomain:NSXMLParserErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msg, @"Message", nil]];
#if 0
	NSLog(@"XML parseError: %u - %@", err, msg);
#endif
	ASSIGN(error, e);
	abort=YES;	// break loop
	if([delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
		[delegate parser:self parseErrorOccurred:error];	// pass error
	return NO;
}

- (BOOL) _parseError:(NSXMLParserError) err;
{
	return [self _parseError:err message:nil];
}

- (void) _processTag:(NSString *) tag isEnd:(BOOL) flag withAttributes:(NSDictionary *) attributes;
{
#if 0
	NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
	if(acceptHTML)
		tag=[tag uppercaseString];	// HTML is not case sensitive
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
				{ // parse and might load
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
				// [delegate parser:self foundCDATA:data];
				return;
				}
			if([tag isEqualToString:@"!CDATA"])
				{ // pass through as NSData
#if 0
				NSLog(@"_processTag <%@%@ %@>", flag?@"/":@"", tag, attributes);
#endif
				// [delegate parser:self foundCDATA:[NSData dataWithBytesNoCopy: length: freeWhenDone:NO]];
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
	NSString *entity;
	do {
		c=cget();
	} while(c != EOF && c != '<' && c != ';');
	if(c != ';')
		return nil; // invalid sequence - end of file or missing ; before next tag
	len=cp-ep-1;
	if(*ep == '#')
		{ // &#ddd; or &#xhh;
			// !!! ep+1 is not 0-terminated - but by ;!!
		if(sscanf((char *)ep+1, "x%x;", &val))
			return [NSString stringWithFormat:@"%C", val];	// &#xhh; hex value
		else if(sscanf((char *)ep+1, "%d;", &val))
			return [NSString stringWithFormat:@"%C", val];	// &ddd; decimal value
		}
	else
		{ // the five predefined entities
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
			entitiesTable=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
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
			NSLog(@"bundle=%@", b);
			NSLog(@"path=%@", path);
			NSLog(@"entitiesTable=%@", entitiesTable);
			[arp release];
			}
		entity=[entitiesTable objectForKey:entity];	// look up string in entity translation table
		if(entity)
			return entity;
		}
#if 1
	NSLog(@"NSXMLParser: unrecognized entity: &%@;", entity);
#endif
	return [NSString _string:(char *)ep-1 withEncoding:encoding length:len+2];	// unknown entity
}

- (NSString *) _qarg;
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
		} while(c != '\"' && c != EOF);
		// if(c == EOF) - rescan until next for better error recovery
		val=[NSString _string:(char *)ap+1 withEncoding:encoding length:cp-ap-2];
		if(val == nil)
			{
			NSLog(@"error? %@", val);
			NSLog(@"*ap=%s", ap);
			NSLog(@"*cp=%s", cp);
			NSLog(@"len=%d", cp-ap-2);
			}
		}
	else if(c == '\'')
		{ // apostrophed argument
		do {
			c=cget();
		} while(c != '\'' && c != EOF);
		val=[NSString _string:(char *)ap+1 withEncoding:encoding length:cp-ap-2];
		if(val == nil)
			NSLog(@"error? %@", val);
		}
	else
		{
		if(!acceptHTML)
			;	// strict XML requires quoting
		while(!isspace(c) && c != '>' && c != '=' && (acceptHTML || (c != '/' && c != '?')) &&c != EOF)
			{
			c=cget();
			}
		cp--;	// go back to terminating character
		val=[NSString _string:(char *)ap withEncoding:encoding length:cp-ap];
		if(acceptHTML)
			val=[val uppercaseString];	// unquoted keys and values are case insensitive by default
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
		c=cget();	// get first character
	while(isspace(c));	// skip initial whitespace
	if(c != EOF && c != '<')
		{ // not a valid XML document start
		return [self _parseError:NSXMLParserDocumentStartError];
		}
	acceptHTML=(strncmp((char *) cp, "<?xml ", 6) != 0);	// accept html unless we start with <xml
	while(!abort)
		{ // parse next element
#if 0
		NSLog(@"_nextelement %02x %c", c, isprint(c)?c:' ');
#endif
		switch(c)
			{
			case '\r':
				column=0;
				break;
			case '\n':
				line++;
				column=0;
			case EOF:
			case '<':
			case '&':
				{ // push out any characters that have been collected so far
				if(cp-vp > 1)
					{
					// check for whitespace only - might set/reset a flag to indicate so
					if([delegate respondsToSelector:@selector(parser:foundCharacters:)])
						[delegate parser:self foundCharacters:[NSString _string:(char *)vp withEncoding:encoding length:cp-vp-1]];
					vp=cp;
					}
				}
			}
		switch(c)
			{
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
							NSLog(@"lazily close %@", [tagPath lastObject]);
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
					if(!entity)
						return [self _parseError:NSXMLParserParsedEntityRefNoNameError];
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
					NSString *arg;
					const unsigned char *tp=cp;	// tag pointer
					if(cp < cend-3 && strncmp((char *)cp, "!--", 3) == 0)
						{ // start of comment skip all characters until "-->"
						cp+=3;
						while(cp < cend-3 && strncmp((char *)cp, "-->", 3) != 0)
							cp++;	// search
						if([delegate respondsToSelector:@selector(parser:foundComment:)])
							[delegate parser:self foundComment:[NSString _string:(char *)tp+4 withEncoding:encoding length:cp-tp-4]];
						cp+=3;		// might go beyond cend but does not care
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
						// to do this properly, we need a notion of comments and quoted string constants...
						}
					while(!isspace(c) && c != '>' && (c != '/')  && (c != '?'))
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
						if(!acceptHTML && c == '/' && *tp != '/')
							{ // appears to be a /> (not valid in HTML: <a href=file:///somewhere/>)
							c=cget();
							if(c != '>')
								return [self _parseError:NSXMLParserLTRequiredError];
							[self _processTag:tag isEnd:NO withAttributes:parameters];	// notify a virtual opening tag
							[self _processTag:tag isEnd:YES withAttributes:nil];		// and a real closing tag
							break; // done
							}
						if(c == '?' && *tp == '?')
							{ // appears to be a ?>
							c=cget();
							if(c != '>')
								return [self _parseError:NSXMLParserLTRequiredError];
							// process ?>
							[self _processTag:tag isEnd:NO withAttributes:parameters];	// single <?tag ...?>
							break; // done
							}
						while(isspace(c))	// should also allow for line break and tab
							c=cget();
						if(c == '>')
							{
							[self _processTag:tag isEnd:(*tp=='/') withAttributes:parameters];	// handle tag
							break;
							}
						arg=[self _qarg];	// get next argument (eats up to /, ?, >, =, space)
#if 0
						NSLog(@"arg=%@", arg);
#endif
						if(!acceptHTML && [arg length] == 0)
							return [self _parseError:NSXMLParserAttributeNotStartedError];
						c=cget();	// get delimiting character
						if(c == '=')
							{ // explicit assignment
							NSString *val;
							c=cget();	// skip =
							val=[self _qarg];
							if(!val || !arg)
								NSLog(@"invalid key=%@ val=%@", arg, val);
							else
								[parameters setObject:val forKey:arg];
							c=cget();	// get character behind qarg value
							}
						else	// implicit
							{
							// FIXME: allow for HTML only? NSXMLParserAttributeHasNoValueError
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
	return [self _parseError:NSXMLParserDelegateAbortedParseError];	// aborted
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
