/* simplewebkit
   DOMCore.m

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

//
//  some parts how it works and what return values should be, has been identified by running the DOMTreeView sample code from Apple
//

#import "DOM.h"
#import "Private.h"

@implementation DOMObject

- (id) copyWithZone:(NSZone *) z;
{
	return [self retain];
}

@end

@implementation DOMWindow

- (void) removeWebScriptKey:(NSString *) key;
{
	NIMP;
}

- (void) setWebScriptValueAtIndex:(unsigned int) index value:(id) val;
{
	NIMP;
}

- (id) webScriptValueAtIndex:(unsigned int) index;
{
	return NIMP;	// not for generic object
}

- (void) setValue:(id) value forKey:(NSString *) key;
{ // KVC setter
	NIMP;
}

- (id) valueForKey:(NSString *) key;
{ // KVC getter
	return NIMP;
}

@end

@implementation DOMNode

- (id) _initWithName:(NSString *) name namespaceURI:(NSString *) uri;
{
	if((self=[self init]))
		{
		_nodeName=[name retain];
		_namespaceURI=[uri retain];
		_parentNode=nil;	// until we get added somewhere
		}
	return self;
}

- (void) dealloc;
{
	[_nodeName release];
	[_nodeValue release];
	[_namespaceURI release];
	[[_childNodes _list] makeObjectsPerformSelector:@selector(_orphanize)];	
	[_childNodes release];
	[_visualRepresentation release];
	// [_parentNode release];
	// [_document release];
	[_prefix release];
	[super dealloc];
}

- (void) _setVisualRepresentation:(NSObject <WebDocumentView> *) view;
{
	ASSIGN(_visualRepresentation, view);
	[_visualRepresentation setNeedsLayout:YES];
}

- (NSObject <WebDocumentView> *) _visualRepresentation;
{ // return our specific rep or find in the parent nodes
	while(self)
			{ // look upwards
				if(_visualRepresentation)
					return _visualRepresentation;
				self=_parentNode;
			}
	return (NSObject <WebDocumentView> *) self;
}

- (NSString *) description;
{
	NSAutoreleasePool *arp=[NSAutoreleasePool new];
	NSString *str=[NSString stringWithFormat:@"%@:\n", _nodeName];
	int i;
	for(i=0; i<[_childNodes length]; i++)
		{
		NSString *c=[[_childNodes item:i] description];
		NSEnumerator *e=[[c componentsSeparatedByString:@"\n"] objectEnumerator];
		NSString *d;
		while((d=[e nextObject]))		// append line by line and indent each one by @"  "
			{
			if([d length] > 0)
				str=[str stringByAppendingFormat:@"  %@\n", d];
			}
		if([str length] > 5000)
			break;	// ignore further children
		}
	[str retain];
	[arp release];
	[str autorelease];	// move one ARP level up
	return str;
}

- (DOMNode *) appendChild:(DOMNode *) node;
{
	if(!_childNodes)
		_childNodes=[[DOMNodeList alloc] init];	// create list
	[[_childNodes _list] addObject:node];
	[node _setParent:self];
	[[self _visualRepresentation] setNeedsLayout:YES];	// we have been updated
	return node;
}

- (DOMNodeList *) childNodes;
{
	if(!_childNodes)
		_childNodes=[[DOMNodeList alloc] init];	// create list
	return _childNodes;
}

- (DOMNode *) cloneNode:(BOOL) deep;
{
	// make new and copy child nodes
	return NIMP;
}

- (DOMNode *) firstChild; { 
  return ((_childNodes != nil) && ([_childNodes length] > 0))?((DOMNode *)[_childNodes item:0]) : (DOMNode *)nil; 
}

- (BOOL) hasAttributes; { return NO; }

- (BOOL) hasChildNodes; { return _childNodes && [_childNodes length] > 0; }

- (DOMNode *) insertBefore:(DOMNode *) node :(DOMNode *) ref;
{
	NSMutableArray *l;
	if(!_childNodes)
		_childNodes=[[DOMNodeList alloc] init];	// create list
	l=[_childNodes _list];
	[l insertObject:node atIndex:[l indexOfObject:ref]];
	[node _setParent:self];
	[[self _visualRepresentation] setNeedsLayout:YES];	// we have been updated
	return node;
}

- (BOOL) isSupported:(NSString *) feature :(NSString *) version; { return NO; }

- (DOMNode *) lastChild { 
  return ((_childNodes != nil) && ([_childNodes length] > 0))?
    (DOMNode *)[_childNodes item:[_childNodes length]-1]: (DOMNode *)nil; 
}

- (NSString *) localName; { return @"local name"; }

- (NSString *) namespaceURI; { return _namespaceURI; }

- (DOMNode *) nextSibling;
{
	NSMutableArray *l;
	unsigned idx;
	if(!_parentNode)
		return nil;
	l=[[_parentNode childNodes] _list];
	idx=[l indexOfObject:self]+1;	// my index+1
	if(idx == [l count])
		return nil;	// we are the last one
	return [l objectAtIndex:idx+1];
}

- (NSString *) nodeName; { return _nodeName; }
- (unsigned short) nodeType; { return _nodeType; }
- (NSString *) nodeValue; { return _nodeValue; }

- (void) normalize;
{
	// aggregate all consecutive DOMText children into a single one
	// while not at end
	//   normalize child
	//   while(child is not DOMText)
	//     go to next
	//   while(next child exists and is DOMText)
	//     merge into single
	NIMP;
	return;
}

- (RENAME(DOMDocument) *) ownerDocument; { return [_parentNode ownerDocument]; }	// walk the tree upwards; DOMDocument overrides to return self;

- (DOMNode *) parentNode; { return _parentNode; }
- (NSString *) prefix; { return _prefix; }

- (DOMNode *) previousSibling;
{
	NSMutableArray *l;
	unsigned idx;
	if(!_parentNode)
		return nil;
	l=[[_parentNode childNodes] _list];
	idx=[l indexOfObject:self];	// my index
	if(idx == 0)
		return nil;	// we are the first one
	return [l objectAtIndex:idx];
}

- (DOMNode *) removeChild:(DOMNode *) node;
{ // CHECKME: what is the semantics of the return value?
	[node _orphanize];
	if(_childNodes)
		{
		[[_childNodes _list] removeObject:node];
		[[self _visualRepresentation] setNeedsLayout:YES];	// we have been updated
		}
	return node;
}

- (DOMNode *) replaceChild:(DOMNode *) node :(DOMNode *) old;
{ // CHECKME: what is the semantics of the return value?
	NSMutableArray *l;
	if(!_childNodes)
		_childNodes=[[DOMNodeList alloc] init];	// create list
	[old _orphanize];
	l=[_childNodes _list];
	[l replaceObjectAtIndex:[l indexOfObject:old] withObject:node];
	[node _setParent:self];
	[[self _visualRepresentation] setNeedsLayout:YES];	// we have been updated
	return node;
}

- (void) _setParent:(DOMNode *) p;
{
	_parentNode=p;
	[[self _visualRepresentation] setNeedsLayout:YES];	// we may now have a visual representation
}

- (void) _orphanize;
{
	_parentNode=nil;
	[[self _visualRepresentation] setNeedsLayout:YES];	// we may now have a visual representation
}

- (void) setNodeValue:(NSString *) string;
{
	ASSIGN(_nodeValue, string);
	[[self _visualRepresentation] setNeedsLayout:YES];	// we have been updated
}

- (void) setPrefix:(NSString *) prefix; { ASSIGN(_prefix, prefix); }

@end

@implementation DOMNodeList

- (id) init; { if((self=[super init])) { _list=[[NSMutableArray alloc] initWithCapacity:5]; } return self; }
- (void) dealloc; { [_list release]; [super dealloc]; }
- (NSMutableArray *) _list;	{ return _list; }
- (DOMNode *) item:(unsigned long) index; { return [_list objectAtIndex:index]; }
- (unsigned long) length; { return [_list count]; }

@end

@implementation DOMAttr

- (id) _initWithName:(NSString *) str value:(NSString *) val;
{ // value can be nil
	if((self=[super init]))
		{
		_name=[str retain];
		_value=[val retain];
		}
	return self;
}

- (void) dealloc; { [_name release]; [_value release]; [super dealloc]; }
- (NSString *) description; { return [NSString stringWithFormat:_value?@"%@=%@":@"%@", _name, _value]; }

- (NSString *) name; { return _name; }
- (DOMElement *) ownerElement; { return (DOMElement *) _parentNode; }

- (void) setValue:(NSString *) val;
{
	if([_value isEqual:val])
		return;	// unchanged
	ASSIGN(_value, val);
	[[self _visualRepresentation] setNeedsLayout:YES];
}

- (BOOL) specified; { return _value != nil; }
- (NSString *) value; { return _value; }

@end

@implementation DOMElement

- (void) dealloc; { [[_attributes allValues] makeObjectsPerformSelector:@selector(_orphanize)]; [_attributes release]; [super dealloc]; }
- (NSArray *) _attributes; { return [_attributes allValues]; }

- (NSString *) getAttribute:(NSString *) name; { return [[_attributes objectForKey:name] value]; }

- (DOMAttr *) getAttributeNode:(NSString *) name; { return [_attributes objectForKey:name]; }

- (DOMAttr *) getAttributeNodeNS:(NSString *) uri :(NSString *) name; { return NIMP; }
- (NSString *) getAttributeNS:(NSString *) uri :(NSString *) name; { return NIMP; }

- (DOMNodeList *) getElementsByTagName:(NSString *) name; { return NIMP; } // filter by tag name
- (DOMNodeList *) getElementsByTagNameNS:(NSString *) uri :(NSString *) name; { return NIMP; }

- (BOOL) hasAttribute:(NSString *) name; { return [_attributes objectForKey:name] != nil; }
- (BOOL) hasAttributeNS:(NSString *) uri :(NSString *) name; { NIMP; return NO; }

- (BOOL) hasAttributes; { return YES; }

- (void) removeAttribute:(NSString *) name; { [_attributes removeObjectForKey:name]; }
- (DOMAttr *) removeAttributeNode:(DOMAttr *) attr;
{
	[_attributes removeObjectForKey:[attr name]];
	[attr _orphanize];
	[[self _visualRepresentation] setNeedsLayout:YES];
	return attr;
}

- (void) removeAttributeNS:(NSString *) uri :(NSString *) name; { NIMP; }

- (void) setAttribute:(NSString *) name :(NSString *) val;
{
	DOMAttr *attr=[_attributes objectForKey:name];
	if(attr)
		[attr setValue:val];	// already exists
	else
		[self setAttributeNode:[[[DOMAttr alloc] _initWithName:name value:val] autorelease]];	// create new
}

- (DOMAttr *) setAttributeNode:(DOMAttr *) attr;
{
	if(!_attributes)
		_attributes=[[NSMutableDictionary alloc] initWithCapacity:5];
	[_attributes setObject:attr forKey:[attr name]];
	[attr _setParent:self];
	return attr;
}

- (DOMAttr *) setAttributeNodeNS:(DOMAttr *) attr; { return NIMP; }
- (void) setAttributeNS:(NSString *) uri :(NSString *) name :(NSString *) value; { NIMP; }
- (NSString *) tagName; { return _nodeName; }

// WebScript bridging

- (NSString *) valueForKey:(NSString *) name;
{
	id attr=[_attributes objectForKey:name];
	if(attr)
		return [attr value];
	return [super valueForKey:name];	// standard KVC (either iVar or getter)
}

- (void) setValue:(id) val forKey:(NSString *) name;
{
	DOMAttr *attr=[_attributes objectForKey:name];
	if(attr)
		[attr setValue:val];	// already exists
	// FIXME: can we call setters?
	else
		[self setAttributeNode:[[[DOMAttr alloc] _initWithName:name value:val] autorelease]];	// create new
}

- (BOOL) _canPut:(NSString *) property; { return YES; }

// FIXME: check if we have iVar or setter

- (BOOL) _hasProperty:(NSString *) property;  { return [_attributes objectForKey:property] != nil; }

- (void) removeWebScriptKey:(NSString *) property;
{
	if(![_attributes objectForKey:property])
		return;	// or raise exception?
	[_attributes removeObjectForKey:property];
}

@end

@implementation RENAME(DOMDocument)

- (DOMAttr *) createAttribute:(NSString *) name; { return [[[DOMAttr alloc] _initWithName:name value:nil] autorelease]; }

- (DOMAttr *) createAttributeNS:(NSString *) uri :(NSString *) name; { return NIMP; }

- (DOMCDATASection *) createCDATASection:(NSString *) data;
{
	DOMCDATASection *r=[[[DOMCDATASection alloc] _initWithName:@"#cdata" namespaceURI:nil] autorelease];
	[r setData:data];
	return r;
}

- (DOMComment *) createComment:(NSString *) data;
{
	DOMComment *r=[[[DOMComment alloc] _initWithName:@"<!--" namespaceURI:nil] autorelease];
	[r setData:data];
	return r;
}

- (DOMDocumentFragment *) createDocumentFragment;
{
	return NIMP;
}

- (DOMElement *) createElement:(NSString *) tag;
{
	DOMElement *r=[[[DOMElement alloc] _initWithName:tag namespaceURI:nil] autorelease];
	return r;
}

- (DOMElement *) createElementNS:(NSString *) uri :(NSString *) tag;
{
	DOMElement *r=[[[DOMElement alloc] _initWithName:tag namespaceURI:uri] autorelease];
	return r;
}

- (DOMEntityReference *) createEntityReference:(NSString *) name;
{
//	DOMEntityReference *r=[[[DOMEntityReference alloc] _initWithName:@"entity" namespaceURI:nil document:self] autorelease];
//	return r;
	return NIMP;
}

- (DOMProcessingInstruction *) createProcessingInstruction:(NSString *) target :(NSString *) data; { return NIMP; }

- (DOMText *) createTextNode:(NSString *) data;
{
	DOMText *r=[[[DOMText alloc] _initWithName:@"#text" namespaceURI:nil] autorelease];
	[r setData:data];
	return r;
}

- (DOMDocumentType *) doctype; {return  NIMP; }

- (DOMElement *) documentElement; { return (DOMElement *) self; }

- (RENAME(DOMDocument) *) ownerDocument; { return self; }	// end recursion

- (DOMElement *) getElementById:(NSString *) element; {return NIMP; }
- (DOMNodeList *) getElementsByTagName:(NSString * ) name; { return NIMP; }
- (DOMNodeList *) getElementsByTagNameNS:(NSString *) uri :(NSString *) name; { return NIMP; }
- (DOMImplementation *) implementation; { return NIMP; }
- (DOMNode *) importNode:(DOMNode *) node :(BOOL) deep; { return NIMP; }

@end

@implementation DOMCharacterData

- (id) init; { if((self=[super init])) { _nodeValue=[[NSMutableString alloc] initWithCapacity:30]; } return self; }
// - (void) dealloc; { [super dealloc]; }

- (NSString *) description;
{
	if([_nodeValue hasSuffix:@"\n"])
		return [NSString stringWithFormat:@"%@: %@<lf>\n", _nodeName, _nodeValue];
	return [NSString stringWithFormat:@"%@: %@\n", _nodeName, _nodeValue];
}


- (void) appendData:(NSString *) arg;
{
	[(NSMutableString *) _nodeValue appendString:arg];
	if([arg length] > 0)
		[[self _visualRepresentation] setNeedsLayout:YES];
}

- (NSString *) data; { return _nodeValue; }

- (void) deleteData:(unsigned long) offset :(unsigned long) count;
{
	[(NSMutableString *) _nodeValue deleteCharactersInRange:NSMakeRange(offset, count)];
	if(count > 0)
		[[self _visualRepresentation] setNeedsLayout:YES];
}

- (void) insertData:(unsigned long) offset :(NSString *) arg;
{
	[(NSMutableString *) _nodeValue insertString:arg atIndex:offset];
	if([arg length] > 0)
		[[self _visualRepresentation] setNeedsLayout:YES];
}

- (void) replaceData:(unsigned long) offset :(unsigned long) count :(NSString *) arg;
{
	[(NSMutableString *) _nodeValue replaceCharactersInRange:NSMakeRange(offset, count) withString:arg];
	if([arg length] > 0)
		[[self _visualRepresentation] setNeedsLayout:YES];
}

- (unsigned long) length; { return [_nodeValue length]; }

- (void) setNodeValue:(NSString *) data;
{
	if([_nodeValue isEqual:data])
		return;	// unchanged
	[(NSMutableString *) _nodeValue setString:data];
	[[self _visualRepresentation] setNeedsLayout:YES];
}

- (void) setData:(NSString *) data;
{
	if([_nodeValue isEqual:data])
		return;	// unchanged
	[(NSMutableString *) _nodeValue setString:data];
	[[self _visualRepresentation] setNeedsLayout:YES];
}

- (NSString *) substringData:(unsigned long) offset :(unsigned long) count; { return [_nodeValue substringWithRange:NSMakeRange(offset, count)]; }

@end

@implementation DOMText

- (DOMText *) splitText:(unsigned long) offset
{ // FIXME: what is the semantics of this method? return first part, shrink self to second or vice versa? or split into two #text nodes as children of common parent???
	DOMText *r;
	NSString *first=[_nodeValue substringWithRange:NSMakeRange(0, offset)];	// first part
	NSString *last=[_nodeValue substringWithRange:NSMakeRange(offset, [_nodeValue length]-offset)];	// second part
	[(NSMutableString *) _nodeValue setString:last];	// keep last
	r=[[DOMText new] autorelease];
	[r setData:first];	// return first part
	[[self _visualRepresentation] setNeedsLayout:YES];
	return r;
}

@end

@implementation DOMComment
@end

@implementation DOMCDATASection
@end
