//
//  DOMCore.h
//  SimpleWebKit
//
//  Created by Dr. H. Nikolaus Schaller on 02.11.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#ifdef __mySTEP__
// gcc 2.95.3 does not allow methods with the same name as a class, i.e.
// - (DOMDocument *) DOMDocument;
// you should wrap the class name with this macro i.e.
// - (RENAME(DOMDocument) *) DOMDocument;
#define RENAME(X) _class_##X
#else
#define RENAME(X) X
#endif

#import <Cocoa/Cocoa.h>

// #import <WebKit/DOMCore.h>

#import <WebKit/WebScriptObject.h>

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
{
}
@end

@interface DOMNode : DOMObject
{
	NSString *_nodeName;
	NSString *_nodeValue;
	NSString *_namespaceURI;
	DOMNodeList *_childNodes;
	DOMNode *_parentNode;
	RENAME(DOMDocument) *_document;
	NSString *_prefix;
	unsigned short _nodeType;
}

- (id) _initWithName:(NSString *) name namespaceURI:(NSString *) uri document:(RENAME(DOMDocument) *) document;
- (void) _setParent:(DOMNode *) p;

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

@interface DOMElement : DOMNode
{
	NSMutableDictionary *_attributes;	// name -> DOMAttr
}

- (NSArray *) _attributes;
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
	NSString *_name;
	NSString *_value;	// value can be nil
	DOMElement *_ownerElement;
}

- (id) _initWithName:(NSString *) str value:(NSString *) value;
- (void) _setOwner:(DOMElement *) owner;

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
