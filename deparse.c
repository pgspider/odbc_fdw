/*-------------------------------------------------------------------------
 *
 * deparse.c
 *		  Query deparser for odbc_fdw
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 * Portions Copyright (c) 2012-2021, PostgreSQL Global Development Group
 *
 * IDENTIFICATION
 *		  contrib/odbc_fdw/deparse.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/htup_details.h"
#include "access/sysattr.h"
#include "access/table.h"
#include "catalog/pg_aggregate.h"
#include "catalog/pg_collation.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "common/keywords.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "nodes/plannodes.h"
#include "optimizer/optimizer.h"
#include "optimizer/prep.h"
#include "optimizer/tlist.h"
#include "parser/parsetree.h"
#include "odbc_fdw.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/syscache.h"
#include "utils/typcache.h"
#include "commands/tablecmds.h"
#include "catalog/namespace.h"
#include "catalog/pg_type.h"

/*
 * Global context for odbc_foreign_expr_walker's search of an expression tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	Relids		relids;			/* relids of base relations in the underlying
								 * scan */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for odbc_foreign_expr_walker's search.
 * This is concerned with identifying collations used in the expression.
 */
typedef enum
{
	FDW_COLLATE_NONE,			/* expression is of a noncollatable type, or
								 * it has default collation that is not
								 * traceable to a foreign Var */
	FDW_COLLATE_SAFE,			/* collation derives from a foreign Var */
	FDW_COLLATE_UNSAFE			/* collation is non-default and derives from
								 * something other than a foreign Var */
} FDWCollateState;

typedef struct foreign_loc_cxt
{
	Oid			collation;		/* OID of current collation, if any */
	FDWCollateState state;		/* state of current collation choice */
	bool		is_op_args;		/* outer is T_OpExpr or not */
	bool		is_scalar_array_op_arg;	/* outer is T_ScalarArrayOpExpr or not */
} foreign_loc_cxt;

/*
 * odbcSupportedBuiltinAggFunction
 * List of supported builtin aggregate functions for odbc
 */
static const char *odbcSupportedBuiltinAggFunction[] = {
	"avg",
	"bit_and",
	"bit_or",
	"count",
	"max",
	"min",
	"stddev_pop",
	"stddev_samp",
	"sum",
	"var_pop",
	"var_samp",
	NULL};

/*
 * odbcSupportedBuiltinOperators
 * List of supported builtin operator for odbc
 */
static const char *odbcSupportedBuiltinOperators[] = {
	/* Comparison operators */
	">",
	"<",
	">=",
	"<=",
	"=",
	"<>",
	"!=",
	/* Mathematical operators */
	"+",
	"-",
	"*",
	/* "/", Does not support / operator */
	"%",						/* MOD */
	/* String operators */
	"||",						/* Concatenates */
	/* Pattern matching operators */
	"~~",						/* LIKE */
	"!~~",						/* NOT LIKE */
	NULL};

/*
 * OdbcCommonFunctions:
 *		- List of common function for ODBC driver
 *		- This list is confirmed with PostgreSQL and MySQL.
 */
static const char *OdbcCommonFunctions[] = {
	"nullif",
	/* Numeric functions */
	"abs",
	"acos",
	"asin",
	"atan",
	"atan2",
	"ceil",
	"ceiling",
	"cos",
	"cot",
	"degrees",
	"div",
	"exp",
	"floor",
	"ln",
	"log",
	"log10",
	"mod",
	"pow",
	"power",
	"radians",
	"round",
	"sign",
	"sin",
	"sqrt",
	"tan",
	/* String functions */
	"ascii",
	"bit_length",
	"char_length",
	"character_length",
	"concat",
	"concat_ws",
	"left",
	"length",
	"lower",
	"lpad",
	"octet_length",
	"repeat",
	"replace",
	"reverse",
	"right",
	"rpad",
	"position",
	"regexp_replace",
	"substr",
	"substring",
	"upper",
	/* Datetime function */
	"date",
	NULL};

/*
 * CastFunctions
 * List of PostgreSQL cast functions, these functions can be push down.
 */
static const char *CastFunctions[] = {
	"float4",
	/* date time cast */
	"date",
	"time",
	NULL};

bool		odbc_is_builtin(Oid oid);
static bool odbc_foreign_expr_walker(Node *node,
									 foreign_glob_cxt *glob_cxt,
									 foreign_loc_cxt *outer_cxt);

/*
 * Functions to construct string representation of a node tree.
 */
static void odbc_deparse_target_list(StringInfo buf,
									 RangeTblEntry *rte,
									 Index rtindex,
									 Relation rel,
									 bool is_returning,
									 Bitmapset *attrs_used,
									 bool qualify_col,
									 List **retrieved_attrs,
									 deparse_expr_cxt *context);
static void odbc_deparse_expr(Expr *expr, deparse_expr_cxt *context);
static void odbc_deparse_var(Var *node, deparse_expr_cxt *context);
static void odbc_deparse_const(Const *node, deparse_expr_cxt *context);
static void odbc_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context);
static void odbc_deparse_nullif_expr(NullIfExpr *node, deparse_expr_cxt *context);
static void odbc_deparse_operator_name(StringInfo buf, Form_pg_operator opform);
static void odbc_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context);
static void odbc_deparse_null_test(NullTest *node, deparse_expr_cxt *context);
static void odbc_deparse_boolean_test(BooleanTest *node, deparse_expr_cxt *context);
static void odbc_deparse_aggref(Aggref *node, deparse_expr_cxt *context);
static void odbc_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context);
static char *odbc_deparse_cast_function(char *function_name, Oid type_oid, int32 typemod);
static void odbc_deparse_select_sql(List *tlist, List **retrieved_attrs,
									deparse_expr_cxt *context);
static void odbc_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root,
										   RelOptInfo *foreignrel, bool use_alias,
										   Index ignore_rel, List **ignore_conds,
										   List **params_list);
static void odbc_deparse_from_expr(List *quals, deparse_expr_cxt *context);
static void odbc_deparse_string_literal(StringInfo buf, const char *val);
static void odbc_deparse_function_name(Oid funcid, deparse_expr_cxt *context);
static void odbc_deparse_explicit_target_list(List *tlist,
											  bool is_returning,
											  List **retrieved_attrs,
											  deparse_expr_cxt *context);
static void odbc_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node, deparse_expr_cxt *context);
static bool odbc_is_str_exist_in_list(char *str, const char **list);
static void odbc_deconstruct_constant_array(Const *node, bool **elem_nulls,
											Datum **elem_values, Oid *elmtype, int *num_elems);
static void odbc_append_constant_value(StringInfo buf, Oid const_type, char *extval);
static void odbc_append_conditions(List *exprs, deparse_expr_cxt *context);
static bool odbc_is_supported_type(Oid type);
static bool odbc_is_supported_builtin_func(Oid funcid, char *in);

/*
 * Returns true if given expr is safe to evaluate on the foreign server.
 */
bool
odbc_is_foreign_expr(PlannerInfo *root,
					 RelOptInfo *baserel,
					 Expr *expr)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) (baserel->fdw_private);

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	glob_cxt.root = root;
	glob_cxt.foreignrel = baserel;

	/*
	 * For an upper relation, use relids from its underneath scan relation,
	 * because the upperrel's own relids currently aren't set to anything
	 * meaningful by the core code.  For other relation, use their own relids.
	 */
	if (IS_UPPER_REL(baserel))
		glob_cxt.relids = fpinfo->outerrel->relids;
	else
		glob_cxt.relids = baserel->relids;
	loc_cxt.collation = InvalidOid;
	loc_cxt.state = FDW_COLLATE_NONE;
	loc_cxt.is_op_args = false;
	loc_cxt.is_scalar_array_op_arg = false;
	if (!odbc_foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	/*
	 * If the expression has a valid collation that does not arise from a
	 * foreign var, the expression can not be sent over.
	 */
	if (loc_cxt.state == FDW_COLLATE_UNSAFE)
		return false;

	/* OK to evaluate on the remote server */
	return true;
}


/*
 * Check if expression is safe to execute remotely, and return true if so.
 *
 * In addition, *outer_cxt is updated with collation information.
 *
 * We must check that the expression contains only node types we can deparse,
 * that all types/functions/operators are safe to send (they are "shippable"),
 * and that all collations used in the expression derive from Vars of the
 * foreign table.  Because of the latter, the logic is pretty close to
 * assign_collations_walker() in parse_collate.c, though we can assume here
 * that the given expression is valid.  Note function mutability is not
 * currently considered here.
 */
static bool
odbc_foreign_expr_walker(Node *node,
						 foreign_glob_cxt *glob_cxt,
						 foreign_loc_cxt *outer_cxt)
{
	bool		check_type = true;
	foreign_loc_cxt inner_cxt;
	Oid			collation;
	FDWCollateState state;
	HeapTuple	tuple;

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;
	inner_cxt.is_op_args = outer_cxt->is_op_args;
	inner_cxt.is_scalar_array_op_arg = outer_cxt->is_scalar_array_op_arg;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;

				/* Check var type if it is an arg of an operator */
				if (outer_cxt->is_op_args && !odbc_is_supported_type(var->vartype))
					return false;

				/*
				 * If the Var is from the foreign table, we consider its
				 * collation (if any) safe to use.  If it is from another
				 * table, we treat its collation the same way as we would a
				 * Param's collation, ie it's not safe for it to have a
				 * non-default collation.
				 */
				if (bms_is_member(var->varno, glob_cxt->relids) &&
					var->varlevelsup == 0)
				{
					/* Var belongs to foreign table */

					/*
					 * System columns should not be sent to the remote, since
					 * we don't make any effort to ensure that local and
					 * remote values match (tableoid, in particular, almost
					 * certainly doesn't match).
					 */
					if (var->varattno < 0)
						return false;

					/* Else check the collation */
					collation = var->varcollid;
					state = OidIsValid(collation) ? FDW_COLLATE_SAFE : FDW_COLLATE_NONE;
				}
				else
				{
					/* Parameter is unsupported */
					return false;
				}
			}
			break;
		case T_Const:
			{
				Const	   *c = (Const *) node;

				/* Does not support push-down bytea constant */
				if (c->consttype == BYTEAOID)
					return false;
				/* Check const type if it is an arg of an operator */
				if (outer_cxt->is_op_args && !odbc_is_supported_type(c->consttype))
					return false;

				/*
				 * If the constant has nondefault collation, either it's of a
				 * non-builtin type, or it reflects folding of a CollateExpr.
				 * It's unsafe to send to the remote unless it's used in a
				 * non-collation-sensitive context.
				 */
				collation = c->constcollid;
				if (collation == InvalidOid ||
					collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_DistinctExpr:
			/* Does not support pushdown T_DistinctExpr */
			return false;
		case T_NullIfExpr:
		case T_OpExpr:
			{
				OpExpr	   *oe = (OpExpr *) node;
				char	   *oprname;
				Form_pg_operator form;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!odbc_is_builtin(oe->opno))
					return false;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				/* Get operation name */
				oprname = pstrdup(NameStr(form->oprname));
				ReleaseSysCache(tuple);

				/*
				 * odbc does not support push-down operator which not exsisted
				 * in odbcSupportedBuiltinOperators
				 */
				if (!odbc_is_str_exist_in_list(oprname, odbcSupportedBuiltinOperators))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				inner_cxt.is_op_args = true;
				if (!odbc_foreign_expr_walker((Node *) oe->args,
											  glob_cxt, &inner_cxt))
					return false;
				inner_cxt.is_op_args = false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Result-collation handling is same as for functions */
				collation = oe->opcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_BoolExpr:
			{
				BoolExpr   *b = (BoolExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!odbc_foreign_expr_walker((Node *) b->args,
											  glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_NullTest:
			{
				NullTest   *nt = (NullTest *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!odbc_foreign_expr_walker((Node *) nt->arg,
											  glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_BooleanTest:
			{
				BooleanTest *bt = (BooleanTest *) node;

				if (bt->booltesttype == IS_UNKNOWN || bt->booltesttype == IS_NOT_UNKNOWN)
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!odbc_foreign_expr_walker((Node *) bt->arg,
											  glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_ScalarArrayOpExpr:
			{
				ScalarArrayOpExpr *oe = (ScalarArrayOpExpr *) node;
				Form_pg_operator	form;
				char	   *oprname = NULL;

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!odbc_is_builtin(oe->opno))
					return false;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				/* Get operation name */
				oprname = pstrdup(NameStr(form->oprname));
				ReleaseSysCache(tuple);

				/* Only support push down equal or not-equal operator. */
				if (!(strcmp(oprname, "=") == 0 ||
					  strcmp(oprname, "<>") == 0 ||
					  strcmp(oprname, "!=") == 0))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				inner_cxt.is_scalar_array_op_arg = true;
				if (!odbc_foreign_expr_walker((Node *) oe->args,
											  glob_cxt, &inner_cxt))
					return false;
				inner_cxt.is_scalar_array_op_arg = false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_ArrayExpr:
			{
				ArrayExpr  *a = (ArrayExpr *) node;

				/* just support array in side T_ScalarArrayOpExpr */
				if (!inner_cxt.is_scalar_array_op_arg)
					return false;
				/*
				 * Recurse to input subexpressions.
				 */
				if (!odbc_foreign_expr_walker((Node *) a->elements,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * ArrayExpr must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = a->array_collid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_List:
			{
				List	   *l = (List *) node;
				ListCell   *lc;

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!odbc_foreign_expr_walker((Node *) lfirst(lc),
												  glob_cxt, &inner_cxt))
						return false;
				}

				/*
				 * When processing a list, collation state just bubbles up
				 * from the list elements.
				 */
				collation = inner_cxt.collation;
				state = inner_cxt.state;

				/* Don't apply exprType() to the list. */
				check_type = false;
			}
			break;
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;
				ListCell   *lc;
				char	   *aggname = NULL;

				/* Not safe to pushdown when not in grouping context */
				if (!IS_UPPER_REL(glob_cxt->foreignrel))
					return false;

				/* Only non-split aggregates are pushable. */
				if (agg->aggsplit != AGGSPLIT_SIMPLE)
					return false;

				/*
				 * Does not support VARIADIC, FILTER and ORDER BY inside
				 * aggregate function
				 */
				if (agg->aggfilter != NULL ||
					agg->aggorder != NIL ||
					agg->aggvariadic == true)
					return false;

				/* get function name */
				aggname = get_func_name(agg->aggfnoid);

				/*
				 * Does not push down aggregate function if it not in
				 * odbcSupportedBuiltinAggFunction
				 */
				if (!odbc_is_str_exist_in_list(aggname, odbcSupportedBuiltinAggFunction))
					return false;

				if (agg->aggdistinct != NIL &&
				   !(strcmp(aggname, "max") == 0 ||
				   strcmp(aggname, "min") == 0 ||
				   strcmp(aggname, "avg") == 0 ||
				   strcmp(aggname, "sum") == 0 ||
				   strcmp(aggname, "count") == 0))
					return false;

				/*
				 * Recurse to input args.
				 */
				foreach(lc, agg->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					/* If TargetEntry, extract the expression from it */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;
					}

					if (!odbc_foreign_expr_walker(n, glob_cxt, &inner_cxt))
						return false;
				}

				/*
				 * If aggregate's input collation is not derived from a
				 * foreign Var, it can't be sent to remote.
				 */
				if (agg->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 agg->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
				 */
				collation = agg->aggcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_FuncExpr:
			{
				FuncExpr   *fe = (FuncExpr *) node;
				char	   *funcname = NULL;
				bool		is_cast_functions = false;
				bool		is_common_function = false;

				/*
				 * If function used by the expression is not built-in, it
				 * can't be sent to remote because it might have incompatible
				 * semantics on remote side.
				 */
				funcname = get_func_name(fe->funcid);

				/* check NULL for funcname */
				if (funcname == NULL)
					elog(ERROR, "cache lookup failed for function %u", fe->funcid);

				/*
				 * Check cast functions:
				 * - IMPLICIT CAST will be skip
				 * - EXPLICIT CAST existed in CastFunctions list will be pushed-down
				 */
				if (fe->funcformat == COERCE_IMPLICIT_CAST ||
				    (fe->funcformat == COERCE_EXPLICIT_CAST &&
					odbc_is_str_exist_in_list(funcname, CastFunctions)))
				{
					is_cast_functions = true;
				}
				else if (fe->funcformat != COERCE_EXPLICIT_CAST)
				{
					/* odbc supported builtin functions */
					if (odbc_is_supported_builtin_func(fe->funcid, funcname))
						is_common_function = true;
				}

				/*
				 * Does not push down function to odbc data source if it not
				 * a supported cast function or common function
				 */
				if (!is_cast_functions &&
					!is_common_function)
					return false;

				/* Just support push-down log with 2 arguments */
				if (strcmp(funcname, "log") == 0 && list_length(fe->args) != 2)
					return false;

				/* Does not support push-down regexp_replace with more than 3 arguments */
				if (strcmp(funcname, "regexp_replace") == 0 && list_length(fe->args) > 3)
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!odbc_foreign_expr_walker((Node *) fe->args,
											  glob_cxt, &inner_cxt))
					return false;

				/*
				 * If function's input collation is not derived from a
				 * foreign Var, it can't be sent to remote.
				 */
				if (fe->inputcollid == InvalidOid)
						/* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						fe->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not
				 * derived from a foreign Var.  (If so, we just mark it
				 * unsafe for now rather than immediately returning false,
				 * since the parent node might not care.)
				 */
				collation = fe->funccollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
							collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		default:

			/*
			 * If it's anything else, assume it's unsafe.  This list can be
			 * expanded later, but don't forget to add deparse support below.
			 */
			return false;
	}

	/*
	 * If result type of given expression is not shippable, it can't be sent
	 * to remote because it might have incompatible semantics on remote side.
	 */
	if (check_type && !odbc_is_builtin(exprType(node)))
		return false;

	/*
	 * Now, merge my collation information into my parent's state.
	 */
	if (state > outer_cxt->state)
	{
		/* Override previous parent state */
		outer_cxt->collation = collation;
		outer_cxt->state = state;
	}
	else if (state == outer_cxt->state)
	{
		/* Merge, or detect error if there's a collation conflict */
		switch (state)
		{
			case FDW_COLLATE_NONE:
				/* Nothing + nothing is still nothing */
				break;
			case FDW_COLLATE_SAFE:
				if (collation != outer_cxt->collation)
				{
					/*
					 * Non-default collation always beats default.
					 */
					if (outer_cxt->collation == DEFAULT_COLLATION_OID)
					{
						/* Override previous parent state */
						outer_cxt->collation = collation;
					}
					else if (collation != DEFAULT_COLLATION_OID)
					{
						/*
						 * Conflict; show state as indeterminate.  We don't
						 * want to "return false" right away, since parent
						 * node might not care about collation.
						 */
						outer_cxt->state = FDW_COLLATE_UNSAFE;
					}
				}
				break;
			case FDW_COLLATE_UNSAFE:
				/* We're still conflicted ... */
				break;
		}
	}

	/* It looks OK */
	return true;
}

/*
 * Examine each qual clause in input_conds, and classify them into two groups,
 * which are returned as two lists:
 *	- remote_conds contains expressions that can be evaluated remotely
 *	- local_conds contains expressions that can't be evaluated remotely
 */
void
odbc_classify_conditions(PlannerInfo *root,
						 RelOptInfo *baserel,
						 List *input_conds,
						 List **remote_conds,
						 List **local_conds)
{
	ListCell   *lc;

	*remote_conds = NIL;
	*local_conds = NIL;

	foreach(lc, input_conds)
	{
		RestrictInfo *ri = lfirst_node(RestrictInfo, lc);

		if (odbc_is_foreign_expr(root, baserel, ri->clause))
			*remote_conds = lappend(*remote_conds, ri);
		else
			*local_conds = lappend(*local_conds, ri);
	}
}


/*
 * Return true if given object is one of PostgreSQL's built-in objects.
 *
 * We use FirstBootstrapObjectId as the cutoff, so that we only consider
 * objects with hand-assigned OIDs to be "built in", not for instance any
 * function or type defined in the information_schema.
 *
 * Our constraints for dealing with types are tighter than they are for
 * functions or operators: we want to accept only types that are in pg_catalog,
 * else format_type might incorrectly fail to schema-qualify their names.
 * (This could be fixed with some changes to format_type, but for now there's
 * no need.)  Thus we must exclude information_schema types.
 *
 * XXX there is a problem with this, which is that the set of built-in
 * objects expands over time.  Something that is built-in to us might not
 * be known to the remote server, if it's of an older version.  But keeping
 * track of that would be a huge exercise.
 */
bool
odbc_is_builtin(Oid oid)
{
	return (oid < FirstGenbkiObjectId);
}


/*
 * Deparse SELECT statement for given relation into buf.
 *
 * tlist contains the list of desired columns to be fetched from foreign server.
 * For a base relation fpinfo->attrs_used is used to construct SELECT clause,
 * hence the tlist is ignored for a base relation.
 *
 * remote_conds is the list of conditions to be deparsed into the WHERE clause
 * (or, in the case of upper relations, into the HAVING clause).
 *
 * If params_list is not NULL, it receives a list of Params and other-relation
 * Vars used in the clauses; these values must be transmitted to the remote
 * server as parameter values.
 *
 * pathkeys is the list of pathkeys to order the result by.
 *
 * is_subquery is the flag to indicate whether to deparse the specified
 * relation as a subquery.
 *
 * List of columns selected is returned in retrieved_attrs.
 */
void
odbc_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
								 List *tlist, List *remote_conds, List *pathkeys,
								 bool has_final_sort, bool has_limit, bool is_subquery,
								 List **retrieved_attrs)
{
	deparse_expr_cxt context;
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) rel->fdw_private;
	List	   *quals;

	/*
	 * We handle relations for foreign tables, joins between those and upper
	 * relations.
	 */
	Assert(IS_SIMPLE_REL(rel) || IS_UPPER_REL(rel));

	/* Fill portions of context common to upper, join and base relation */
	context.buf = buf;
	context.root = root;
	context.foreignrel = rel;
	context.q_char = fpinfo->q_char;
	context.name_qualifier_char = fpinfo->name_qualifier_char;
	context.scanrel = IS_UPPER_REL(rel) ? fpinfo->outerrel : rel;

	/*
	 * For upper relations, the WHERE clause is built from the remote
	 * conditions of the underlying scan relation; otherwise, we can use the
	 * supplied list of remote conditions directly.
	 */
	if (IS_UPPER_REL(rel))
	{
		OdbcFdwRelationInfo *ofpinfo;

		ofpinfo = (OdbcFdwRelationInfo *) fpinfo->outerrel->fdw_private;
		quals = ofpinfo->remote_conds;
	}
	else
		quals = remote_conds;

	/* Construct SELECT clause */
	odbc_deparse_select_sql(tlist, retrieved_attrs, &context);

	/* Construct FROM and WHERE clauses */
	odbc_deparse_from_expr(quals, &context);
}

/*
 * Construct a simple SELECT statement that retrieves desired columns
 * of the specified foreign table, and append it to "buf".  The output
 * contains just "SELECT ... ".
 *
 * We also create an integer List of the columns being retrieved, which is
 * returned to *retrieved_attrs, unless we deparse the specified relation
 * as a subquery.
 *
 * tlist is the list of desired columns.  is_subquery is the flag to
 * indicate whether to deparse the specified relation as a subquery.
 * Read prologue of odbc_deparse_select_stmt_for_rel() for details.
 */
static void
odbc_deparse_select_sql(List *tlist, List **retrieved_attrs,
						deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *foreignrel = context->foreignrel;
	PlannerInfo *root = context->root;
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) foreignrel->fdw_private;

	/*
	 * Construct SELECT list
	 */
	appendStringInfoString(buf, "SELECT ");
	if (IS_UPPER_REL(foreignrel))
	{
		/*
		 * For a join or upper relation the input tlist gives the list of
		 * columns required to be fetched from the foreign server.
		 */
		odbc_deparse_explicit_target_list(tlist, false, retrieved_attrs, context);
	}
	else
	{
		/*
		 * For a base relation fpinfo->attrs_used gives the list of columns
		 * required to be fetched from the foreign server.
		 */
		RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel = table_open(rte->relid, NoLock);

		odbc_deparse_target_list(buf, rte, foreignrel->relid, rel, false,
								 fpinfo->attrs_used, false, retrieved_attrs, context);
		table_close(rel, NoLock);
	}
}

/*
 * Construct a FROM clause and, if needed, a WHERE clause, and append those to
 * "buf".
 *
 * quals is the list of clauses to be included in the WHERE clause.
 * (These may or may not include RestrictInfo decoration.)
 */
static void
odbc_deparse_from_expr(List *quals, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *scanrel = context->scanrel;

	/* For upper relations, scanrel must be either a joinrel or a baserel */
	Assert(!IS_UPPER_REL(context->foreignrel) ||
		   IS_JOIN_REL(scanrel) || IS_SIMPLE_REL(scanrel));

	/* Construct FROM clause */
	appendStringInfoString(buf, " FROM ");
	odbc_deparse_from_expr_for_rel(buf, context->root, scanrel,
								   (bms_membership(scanrel->relids) == BMS_MULTIPLE),
								   (Index) 0, NULL, NULL);

	/* Construct WHERE clause */
	if (quals != NIL)
	{
		appendStringInfoString(buf, " WHERE ");
		odbc_append_conditions(quals, context);
	}
}

/*
 * Deparse given targetlist and append it to paremeter of select
 *
 * tlist is list of TargetEntry's which in turn contain Var nodes.
 *
 * retrieved_attrs is the list of continuously increasing integers starting
 * from 1. It has same number of entries as tlist.
 *
 * This is used for both SELECT and RETURNING targetlists; the is_returning
 * parameter is true only for a RETURNING targetlist.
 */
static void
odbc_deparse_explicit_target_list(List *tlist,
								  bool is_returning,
								  List **retrieved_attrs,
								  deparse_expr_cxt *context)
{
	ListCell   *lc;
	int			i = 0;

	*retrieved_attrs = NIL;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (i > 0)
			appendStringInfoString(context->buf, ", ");

		odbc_deparse_expr((Expr *) tle->expr, context);

		*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
		i++;
	}

	if (i == 0)
            appendStringInfoString(context->buf, "NULL");
}

/*
 * Emit a target list that retrieves the columns specified in attrs_used.
 * This is used for both SELECT and RETURNING targetlists; the is_returning
 * parameter is true only for a RETURNING targetlist.
 *
 * The tlist text is appended to buf, and we also create an integer List
 * of the columns being retrieved, which is returned to *retrieved_attrs.
 *
 * If qualify_col is true, add relation alias before the column name.
 */
static void
odbc_deparse_target_list(StringInfo buf,
						 RangeTblEntry *rte,
						 Index rtindex,
						 Relation rel,
						 bool is_returning,
						 Bitmapset *attrs_used,
						 bool qualify_col,
						 List **retrieved_attrs,
						 deparse_expr_cxt *context)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	bool		have_wholerow;
	bool		first;
	int			i;

	*retrieved_attrs = NIL;

	/* If there's a whole-row reference, we'll need all the columns. */
	have_wholerow = bms_is_member(0 - FirstLowInvalidHeapAttributeNumber,
								  attrs_used);

	first = true;
	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		if (have_wholerow ||
			bms_is_member(i - FirstLowInvalidHeapAttributeNumber,
						  attrs_used))
		{
			if (!first)
				appendStringInfoString(buf, ", ");

			first = false;

			odbc_deparse_column_ref(buf, rtindex, i, rte, qualify_col, context);

			*retrieved_attrs = lappend_int(*retrieved_attrs, i);
		}
	}

	/* Don't generate bad syntax if no undropped columns */
	if (first)
		appendStringInfoString(buf, "NULL");
}

/*
 * Construct FROM clause for given relation
 *
 * 'ignore_rel' is either zero or the RT index of a target relation.  In the
 * latter case the function constructs FROM clause of UPDATE or USING clause
 * of DELETE; it deparses the join relation as if the relation never contained
 * the target relation, and creates a List of conditions to be deparsed into
 * the top-level WHERE clause, which is returned to *ignore_conds.
 */
static void
odbc_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *foreignrel,
							   bool use_alias, Index ignore_rel, List **ignore_conds,
							   List **params_list)
{
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) foreignrel->fdw_private;

	RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
	Relation	rel = table_open(rte->relid, NoLock);

	odbc_deparse_relation(buf, rel, fpinfo->name_qualifier_char, fpinfo->q_char);

	/*
	 * Add a unique alias to avoid any conflict in relation names due to
	 * pulled up subqueries in the query being built for a pushed down join.
	 */
	if (use_alias)
		appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, foreignrel->relid);

	table_close(rel, NoLock);
}

/*
 * Append remote name of specified foreign table to buf.
 * Use value of table_name FDW option (if any) instead of relation's name.
 * Similarly, schema_name FDW option overrides schema name.
 */
void
odbc_deparse_relation(StringInfo buf, Relation rel, char *name_qualifier_char, char *q_char)
{
	ForeignTable *table;
	const char *nspname = NULL;
	const char *relname = NULL;
	ListCell   *lc;

	/* obtain additional catalog information. */
	table = GetForeignTable(RelationGetRelid(rel));

	/*
	 * Use value of FDW options if any, instead of the name of object itself.
	 */
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "schema") == 0)
			nspname = defGetString(def);
		else if (strcmp(def->defname, "table") == 0)
			relname = defGetString(def);
	}

	/*
	 * Note: we could skip printing the schema name if it's pg_catalog, but
	 * that doesn't seem worth the trouble.
	 */
	if (nspname == NULL)
		nspname = get_namespace_name(RelationGetNamespace(rel));
	if (relname == NULL)
		relname = RelationGetRelationName(rel);

	appendStringInfo(buf, "%s%s%s",
					 odbc_quote_identifier(nspname, q_char, false),
					 name_qualifier_char,
					 odbc_quote_identifier(relname, q_char, false));
}

/*
 * Deparse conditions from the provided list and append them to buf.
 *
 * The conditions in the list are assumed to be ANDed. This function is used to
 * deparse WHERE clauses, JOIN .. ON clauses and HAVING clauses.
 *
 * Depending on the caller, the list elements might be either RestrictInfos
 * or bare clauses.
 */
static void
odbc_append_conditions(List *exprs, deparse_expr_cxt *context)
{
	int			nestlevel;
	ListCell   *lc;
	bool		is_first = true;
	StringInfo	buf = context->buf;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = odbc_set_transmission_modes();

	foreach(lc, exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);

		/* Extract clause from RestrictInfo, if required */
		if (IsA(expr, RestrictInfo))
			expr = ((RestrictInfo *) expr)->clause;

		/* Connect expressions with "AND" and parenthesize each condition. */
		if (!is_first)
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		odbc_deparse_expr(expr, context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}

	odbc_reset_transmission_modes(nestlevel);
}

/*
 * Deparse given expression into context->buf.
 *
 * This function must support all the same node types that odbc_foreign_expr_walker
 * accepts.
 *
 * Note: unlike ruleutils.c, we just use a simple hard-wired parenthesization
 * scheme: anything more complex than a Var, Const, function call or cast
 * should be self-parenthesized.
 */
static void
odbc_deparse_expr(Expr *node, deparse_expr_cxt *context)
{
	if (node == NULL)
		return;

	switch (nodeTag(node))
	{
		case T_Var:
			odbc_deparse_var((Var *) node, context);
			break;
		case T_Const:
			odbc_deparse_const((Const *) node, context);
			break;
		case T_NullIfExpr:
			odbc_deparse_nullif_expr((OpExpr *) node, context);
			break;
		case T_OpExpr:
			odbc_deparse_op_expr((OpExpr *) node, context);
			break;
		case T_BoolExpr:
			odbc_deparse_bool_expr((BoolExpr *) node, context);
			break;
		case T_NullTest:
			odbc_deparse_null_test((NullTest *) node, context);
			break;
		case T_BooleanTest:
			odbc_deparse_boolean_test((BooleanTest *) node, context);
			break;
		case T_ScalarArrayOpExpr:
			odbc_deparse_scalar_array_op_expr((ScalarArrayOpExpr *) node, context);
			break;
		case T_Aggref:
			odbc_deparse_aggref((Aggref *) node, context);
			break;
		case T_FuncExpr:
			odbc_deparse_func_expr((FuncExpr *) node, context);
			break;
		default:
			elog(ERROR, "unsupported expression type for deparse: %d",
				 (int) nodeTag(node));
			break;
	}
}

/*
 * Deparse given Var node into context->buf.
 *
 * If the Var belongs to the foreign relation, just print its remote name.
 * Otherwise, it's effectively a Param (and will in fact be a Param at
 * run time).  Handle it the same way we handle plain Params --- see
 * deparseParam for comments.
 */
static void
odbc_deparse_var(Var *node, deparse_expr_cxt *context)
{
	Relids		relids = context->scanrel->relids;

	/* Qualify columns when multiple relations are involved. */
	bool		qualify_col = (bms_membership(relids) == BMS_MULTIPLE);

	if (bms_is_member(node->varno, relids) && node->varlevelsup == 0)
		odbc_deparse_column_ref(context->buf, node->varno, node->varattno,
								planner_rt_fetch(node->varno, context->root),
								qualify_col, context);
	else
	{
		/* Does not reach here. */
		elog(ERROR, "Parameter is unsupported");
		Assert(false);
	}
}

/*
 * Construct name to use for given column, and emit it into buf.
 * If it has a column_name FDW option, use that instead of attribute name.
 *
 * If qualify_col is true, qualify column name with the alias of relation.
 */
void
odbc_deparse_column_ref(StringInfo buf, int varno, int varattno, RangeTblEntry *rte,
						bool qualify_col, deparse_expr_cxt *context)
{
	if (varattno == 0)
	{
		/* Whole row reference */
		Relation	rel;
		Bitmapset  *attrs_used;

		/* Required only to be passed down to odbc_deparse_target_list(). */
		List	   *retrieved_attrs;

		/*
		 * The lock on the relation will be held by upper callers, so it's
		 * fine to open it with no lock here.
		 */
		rel = table_open(rte->relid, NoLock);

		/*
		 * The local name of the foreign table can not be recognized by the
		 * foreign server and the table it references on foreign server might
		 * have different column ordering or different columns than those
		 * declared locally. Hence we have to deparse whole-row reference as
		 * ROW(columns referenced locally). Construct this by deparsing a
		 * "whole row" attribute.
		 */
		attrs_used = bms_add_member(NULL,
									0 - FirstLowInvalidHeapAttributeNumber);

		odbc_deparse_target_list(buf, rte, varno, rel, false, attrs_used, qualify_col,
								 &retrieved_attrs, context);

		table_close(rel, NoLock);
		bms_free(attrs_used);
	}
	else
	{
		char	   *colname = NULL;
		List	   *options;
		ListCell   *lc;

		/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
		Assert(!IS_SPECIAL_VARNO(varno));

		/*
		 * If it's a column of a foreign table, and it has the column_name FDW
		 * option, use that value.
		 */
		options = GetForeignColumnOptions(rte->relid, varattno);
		foreach(lc, options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "column") == 0)
			{
				colname = defGetString(def);
				break;
			}
		}

		/*
		 * If it's a column of a regular table or it doesn't have column_name
		 * FDW option, use attribute name.
		 */
		if (colname == NULL)
			colname = get_attname(rte->relid, varattno, false);

		if (qualify_col)
			appendStringInfo(buf, "%s%d%s", REL_ALIAS_PREFIX, varno, context->name_qualifier_char);

		appendStringInfoString(buf, odbc_quote_identifier(colname, context->q_char, false));
	}
}

/*
 * Deparse given constant value into context->buf.
 *
 * This function has to be kept in sync with ruleutils.c's get_const_expr.
 * As for that function, showtype can be -1 to never show "::typename" decoration,
 * or +1 to always show it, or 0 to show it only if the constant wouldn't be assumed
 * to be the right type by default.
 */
static void
odbc_deparse_const(Const *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;

	if (node->constisnull)
	{
		appendStringInfoString(buf, "NULL");
		return;
	}

	getTypeOutputInfo(node->consttype,
					  &typoutput, &typIsVarlena);
	extval = OidOutputFunctionCall(typoutput, node->constvalue);

	odbc_append_constant_value(buf, node->consttype, extval);

	pfree(extval);
}

/*
 * Append constant value to buffer,
 * and convert constant to common style if needed.
 */
static void
odbc_append_constant_value(StringInfo buf, Oid const_type, char *extval)
{
	switch (const_type)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			{
				/*
				 * No need to quote unless it's a special value such as 'NaN'.
				 * See comments in get_const_expr().
				 */
				if (strspn(extval, "0123456789+-eE.") == strlen(extval))
				{
					if (extval[0] == '+' || extval[0] == '-')
						appendStringInfo(buf, "(%s)", extval);
					else
						appendStringInfoString(buf, extval);
				}
				else
					appendStringInfo(buf, "'%s'", extval);
			}
			break;
		case BITOID:
		case VARBITOID:
			appendStringInfo(buf, "B'%s'", extval);
			break;
		case BOOLOID:
			if (strcmp(extval, "t") == 0)
				appendStringInfoString(buf, "true");
			else
				appendStringInfoString(buf, "false");
			break;
		default:
			odbc_deparse_string_literal(buf, extval);
			break;
	}
}

static void
odbc_deparse_nullif_expr(NullIfExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	appendStringInfoString(buf, "nullif(");
	odbc_deparse_expr(linitial(node->args), context);
	appendStringInfoString(buf, ", ");
	odbc_deparse_expr(llast(node->args), context);
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse given operator expression.   To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
odbc_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Form_pg_operator form;
	char		oprkind;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
	Assert((oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/* Deparse left operand, if any. */
	if (oprkind == 'b')
	{
		odbc_deparse_expr(linitial(node->args), context);
		appendStringInfoChar(buf, ' ');
	}

	/* Deparse operator name. */
	odbc_deparse_operator_name(buf, form);

	/* Deparse right operand. */
	appendStringInfoChar(buf, ' ');
	odbc_deparse_expr(llast(node->args), context);

	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
}

/*
 * Deparse a BoolExpr node.
 */
static void
odbc_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	const char *op = NULL;		/* keep compiler quiet */
	bool		first;
	ListCell   *lc;

	switch (node->boolop)
	{
		case AND_EXPR:
			op = "AND";
			break;
		case OR_EXPR:
			op = "OR";
			break;
		case NOT_EXPR:
			appendStringInfoString(buf, "(NOT ");
			odbc_deparse_expr(linitial(node->args), context);
			appendStringInfoChar(buf, ')');
			return;
	}

	appendStringInfoChar(buf, '(');
	first = true;
	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfo(buf, " %s ", op);
		odbc_deparse_expr((Expr *) lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse IS [NOT] NULL expression.
 */
static void
odbc_deparse_null_test(NullTest *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfoChar(buf, '(');
	odbc_deparse_expr(node->arg, context);

	if (node->nulltesttype == IS_NULL)
		appendStringInfoString(buf, " IS NULL)");
	else
		appendStringInfoString(buf, " IS NOT NULL)");

}

/*
 * Deparse IS [NOT] TRUE/FALSE expression.
 */
static void
odbc_deparse_boolean_test(BooleanTest *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfoChar(buf, '(');
	odbc_deparse_expr(node->arg, context);

	if (node->booltesttype == IS_TRUE)
		appendStringInfoString(buf, " IS TRUE)");
	else if (node->booltesttype == IS_NOT_TRUE)
		appendStringInfoString(buf, " IS NOT TRUE)");
	else if (node->booltesttype == IS_FALSE)
		appendStringInfoString(buf, " IS FALSE)");
	else
		appendStringInfoString(buf, " IS NOT FALSE)");

}

/*
 * Print the name of an operator.
 */
static void
odbc_deparse_operator_name(StringInfo buf, Form_pg_operator opform)
{
	char	   *opname = NameStr(opform->oprname);

	/* Just print operator name. */
	if (strcmp(opname, "~~") == 0)
		appendStringInfoString(buf, "LIKE");
	else if (strcmp(opname, "!~~") == 0)
		appendStringInfoString(buf, "NOT LIKE");
	else
		appendStringInfoString(buf, opname);

}

/*
 * Append a SQL string literal representing "val" to buf.
 */
static void
odbc_deparse_string_literal(StringInfo buf, const char *val)
{
	const char *valptr;

	appendStringInfoChar(buf, '\'');

	for (valptr = val; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}
	appendStringInfoChar(buf, '\'');
}

/*
 * Deparse an Aggref node.
 */
static void
odbc_deparse_aggref(Aggref *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	odbc_deparse_function_name(node->aggfnoid, context);
	appendStringInfoChar(buf, '(');

	/* Add DISTINCT */
	appendStringInfo(buf, "%s", (node->aggdistinct != NIL) ? "DISTINCT " : "");

	/* aggstar can be set only in zero-argument aggregates */
	if (node->aggstar)
		appendStringInfoChar(buf, '*');
	else
	{
		ListCell   *arg;
		bool		first = true;

		/* Add all the arguments */
		foreach(arg, node->args)
		{
			TargetEntry *tle = (TargetEntry *) lfirst(arg);
			Node	   *n = (Node *) tle->expr;

			if (tle->resjunk)
				continue;

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			odbc_deparse_expr((Expr *) n, context);
		}
	}

	/* Does not support ORDER BY inside Aggregate */
	Assert(!node->aggorder);

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse function position()
 */
static void
odbc_deparse_func_expr_position(FuncExpr *node, deparse_expr_cxt *context, StringInfo buf, char *proname)
{
	Expr	   *arg1;
	Expr	   *arg2;

	/* Append the function name */
	appendStringInfo(buf, "%s(", proname);

	/*
	 * POSITION function has only two arguments. When deparsing, the range of
	 * these argument will be changed, the first argument will be in last so
	 * it will be get first, After that, the last argument will be get later.
	 */
	Assert(list_length(node->args) == 2);

	/* Get the first argument */
	arg1 = lsecond(node->args);
	odbc_deparse_expr(arg1, context);
	appendStringInfo(buf, " IN ");
	/* Get the last argument */
	arg2 = linitial(node->args);
	odbc_deparse_expr(arg2, context);

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse a function call.
 */
static void
odbc_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first;
	ListCell   *arg;
	char	   *function_name;

	/*
	 * If the function call came from an implicit coercion, then just show the
	 * first argument.
	 */
	if (node->funcformat == COERCE_IMPLICIT_CAST)
	{
		odbc_deparse_expr((Expr *) linitial(node->args), context);
		return;
	}

	function_name = get_func_name(node->funcid);

	/*
	 * If the function call came from a cast, it will deparse to CAST(... AS ...)
	 */
	if (node->funcformat == COERCE_EXPLICIT_CAST)
	{
		Oid			rettype = node->funcresulttype;
		int32		coercedTypmod;

		/* Get the typmod if this is a length-coercion function */
		(void) exprIsLengthCoercion((Node *) node, &coercedTypmod);
		appendStringInfoString(buf, "CAST(");
		odbc_deparse_expr((Expr *) linitial(node->args), context);
		appendStringInfo(buf, " AS %s)",
						 odbc_deparse_cast_function(function_name, rettype, coercedTypmod));
		return;
	}

	if (strcmp(function_name, "position") == 0)
	{
		odbc_deparse_func_expr_position(node, context, buf, function_name);
		return;
	}

	/*
	 * For the other function: display as function_name(args1, arg2, ...).
	 */
	appendStringInfo(buf, "%s(", function_name);

	/* ... and all the arguments */
	first = true;
	foreach(arg, node->args)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		odbc_deparse_expr((Expr *) lfirst(arg), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Add typmod decoration to the basic type name
 */
static char *
odbc_print_typmod(char *typname, int32 typmod, Oid typmodout)
{
	char	   *res;

	/* Shouldn't be called if typmod is -1 */
	Assert(typmod >= 0);

	if (typmodout == InvalidOid)
	{
		/* Default behavior: just print the integer typmod with parens */
		res = psprintf("%s(%d)", typname, (int) typmod);
	}
	else
	{
		/* Use the type-specific typmodout procedure */
		char	   *tmstr;

		tmstr = DatumGetCString(OidFunctionCall1(typmodout,
												 Int32GetDatum(typmod)));
		res = psprintf("%s%s", typname, tmstr);
	}

	return res;
}

static char *
odbc_format_type_extended(char *function_name, Oid type_oid, int32 typemod)
{
	char	   *buf;

	if (strcmp(function_name, "float4") == 0)
		buf = pstrdup("real");
	else
		buf = function_name;

	/* print type modifier */
	if (typemod >= 0)
	{
		HeapTuple	tuple;
		Form_pg_type typeform;

		tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(type_oid));
		if (!HeapTupleIsValid(tuple))
		{
			elog(ERROR, "cache lookup failed for type %u", type_oid);
		}
		typeform = (Form_pg_type) GETSTRUCT(tuple);

		buf = odbc_print_typmod(buf, typemod, typeform->typmodout);
		ReleaseSysCache(tuple);
	}

	return buf;
}

/*
 * Convert type OID + typmod info into a type name we can ship to the remote
 * server.  Someplace else had better have verified that this type name is
 * expected to be known on the remote end.
 *
 * This is almost just format_type_with_typemod(), except that if left to its
 * own devices, that function will make schema-qualification decisions based
 * on the local search_path, which is wrong.  We must schema-qualify all
 * type names that are not in pg_catalog.  We assume here that built-in types
 * are all in pg_catalog and need not be qualified; otherwise, qualify.
 */
static char *
odbc_deparse_cast_function(char *function_name, Oid type_oid, int32 typemod)
{
	return odbc_format_type_extended(function_name, type_oid, typemod);
}

/*
 * Deparse given ScalarArrayOpExpr expression.  To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
odbc_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Expr	   *arg1;
	Expr	   *arg2;
	Form_pg_operator form;
	char	   *opname = NULL;
	bool		useIn = false;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	opname = pstrdup(NameStr(form->oprname));
	ReleaseSysCache(tuple);

	/* Using IN clause for '= ANY' and NOT IN clause for '<> ALL' */
	if ((strcmp(opname, "=") == 0 && node->useOr == true) ||
		(strcmp(opname, "<>") == 0 && node->useOr == false))
		useIn = true;

	/* Get left and right argument for deparsing */
	arg1 = linitial(node->args);
	arg2 = lsecond(node->args);

	if (useIn)
	{
		/* Deparse left operand. */
		odbc_deparse_expr(arg1, context);
		appendStringInfoChar(buf, ' ');

		/* Add IN clause */
		if (strcmp(opname, "<>") == 0)
		{
			appendStringInfoString(buf, "NOT IN (");
		}
		else if (strcmp(opname, "=") == 0)
		{
			appendStringInfoString(buf, "IN (");
		}
	}

	arg2 = (Expr *) lsecond(node->args);
	switch (nodeTag((Node *) arg2))
	{
		case T_Const:
			{
				Const	   *c = (Const *) arg2;
				char	   *extval;
				int			num_elems = 0;
				Datum	   *elem_values;
				bool	   *elem_nulls;
				Oid			elmtype;
				int			i;
				Oid			outputFunctionId;
				bool		typeVarLength;

				if (c->constisnull)
				{
					appendStringInfoString(buf, " NULL");
					return;
				}

				odbc_deconstruct_constant_array(c, &elem_nulls, &elem_values, &elmtype, &num_elems);
				getTypeOutputInfo(elmtype, &outputFunctionId, &typeVarLength);

				for (i = 0; i < num_elems; i++)
				{
					if (i > 0)
					{
						if (useIn)
							appendStringInfoString(buf, ", ");
						else
						{
							if (node->useOr)
								appendStringInfoString(buf, " OR ");
							else
								appendStringInfoString(buf, " AND ");
						}
					}

					if (!useIn)
					{
						/* Deparse left argument */
						appendStringInfoChar(buf, '(');
						odbc_deparse_expr(arg1, context);

						appendStringInfo(buf, " %s ", opname);
					}

					if (elem_nulls[i] == true)
					{
						appendStringInfoString(buf, "NULL");
						continue;
					}

					extval = OidOutputFunctionCall(outputFunctionId, elem_values[i]);
					odbc_append_constant_value(buf, elmtype, extval);

					if (!useIn)
						appendStringInfoChar(buf, ')');
					pfree(extval);
				}

				pfree(elem_values);
				pfree(elem_nulls);
			}
			break;
		case T_ArrayExpr:
			{
				bool		first = true;
				ListCell   *lc;

				foreach(lc, ((ArrayExpr *) arg2)->elements)
				{
					if (!first)
					{
						if (useIn)
						{
							appendStringInfoString(buf, ", ");
						}
						else
						{
							if (node->useOr)
								appendStringInfoString(buf, " OR ");
							else
								appendStringInfoString(buf, " AND ");
						}
					}

					if (useIn)
					{
						odbc_deparse_expr(lfirst(lc), context);
					}
					else
					{
						/* Deparse left argument */
						appendStringInfoChar(buf, '(');
						odbc_deparse_expr(arg1, context);

						appendStringInfo(buf, " %s ", opname);

						/*
						 * Deparse each element in right argument
						 */
						odbc_deparse_expr(lfirst(lc), context);
						appendStringInfoChar(buf, ')');
					}
					first = false;
				}
				break;
			}
		default:
			elog(ERROR, "unsupported expression type for deparse: %d", (int) nodeTag(node));
			break;
	}

	/* Close IN clause */
	if (useIn)
		appendStringInfoChar(buf, ')');
}

/*
 * odbc_deparse_function_name
 *		Deparses function name from given function oid.
 */
static void
odbc_deparse_function_name(Oid funcid, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Always print the function name */
	proname = NameStr(procform->proname);
	appendStringInfoString(buf, proname);

	ReleaseSysCache(proctup);
}

/*
 * odbc_quote_identifier - Quote an identifier only if needed
 *
 * When quotes are needed, we palloc the required space; slightly
 * space-wasteful but well worth it for notational simplicity.
 * refer: PostgreSQL 13.0 src/backend/utils/adt/ruleutils.c L10730
 */
const char *
odbc_quote_identifier(const char *ident, char *q_char, bool quote_all_identifiers)
{
	/*
	 * Can avoid quoting if ident starts with a lowercase letter or underscore
	 * and contains only lowercase letters, digits, and underscores, *and* is
	 * not any SQL keyword.  Otherwise, supply quotes.
	 */
	int			nquotes = 0;
	bool		safe;
	const char *ptr;
	char	   *result;
	char	   *optr;

	if (q_char == NULL)
		return ident;

	/*
	 * Verify q_char get from remote server
	 */
	if (strlen(q_char) == 1)
	{
		/* q_char is a char value */
		if (strcmp(q_char, " ") == 0)
		{
			/* remote server not support identifier quote string */
			return ident;		/* no change needed */
		}
	}
	else
	{
		/*
		 * q_char is a string value. Currently, we do not handle this case.
		 */
		elog(ERROR, "odbc_fdw: Not support quote string \"%s\".", q_char);
	}

	/*
	 * would like to use <ctype.h> macros here, but they might yield unwanted
	 * locale-specific results...
	 */
	safe = ((ident[0] >= 'a' && ident[0] <= 'z') || ident[0] == '_');

	for (ptr = ident; *ptr; ptr++)
	{
		char		ch = *ptr;

		if ((ch >= 'a' && ch <= 'z') ||
			(ch >= '0' && ch <= '9') ||
			(ch == '_'))
		{
			/* okay */
		}
		else
		{
			safe = false;
			if (ch == *q_char)
				nquotes++;
		}
	}

	if (quote_all_identifiers)
		safe = false;

	if (safe)
	{
		/*
		 * Check for keyword.  We quote keywords except for unreserved ones.
		 * (In some cases we could avoid quoting a col_name or type_func_name
		 * keyword, but it seems much harder than it's worth to tell that.)
		 *
		 * Note: ScanKeywordLookup() does case-insensitive comparison, but
		 * that's fine, since we already know we have all-lower-case.
		 */
		int			kwnum = ScanKeywordLookup(ident, &ScanKeywords);

		if (kwnum >= 0 && ScanKeywordCategories[kwnum] != UNRESERVED_KEYWORD)
			safe = false;
	}

	if (safe)
		return ident;			/* no change needed */

	/* -----
	 * Create new ident:
	 * - Enclose by q_char arg
	 * - Add escape for quotes char
	 *
	 * Note:
	 * - nquote: number of quote char need to escape
	 * - 2: number of outer quote.
	 * - 1: null terminator.
	 * -----
	 */
	result = (char *) palloc0(strlen(ident) + nquotes + 2 + 1);

	optr = result;
	*optr++ = *q_char;
	for (ptr = ident; *ptr; ptr++)
	{
		char		ch = *ptr;

		if (ch == *q_char)
			*optr++ = *q_char;
		*optr++ = ch;
	}
	*optr++ = *q_char;
	*optr = '\0';

	return result;
}

/*
 * Build the targetlist for given relation to be deparsed as SELECT clause.
 *
 * The output targetlist contains the columns that need to be fetched from the
 * foreign server for the given relation.  If foreignrel is an upper relation,
 * then the output targetlist can also contain expressions to be evaluated on
 * foreign server.
 */
List *
odbc_build_tlist_to_deparse(RelOptInfo *foreignrel)
{
	List	   *tlist = NIL;
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) foreignrel->fdw_private;
	ListCell   *lc;

	/*
	 * For an upper relation, we have already built the target list while
	 * checking shippability, so just return that.
	 */
	if (IS_UPPER_REL(foreignrel))
		return fpinfo->grouped_tlist;

	/*
	 * We require columns specified in foreignrel->reltarget->exprs and those
	 * required for evaluating the local conditions.
	 */
	tlist = add_to_flat_tlist(tlist,
							  pull_var_clause((Node *) foreignrel->reltarget->exprs,
											  PVC_RECURSE_PLACEHOLDERS));
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		tlist = add_to_flat_tlist(tlist,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_RECURSE_PLACEHOLDERS));
	}

	return tlist;
}

/*
 * Return true if str existed in list string
 */
static bool
odbc_is_str_exist_in_list(char *str, const char **list)
{
	int			i;

	if (list == NULL ||			/* NULL list */
		list[0] == NULL ||		/* List length = 0 */
		str == NULL)			/* Input function name = NULL */
		return false;

	for (i = 0; list[i]; i++)
	{
		if (strcmp(str, list[i]) == 0)
			return true;
	}
	return false;
}

/*
 * Deconstruct constant array to C array.
 */
static void
odbc_deconstruct_constant_array(Const *node, bool **elem_nulls, Datum **elem_values, Oid *elmtype, int *num_elems)
{
	ArrayType  *array;
	int16		elmlen;
	bool		elmbyval;
	char		elmalign;

	array = DatumGetArrayTypeP(node->constvalue);
	*elmtype = ARR_ELEMTYPE(array);

	get_typlenbyvalalign(*elmtype, &elmlen, &elmbyval, &elmalign);
	deconstruct_array(array, *elmtype, elmlen, elmbyval, elmalign,
					  elem_values, elem_nulls, num_elems);
}

/*
 * Return true if the type has fully supported by odbc_fdw
 * this type refer from the Map ODBC data types to PostgreSQL: sql_data_type()
 */
static bool
odbc_is_supported_type(Oid type)
{
	switch (type)
	{
		/* SQL_CHAR, SQL_WCHAR */
		case CHAROID:
		case BPCHAROID:
		/* SQL_VARCHAR, SQL_WVARCHAR */
		case VARCHAROID:
		/* SQL_LONGVARCHAR, SQL_WLONGVARCHAR */
		case TEXTOID:
		/* SQL_DECIMAL, SQL_NUMERIC */
		case NUMERICOID:
		/* SQL_SMALLINT, SQL_TINYINT */
		case INT2OID:
		/* SQL_INTEGER */
		case INT4OID:
		/* SQL_BIGINT */
		case INT8OID:
		/* SQL_REAL, SQL_FLOAT */
		case FLOAT4OID:
		/* SQL_DOUBLE */
		case FLOAT8OID:
		/* SQL_BIT */
		case BOOLOID:
		/* SQL_TIME,  SQL_TYPE_TIME*/
		case TIMEOID:
		/* SQL_TIMESTAMP, SQL_TYPE_TIMESTAMP */
		case TIMESTAMPOID:
		/* SQL_DATE, SQL_TYPE_DATE */
		case DATEOID:
		/* SQL_GUID */
		case UUIDOID:
			return true;
		default:
			return false;
	}
}

/*
 * Return true if function is common function can pushdown to Odbc
 */
static bool
odbc_is_supported_builtin_func(Oid funcid, char *in)
{
	if (!odbc_is_builtin(funcid) ||
		!odbc_is_str_exist_in_list(in, OdbcCommonFunctions))
		return false;

	return true;
}
