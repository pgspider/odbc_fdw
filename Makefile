##########################################################################
#
#                foreign-data wrapper for ODBC
#
# Copyright (c) 2011, PostgreSQL Global Development Group
# Copyright (c) 2016, CARTO
#
# This software is released under the PostgreSQL Licence
#
# Author: Zheng Yang <zhengyang4k@gmail.com>
#
# IDENTIFICATION
#                 odbc_fdw/Makefile
#
##########################################################################

MODULE_big = odbc_fdw
OBJS = odbc_fdw.o deparse.o

EXTENSION = odbc_fdw
DATA = odbc_fdw--0.5.2.sql \
  odbc_fdw--0.2.0--0.3.0.sql \
  odbc_fdw--0.2.0--0.4.0.sql \
  odbc_fdw--0.3.0--0.4.0.sql \
  odbc_fdw--0.4.0--0.5.0.sql \
  odbc_fdw--0.5.0--0.5.1.sql \
  odbc_fdw--0.5.1--0.5.2.sql

REGRESS = postgresql/new_test postgresql/char postgresql/date postgresql/delete postgresql/float4 postgresql/float8 postgresql/insert postgresql/int4 postgresql/int8 postgresql/select postgresql/timestamp postgresql/update postgresql/ported_postgres_fdw mysql/new_test mysql/char mysql/date mysql/delete mysql/float4 mysql/float8 mysql/insert mysql/int4 mysql/int8 mysql/select mysql/timestamp mysql/update mysql/ported_postgres_fdw 

SHLIB_LINK = -lodbc

ifdef DEBUG
override CFLAGS += -DDEBUG -g -O0
endif

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/odbc_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

ifdef REGRESS_PREFIX
REGRESS_PREFIX_SUB = $(REGRESS_PREFIX)
else
REGRESS_PREFIX_SUB = $(VERSION)
endif

REGRESS := $(addprefix $(REGRESS_PREFIX_SUB)/,$(REGRESS))
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/mysql)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/postgresql)
