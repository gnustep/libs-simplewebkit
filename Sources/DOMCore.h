/* simplewebkit
   DOMCore.h

   Copyright (C) 2007-2010 Free Software Foundation, Inc.

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

#if __GNUC__ == 2
#define MUST_RENAME_CLASSES 1
#endif

#if MUST_RENAME_CLASSES
// gcc 2.95.3 does not allow methods with the same name as a class, i.e.
// - (DOMDocument *) DOMDocument;
// you should wrap the class name with this macro i.e.
// - (RENAME(DOMDocument) *) DOMDocument;
#define RENAME(X) _class_##X
#else
#define RENAME(X) X
#endif

#import <Foundation/Foundation.h>

// #import <WebKit/DOMCore.h>

#import <WebKit/WebScriptObject.h>
#import <WebKit/WebDocument.h>

@class DOMAttr;
@class DOMCDATASection;
@class DOMComment;
@class RENAME(DOMDocument); 
@class DOMDocumentFragment; 
@class DOMDocumentType;
@class DOMElement;
@class DOMEntityReference;
@class DOMImplementation;
@class DOMNodeList;
@class DOMProcessingInstruction;
@class DOMText;

@interface DOMObject : WebScriptObject <NSCopying>
@end

@interface DOMWindow : DOMObject
// this is the global windowScriptObject
/*
 - (DOMHTMLDocument *) document;
 - (DOMAbstractView *) top;
 - (DOMAbstractView *) parent;
 - (DOMAbstractView *) frames;
 */
@end

@interface DOMNode : DOMObject
{
	NSString *_nodeName;
	NSString *_nodeValue;
	NSString *_namespaceURI;
	DOMNodeList *_childNodes;
	DOMNode *_parentNode;
	NSString *_prefix;
	NSObject <WebDocumentView> *_visualRepresentation;			// retained NSView or NSCell or whatever represents the element - will be notified about changes
	unsigned short _nodeType;
}

- (void) _setVisualRepresentation:(NSObject <WebDocumentView> *) view;
- (NSObject <WebDocumentView> *) _visualRepresentation;

- (id) _initWithName:(NSString *) name namespaceURI:(NSString *) uri;
- (void) _setParent:(DOMNode *) p;
- (void) _orphanize;

- (DOMNode *) appendChild:(DOMNode *) node;
- (DOMNodeList *) childNodes;
- (DOMNode *) cloneNode:(BOOL) deep;
- (DOMNode *) firstChild;
- (BOOL) hasAttributes;
- (BOOL) hasChildNodes;
- (DOMNode *) insertBefore:(DOMNode *) node :(DOMNode *) ref;
- (BOOL) isSupported:(NSString *) feature :(NSString *) version;
- (DOMNode *) lastChild;
- (NSString *) localName;
- (NSString *) namespaceURI;
- (DOMNode *) nextSibling;
- (NSString *) nodeName;
- (unsigned short) nodeType;
- (NSString *) nodeValue;
- (void) normalize;
- (RENAME(DOMDocument) *) ownerDocument;
- (DOMNode *) parentNode;
- (NSString *) prefix;
- (DOMNode *) previousSibling;
- (DOMNode *) removeChild:(DOMNode *) node;
- (DOMNode *) replaceChild:(DOMNode *) node :(DOMNode *) old;
- (void) setNodeValue:(NSString *) string;
- (void) setPrefix:(NSString *) prefix;

@end

@interface DOMNodeList : DOMObject
{
	NSMutableArray *_list;
}

- (NSMutableArray *) _list;
- (DOMNode *) item:(unsigned long) index;
- (unsigned long) length;

@end

@interface DOMNamedNodeMap : DOMObject
{
	NSMutableDictionary *_attributes;
}

- (unsigned) length;
- (DOMNode *) getNamedItem:(NSString *) name;
- (DOMNode *) setNamedItem:(DOMNode *) node;
- (DOMNode *) removeNamedItem:(NSString *) name;
- (DOMNode *) item:(unsigned) index;
- (DOMNode *) getNamedItemNS:(NSString *) uri localName:(NSString *) name;
- (DOMNode *) setNamedItemNS:(DOMNode *) node;
- (DOMNode *) removeNamedItemNS:(NSString *) uri localName:(NSString *) name;

@end

@interface DOMElement : DOMNode
{
	DOMNamedNodeMap *_attributes;
}

- (DOMNamedNodeMap *) attributes;
- (NSString *) getAttribute:(NSString *) name;
- (DOMAttr *) getAttributeNode:(NSString *) name;
- (DOMAttr *) getAttributeNodeNS:(NSString *) uri :(NSString *) name;
- (NSString *) getAttributeNS:(NSString *) uri :(NSString *) name;
- (DOMNodeList *) getElementsByTagName:(NSString *) name;
- (DOMNodeList *) getElementsByTagNameNS:(NSString *) uri :(NSString *) name;
- (BOOL) hasAttribute:(NSString *) name;
- (BOOL) hasAttributeNS:(NSString *) uri :(NSString *) name;
- (void) removeAttribute:(NSString *) name;
- (DOMAttr *) removeAttributeNode:(DOMAttr *) attr;
- (void) removeAttributeNS:(NSString *) uri :(NSString *) name;
- (void) setAttribute:(NSString *) name :(NSString *) value;
- (DOMAttr *) setAttributeNode:(DOMAttr *) attr;
- (DOMAttr *) setAttributeNodeNS:(DOMAttr *) attr;
- (void) setAttributeNS:(NSString *) uri :(NSString *) name :(NSString *) value;
- (NSString *) tagName;

@end

@interface RENAME(DOMDocument) : DOMNode

- (DOMAttr *) createAttribute:(NSString *) name;
- (DOMAttr *) createAttributeNS:(NSString *) uri :(NSString *) name;
- (DOMCDATASection *) createCDATASection:(NSString *) data;
- (DOMComment *) createComment:(NSString *) data;
- (DOMDocumentFragment *) createDocumentFragment;
- (DOMElement *) createElement:(NSString *) tag;
- (DOMElement *) createElementNS:(NSString *) uri :(NSString *) name;
- (DOMEntityReference *) createEntityReference:(NSString *) name;
- (DOMProcessingInstruction *) createProcessingInstruction:(NSString *) target :(NSString *) data;
- (DOMText *) createTextNode:(NSString *) data;
- (DOMDocumentType *) doctype;
- (DOMElement *) documentElement;
- (DOMElement *) getElementById:(NSString *) element;
- (DOMNodeList *) getElementsByTagName:(NSString * ) name;
- (DOMNodeList *) getElementsByTagNameNS:(NSString *) uri :(NSString *) name;
- (DOMImplementation *) implementation;
- (DOMNode *) importNode:(DOMNode *) node :(BOOL) deep;

@end

@interface DOMAttr : DOMNode
{
	NSString *_value;	// value can be nil
	DOMElement *_ownerElement;
}

- (id) _initWithName:(NSString *) str value:(NSString *) value;

- (NSString *) name;
- (DOMElement *) ownerElement;
- (void) setValue:(NSString *) value;
- (BOOL) specified;
- (NSString *) value;

@end

@interface DOMCharacterData : DOMNode

- (void) appendData:(NSString *) arg;
- (NSString *) data;
- (void) deleteData:(unsigned long) offset :(unsigned long) count;
- (void) insertData:(unsigned long) offset :(NSString *) arg;
- (void) replaceData:(unsigned long) offset :(unsigned long) count :(NSString *) arg;
- (unsigned long) length;
- (void) setData:(NSString *) data;
- (NSString *) substringData:(unsigned long) offset :(unsigned long) count;

@end

@interface DOMText : DOMCharacterData

- (DOMText *) splitText:(unsigned long) offset;

@end

@interface DOMComment : DOMCharacterData
@end

@interface DOMCDATASection : DOMText
@end
