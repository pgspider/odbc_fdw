/*-------------------------------------------------------------------------
 *
 * odbc_fdw.h
 *		  foreign-data wrapper for ODBC
 *
 * Copyright (c) 2021, TOSHIBA Corporation
 *
 * IDENTIFICATION
 *		  contrib/odbc_fdw/odbc_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef ODBC_FDW_H
#define ODBC_FDW_H

#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "nodes/execnodes.h"
#include "nodes/pathnodes.h"
#include "utils/relcache.h"

#define REL_ALIAS_PREFIX "r"

/*
 * FDW-specific planner information kept in RelOptInfo.fdw_private for a
 * odbc_fdw foreign table.  For a baserel, this struct is created by
 * odbcGetForeignRelSize, although some fields are not filled till later.
 * odbcGetForeignJoinPaths creates it for a joinrel, and
 * odbcGetForeignUpperPaths creates it for an upperrel.
 */
typedef struct OdbcFdwRelationInfo
{
	/*
	 * True means that the relation can be pushed down. Always true for simple
	 * foreign scan.
	 */
	bool		pushdown_safe;

	/*
	 * Restriction clauses, divided into safe and unsafe to pushdown subsets.
	 * All entries in these lists should have RestrictInfo wrappers; that
	 * improves efficiency of selectivity and cost estimation.
	 */
	List	   *remote_conds;
	List	   *local_conds;

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */
	char	   *q_char;
	char	   *name_qualifier_char;

	RelOptInfo *outerrel;

	/* Grouping information */
	List	   *grouped_tlist;
}			OdbcFdwRelationInfo;

/*
 * Context for deparseExpr
 */
typedef struct deparse_expr_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	RelOptInfo *scanrel;		/* the underlying scan relation. Same as
								 * foreignrel, when that represents a join or
								 * a base relation. */
	StringInfo	buf;			/* output buffer to append to */

	char	   *q_char;
	char	   *name_qualifier_char;
} deparse_expr_cxt;

extern int	odbc_set_transmission_modes(void);
extern void odbc_reset_transmission_modes(int nestlevel);

/* depare.c headers */
extern void odbc_classify_conditions(PlannerInfo *root, RelOptInfo *baserel, List *input_conds,
									 List **remote_conds, List **local_conds);
extern bool odbc_is_foreign_expr(PlannerInfo *root, RelOptInfo *baserel, Expr *expr);
extern void odbc_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
											 List *tlist, List *remote_conds, List *pathkeys,
											 bool has_final_sort, bool has_limit, bool is_subquery,
											 List **retrieved_attrs);
extern List *odbc_build_tlist_to_deparse(RelOptInfo *foreignrel);
const char *odbc_quote_identifier(const char *ident, char *q_char, bool quote_all_identifiers);
void odbc_deparse_column_ref(StringInfo buf, int varno, int varattno,
									RangeTblEntry *rte, bool qualify_col, deparse_expr_cxt *context);
void odbc_deparse_relation(StringInfo buf, Relation rel, char *name_qualifier_char, char *q_char);
#endif							/* ODBC_FDW_H */
