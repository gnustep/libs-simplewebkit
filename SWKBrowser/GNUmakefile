include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = SWKBrowser

ifeq ($(FOUNDATION_LIB), apple)
ADDITIONAL_GUI_LIBS += \
       -framework SimpleWebKit
else
ADDITIONAL_GUI_LIBS += \
       -lSimpleWebKit
endif


SWKBrowser_OBJC_FILES = \
	main.m \
	MyApplication.m \
	MyComboBoxCell.m \
	MyDocument.m

SWKBrowser_LANGUAGES = English

SWKBrowser_LOCALIZED_RESOURCE_FILES = \
	MainMenu.nib \
	MyDocument.nib

SWKBrowser_MAIN_MODEL_FILE = MainMenu.nib

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make

include GNUmakefile.postamble
