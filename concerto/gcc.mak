# Copyright (C) 2010 Erik Rainey
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifeq ($(TARGET_CPU),$(HOST_CPU))
	CROSS_COMPILE=
endif

CC = $(CROSS_COMPILE)gcc
CP = $(CROSS_COMPILE)g++
AS = $(CROSS_COMPILE)as
AR = $(CROSS_COMPILE)ar
LD = $(CROSS_COMPILE)ld

ifdef LOGFILE
LOGGING:=&>$(LOGFILE)
else
LOGGING:=
endif

ifeq ($(strip $($(_MODULE)_TYPE)),library)
	BIN_PRE=lib
	BIN_EXT=.a
else ifeq ($(strip $($(_MODULE)_TYPE)),dsmo)
	BIN_PRE=lib
	BIN_EXT=.so
else
	BIN_PRE=
	BIN_EXT=
endif

$(_MODULE)_BIN  := $($(_MODULE)_TDIR)/$(BIN_PRE)$(TARGET)$(BIN_EXT)
$(_MODULE)_OBJS := $(ASSEMBLY:%.S=$($(_MODULE)_ODIR)/%.o) $(CPPSOURCES:%.cpp=$($(_MODULE)_ODIR)/%.o) $(CSOURCES:%.c=$($(_MODULE)_ODIR)/%.o)
$(_MODULE)_STATIC_LIBS := $(foreach lib,$(STATIC_LIBS),$($(_MODULE)_TDIR)/lib$(lib).a)
$(_MODULE)_SHARED_LIBS := $(foreach lib,$(SHARED_LIBS),$($(_MODULE)_TDIR)/lib$(lib).so)

$(_MODULE)_COPT := -fPIC
ifdef DEBUG 
$(_MODULE)_COPT += 
else
$(_MODULE)_COPT += -O3
endif

ifneq ($(HOST_OS),CYGWIN)
$(_MODULE)_IDIRS += $(HOST_ROOT)/include/compatibility
endif

$(_MODULE)_INCLUDES := $(foreach inc,$($(_MODULE)_IDIRS),-I$(inc))
$(_MODULE)_DEFINES  := $(foreach def,$($(_MODULE)_DEFS),-D$(def))
$(_MODULE)_LIBRARIES:= $(foreach ldir,$($(_MODULE)_LDIRS),-L$(ldir)) $(foreach lib,$(STATIC_LIBS),-l$(lib)) $(foreach lib,$(SHARED_LIBS),-l$(lib)) $(foreach lib,$(SYS_SHARED_LIBS),-l$(lib))
$(_MODULE)_AFLAGS   := $($(_MODULE)_INCLUDES)
$(_MODULE)_LDFLAGS  := --architecture=$(TARGET_CPU)
$(_MODULE)_CPLDFLAGS := $(foreach ldf,$($(_MODULE)_LDFLAGS),-Wl,$(ldf))
$(_MODULE)_CFLAGS   := -c $($(_MODULE)_INCLUDES) $($(_MODULE)_DEFINES) $($(_MODULE)_COPT)

ifdef DEBUG
$(_MODULE)_CFLAGS += -O0 -ggdb
$(_MODULE)_AFLAGS += --gdwarf-2
endif

###################################################
# COMMANDS
###################################################

CLEAN := rm  
CLEANDIR := rm -rf
COPY := cp -f

$(_MODULE)_CLEAN_OBJ  := $(CLEAN) $($(_MODULE)_OBJS)
$(_MODULE)_CLEAN_BIN  := $(CLEAN) $($(_MODULE)_BIN)
$(_MODULE)_ATTRIB_EXE := chmod a+x $($(_MODULE)_BIN)
$(_MODULE)_LN_DSO     := ln -s $($(_MODULE)_BIN).1.0 $($(_MODULE)_BIN)
$(_MODULE)_UNLN_DSO   := rm -f /usr/lib/$(BIN_PRE)$(TARGET)$(BIN_EXT).1.0
$(_MODULE)_INSTALL_DSO:= install -t /usr/lib $($(_MODULE)_BIN) 
$(_MODULE)_UNINSTALL_DSO:=rm -f /usr/lib/$(BIN_PRE)$(TARGET)$(BIN_EXT)
$(_MODULE)_INSTALL_EXE:= install -t /usr/bin $($(_MODULE)_BIN) 
$(_MODULE)_UNINSTALL_EXE:=rm -f /usr/bin/$(BIN_PRE)$(TARGET)$(BIN_EXT)
$(_MODULE)_LINK_LIB   := $(AR) -rscu $($(_MODULE)_BIN) $($(_MODULE)_OBJS) $($(_MODULE)_LIBS)
$(_MODULE)_LINK_EXE   := $(CP) $($(_MODULE)_CPLDFLAGS) $($(_MODULE)_OBJS) $($(_MODULE)_LIBRARIES) -o $($(_MODULE)_BIN)
$(_MODULE)_LINK_DSO   := $(LD) -shared -soname,$($(_MODULE)_BIN).1 -whole-archive $($(_MODULE)_LIBRARIES) -no-whole-archive -o $($(_MODULE)_BIN).1.0 $($(_MODULE)_OBJS)

###################################################
# MACROS FOR COMPILING
###################################################

define $(_MODULE)_DEPEND_CC

$($(_MODULE)_ODIR)/$(1).d: $($(_MODULE)_SDIR)/$(1).c $($(_MODULE)_SDIR)/$(SUBMAKEFILE) $($(_MODULE)_ODIR)/.gitignore
	@echo Generating  Dependency Info from $$(notdir $$<)
	$(Q)$(CC) $($(_MODULE)_INCLUDES) $($(_MODULE)_DEFINES) $$< -MM -MF $($(_MODULE)_ODIR)/$(1).d -MT '$($(_MODULE)_ODIR)/$(1).o:' $(LOGGING)

depend:: $($(_MODULE)_ODIR)/$(1).d

-include $($(_MODULE)_ODIR)/$(1).d

endef

define $(_MODULE)_DEPEND_CP

$($(_MODULE)_ODIR)/$(1).d: $($(_MODULE)_SDIR)/$(1).cpp $($(_MODULE)_SDIR)/$(SUBMAKEFILE) $($(_MODULE)_ODIR)/.gitignore
	@echo Generating  Dependency Info from $$(notdir $$<)
	$(Q)$(CC) $($(_MODULE)_INCLUDES) $($(_MODULE)_DEFINES) $$< -MM -MF $($(_MODULE)_ODIR)/$(1).d -MT '$($(_MODULE)_ODIR)/$(1).o:' $(LOGGING)

depend:: $($(_MODULE)_ODIR)/$(1).d

-include $($(_MODULE)_ODIR)/$(1).d

endef

define $(_MODULE)_DEPEND_AS
# Do nothing...
endef

define $(_MODULE)_PREBUILT
$($(_MODULE)_TDIR)/$(1): $($(_MODULE)_SDIR)/$(1)
	@echo Copying Prebuilt binary to $($(_MODULE)_TDIR)
	-$(Q)$(COPY) $($(_MODULE)_SDIR)/$(1) $($(_MODULE)_TDIR)/$(1)
endef

ifeq ($(strip $($(_MODULE)_TYPE)),library)


define $(_MODULE)_UNINSTALL
uninstall::
	@echo No uninstall step for static libraries
endef

define $(_MODULE)_INSTALL
install::
	@echo No install step for static libraries
endef

define $(_MODULE)_BUILD
build:: $($(_MODULE)_BIN)
endef

define $(_MODULE)_CLEAN_LNK
clean::
endef

else ifeq ($(strip $($(_MODULE)_TYPE)),dsmo)

define $(_MODULE)_UNINSTALL
uninstall::
	@echo Uninstalling $$@
	-$(Q)$(call $(_MODULE)_UNLN_DSO)
	-$(Q)$(call $(_MODULE)_UNINSTALL_DSO)
endef

define $(_MODULE)_INSTALL
install::
	@echo Installing $($(_MODULE)_BIN)
	-$(Q)$(call $(_MODULE)_INSTALL_DSO)
	-$(Q)$(call $(_MODULE)_LN_DSO)
endef

define $(_MODULE)_BUILD
build:: $($(_MODULE)_BIN)
endef

define $(_MODULE)_CLEAN_LNK
clean::
	@echo Removing Link for Shared Object $($(_MODULE)_BIN).1.0
	-$(Q)$(CLEAN) $($(_MODULE)_BIN).1.0
endef

else ifeq ($(strip $($(_MODULE)_TYPE)),exe)

define $(_MODULE)_UNINSTALL
uninstall::
	-$(Q)$(call $(_MODULE)_UNINSTALL_EXE)
endef

define $(_MODULE)_INSTALL
install::
	@echo Installing $($(_MODULE)_BIN)
	-$(Q)$(call $(_MODULE)_INSTALL_EXE)
	-$(Q)$(call $(_MODULE)_ATTRIB_EXE)
endef

define $(_MODULE)_BUILD
build:: $($(_MODULE)_BIN)
	@echo Building for $($(_MODULE)_BIN)
endef

define $(_MODULE)_CLEAN_LNK
clean::
endef

endif

define $(_MODULE)_COMPILE_TOOLS
$($(_MODULE)_ODIR)/%.o: $($(_MODULE)_SDIR)/%.c
	@echo [PURE] Compiling C99 $$(notdir $$<)
	$(Q)$(CC) -std=c99 $($(_MODULE)_CFLAGS) $$< -o $$@ $(LOGGING)

$($(_MODULE)_ODIR)/%.o: $($(_MODULE)_SDIR)/%.cpp
	@echo [PURE] Compiling C++ $$(notdir $$<)
	$(Q)$(CP) $($(_MODULE)_CFLAGS) $$< -o $$@  $(LOGGING)

$($(_MODULE)_ODIR)/%.o: $($(_MODULE)_SDIR)/%.S 
	@echo [PURE] Assembling $$(notdir $$<)
	$(Q)$(AS) $($(_MODULE)_AFLAGS) $$< -o $$@ $(LOGGING)
endef