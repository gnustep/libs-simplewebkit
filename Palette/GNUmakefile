#   GNUmakefile 
#
#   Copyright (C) 1999 Free Software Foundation, Inc.
#
#   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
#   Date: 1999
#   
#   This file is part of GNUstep.
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

include $(GNUSTEP_MAKEFILES)/common.make

PALETTE_NAME = SWK
SWK_PALETTE_ICON = SWKPalette
SWK_OBJC_FILES = \
	SWKPalette.m 

SWK_PRINCIPAL_CLASS = SWKPalette

SWK_RESOURCE_FILES = \
	SWKPalette.tiff \
	SWKPalette.gorm \
	palette.table

SWK_STANDARD_INSTALL = no

ADDITIONAL_NATIVE_LIBS+=SimpleWebKit

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/palette.make

-include GNUmakefile.postamble

