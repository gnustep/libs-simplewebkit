ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif


include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=SimpleWebKit
SimpleWebKit_INTERFACE_VERSION=0.1


FRAMEWORK_NAME=SimpleWebKit
SimpleWebKit_HEADER_FILES_INSTALL_DIR = WebKit

LIBRARIES_DEPEND_UPON = $(FND_LIBS) $(OBJC_LIBS)

SimpleWebKit_HEADER_FILES = \
DOM.h \
DOMCore.h \
DOMCSS.h \
DOMHTML.h \
DOMRange.h \
ECMAScriptEvaluator.h \
ECMAScriptParser.h \
ECMAScriptPrototypes.h \
Private.h \
WebArchive.h \
WebBackForwardList.h \
WebCSSDocumentRepresentation.h \
WebDocumentRepresentation.h \
WebDOMOperations.h \
WebDataSource.h \
WebDocument.h \
WebDownload.h \
WebFrame.h \
WebFrameLoadDelegate.h \
WebFrameView.h \
WebHTMLDocumentView.h \
WebHTMLDocumentRepresentation.h \
WebHistory.h \
WebHistoryItem.h \
WebImageDocument.h \
WebKit.h \
WebPDFDocument.h \
WebPlugin.h \
WebPluginContainer.h \
WebPreferences.h \
WebResource.h \
WebResourceLoadDelegate.h \
WebScriptObject.h \
WebTextDocument.h \
WebUIDelegate.h \
WebUndefined.h \
WebView.h \
WebXMLDocument.h 

SimpleWebKit_OBJC_FILES = \
DOMCore.m \
DOMCSS.m \
DOMHTML.m \
DOMRange.m \
ECMAScriptEvaluator.m \
ECMAScriptParser.m \
ECMAScriptPrototypes.m \
WebArchive.m \
WebBackForwardList.m \
WebCSSDocumentRepresentation.m \
WebDocumentRepresentation.m \
WebDOMOperations.m \
WebDataSource.m \
WebFrame.m \
WebFrameView.m \
WebHTMLDocumentView.m \
WebHTMLDocumentRepresentation.m \
WebHistory.m \
WebHistoryItem.m \
WebImageDocument.m \
WebPDFDocument.m \
WebPreferences.m \
WebResource.m \
WebScriptObject.m \
WebTextDocument.m \
WebView.m \
WebXMLDocument.m

SimpleWebKit_RESOURCE_FILES = \
	WebKitIMG.png \
	HTMLEntities.strings \
	DOMHTMLColors.plist \
	DOMHTML.plist \
	default.css

-include Makefile.preamble
-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/framework.make

-include Makefile.postamble
