/*----------------------------------------------------------
 *
 *        foreign-data wrapper for ODBC
 *
 * Copyright (c) 2021, TOSHIBA CORPORATION
 * Copyright (c) 2011, PostgreSQL Global Development Group
 *
 * This software is released under the PostgreSQL Licence.
 *
 * Author: Zheng Yang <zhengyang4k@gmail.com>
 * Updated to 9.2+ by Gunnar "Nick" Bluth <nick@pro-open.de>
 *   based on tds_fdw code from Geoff Montee
 * Version 0.6 or higher
 *   by Takuya Koda <takuya.koda@toshiba.co.jp>
 *
 * IDENTIFICATION
 *      odbc_fdw/odbc_fdw.c
 *
 *----------------------------------------------------------
 */

/* Debug mode flag */
/* #define DEBUG */

#include "postgres.h"
#include <string.h>

#include "odbc_fdw.h"

#include "funcapi.h"
#include "access/reloptions.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "commands/explain.h"
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#if ((PG_VERSION_NUM >= 130010 && PG_VERSION_NUM < 140000) || \
	 (PG_VERSION_NUM >= 140007 && PG_VERSION_NUM < 150000) || \
	  PG_VERSION_NUM >= 150002)
#include "optimizer/inherit.h"
#endif
#include "utils/memutils.h"
#include "utils/builtins.h"
#include "utils/relcache.h"
#include "utils/syscache.h"
#include "storage/lock.h"
#include "miscadmin.h"
#include "mb/pg_wchar.h"
#include "optimizer/cost.h"
#include "storage/fd.h"
#include "utils/array.h"
#include "utils/builtins.h"
#include "utils/rel.h"
#if PG_VERSION_NUM >= 160000
#include "utils/varlena.h"
#endif
#include "nodes/nodes.h"
#include "nodes/makefuncs.h"
#include "nodes/pg_list.h"

#include "optimizer/appendinfo.h"
#include "optimizer/optimizer.h"
#include "optimizer/pathnode.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/planmain.h"
#include "optimizer/tlist.h"

#include "access/tupdesc.h"

#if PG_VERSION_NUM < 120000
#include "access/heapam.h"
#define table_open heap_open
#define table_close heap_close
#else
#include "access/table.h"
#endif

#if defined(_WIN32)
#define strcasecmp _stricmp
#endif

/* TupleDescAttr was backported into 9.5.9 and 9.6.5 but we support any 9.5.X */
#ifndef TupleDescAttr
#define TupleDescAttr(tupdesc, i) ((tupdesc)->attrs[(i)])
#endif

#include "executor/spi.h"

#include <stdio.h>
#include <sql.h>
#include <sqlext.h>

// for INSERT/UPDATE/DELETE
#include "parser/parsetree.h"
#include "utils/lsyscache.h"
#include "utils/float.h"
#include "utils/guc.h"
#include "utils/date.h"
#include "utils/datetime.h"

#if (PG_VERSION_NUM < 140000)
/* source-code-compatibility hacks for pull_varnos() API change */
#define make_restrictinfo(a,b,c,d,e,f,g,h,i) make_restrictinfo_new(a,b,c,d,e,f,g,h,i)
#endif

PG_MODULE_MAGIC;

/* Macro to make conditional DEBUG more terse */
#ifdef DEBUG
#define elog_debug(...) elog(DEBUG1, __VA_ARGS__)
#else
#define elog_debug(...) ((void) 0)
#endif

#define PROCID_TEXTEQ 67
#define PROCID_TEXTCONST 25

/* Provisional limit to name lengths in characters */
#define MAXIMUM_CATALOG_NAME_LEN 255
#define MAXIMUM_SCHEMA_NAME_LEN 255
#define MAXIMUM_TABLE_NAME_LEN 255
#define MAXIMUM_COLUMN_NAME_LEN 255

/* Maximum GetData buffer size */
#define MAXIMUM_BUFFER_SIZE 8192

/*
 * Numbers of the columns returned by SQLTables:
 * 1: TABLE_CAT (ODBC 3.0) TABLE_QUALIFIER (ODBC 2.0) -- database name
 * 2: TABLE_SCHEM (ODBC 3.0) TABLE_OWNER (ODBC 2.0)   -- schema name
 * 3: TABLE_NAME
 * 4: TABLE_TYPE
 * 5: REMARKS
 */
#define SQLTABLES_SCHEMA_COLUMN 2
#define SQLTABLES_NAME_COLUMN 3

#define ODBC_SQLSTATE_FRACTIONAL_TRUNCATION "01S07"
#define ODBC_SQLSTATE_STRING_TRUNCATION "01004"
#define ODBC_SQLSTATE_BQ_TRUNCATION "01000"
#define ODBC_SQLSTATE_LENGTH 5
typedef enum { NO_TRUNCATION, FRACTIONAL_TRUNCATION, STRING_TRUNCATION } GetDataTruncation;

#define IS_KEY_COLUMN(A)	((strcmp(A->defname, "key") == 0) && \
							 (strcmp(strVal(A->arg), "true") == 0))

/*
 * Similarly, this enum describes what's kept in the fdw_private list for
 * a ModifyTable node referencing a odbc_fdw foreign table.  We store:
 *
 * 1) INSERT/UPDATE/DELETE statement text to be sent to the remote server
 * 2) Integer list of target attribute numbers for INSERT/UPDATE
 *	  (NIL for a DELETE)
 * 3) Oid list of target type for INSERT/UPDATE
 * 4) Boolean flag showing if the remote query has a RETURNING clause
 * 5) Integer list of attribute numbers retrieved by RETURNING, if any
 */
enum OdbcFdwModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	OdbcFdwModifyPrivateUpdateSql,
	/* Integer list of target attribute numbers for INSERT/UPDATE */
	OdbcFdwModifyPrivateTargetAttnums,
};

/*
 * Indexes of FDW-private information stored in fdw_private lists.
 *
 * These items are indexed with the enum FdwScanPrivateIndex, so an item
 * can be fetched with list_nth().  For example, to get the SELECT statement:
 *		sql = strVal(list_nth(fdw_private, FdwScanPrivateSelectSql));
 */
enum FdwScanPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwScanPrivateSelectSql,
	/* Integer list of attribute numbers retrieved by the SELECT */
	FdwScanPrivateRetrievedAttrs
};

typedef struct odbcFdwOptions
{
	char  *schema;     /* Foreign schema name */
	char  *table;      /* Foreign table */
	char  *prefix;     /* Prefix for imported foreign table names */
	char  *sql_query;  /* SQL query (overrides table) */
	char  *sql_count;  /* SQL query for counting results */
	char  *encoding;   /* Character encoding name */

	List *connection_list; /* ODBC connection attributes */
} odbcFdwOptions;

typedef struct odbcFdwScanState
{
	AttInMetadata   *attinmeta;
	odbcFdwOptions  options;
	SQLHENV         env;
	SQLHDBC         dbc;
	SQLHSTMT        stmt;
	char            *query;
	bool            query_executed;
	List		   *retrieved_attrs;	/* list of target attribute numbers */
	StringInfoData  *table_columns;
	bool            first_iteration;
	List            *col_size_array;
	List            *col_conversion_array;
	char            *sql_count;
	int             encoding;
} odbcFdwScanState;

typedef struct odbcFdwModifyState
{
	odbcFdwOptions  options;
	SQLHENV         env;
	SQLHDBC         dbc;
	SQLHSTMT        stmt;
	char            *query;
	List  	        *target_attrs;

	/* info about parameters for prepared statement */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
	AttrNumber *junk_idx;
} odbcFdwModifyState;

struct odbcFdwOption
{
	const char   *optname;
	Oid     optcontext; /* Oid of catalog in which option may appear */
};

/*
 * Array of valid options
 * In addition to this, any option with a name prefixed
 * by odbc_ is accepted as an ODBC connection attribute
 * and can be defined in foreign servier, user mapping or
 * table statements.
 * Note that dsn and driver can be defined by
 * prefixed or non-prefixed options.
 */
static struct odbcFdwOption valid_options[] =
{
	/* Foreign server options */
	{ "odbc_driver",     ForeignServerRelationId },
	{ "odbc_server",     ForeignServerRelationId },
	{ "odbc_port",     ForeignServerRelationId },
	{ "odbc_database",     ForeignServerRelationId },

	/* Foreign table options */
	{ "schema",     ForeignTableRelationId },
	{ "table",      ForeignTableRelationId },
	{ "prefix",     ForeignTableRelationId },
	{ "sql_query",  ForeignTableRelationId },
	{ "sql_count",  ForeignTableRelationId },

	{ "column", AttributeRelationId },
	{ "key", AttributeRelationId },

	/* updatable is available on both server and table */
	{"updatable", ForeignServerRelationId},
	{"updatable", ForeignTableRelationId},

	/* user mapping*/
	{"odbc_uid", UserMappingRelationId},
	{"odbc_pwd", UserMappingRelationId},

	/* Sentinel */
	{ NULL,       InvalidOid}
};

typedef enum { TEXT_CONVERSION, BIN_CONVERSION, BOOL_CONVERSION } ColumnConversion;

static GetDataTruncation
result_truncation(SQLRETURN ret, SQLHSTMT stmt)
{
	SQLCHAR sqlstate[ODBC_SQLSTATE_LENGTH + 1];
	GetDataTruncation truncation = NO_TRUNCATION;
	if (ret == SQL_SUCCESS_WITH_INFO)
	{
		SQLGetDiagRec(SQL_HANDLE_STMT, stmt, 1, sqlstate, NULL, NULL, 0, NULL);
		if (strncmp((char*)sqlstate, ODBC_SQLSTATE_STRING_TRUNCATION, ODBC_SQLSTATE_LENGTH) == 0 || strncmp((char*)sqlstate, ODBC_SQLSTATE_BQ_TRUNCATION, ODBC_SQLSTATE_LENGTH) == 0)
		{
			truncation = STRING_TRUNCATION;
		}
		else if (strncmp((char*)sqlstate, ODBC_SQLSTATE_FRACTIONAL_TRUNCATION, ODBC_SQLSTATE_LENGTH) == 0)
		{
			truncation = FRACTIONAL_TRUNCATION;
		}
	}
	return truncation;
}

static void
resize_buffer(char ** buffer, int *size, int used_size, int required_size)
{
	if (required_size > *size)
	{
		int new_size = required_size; // TODO: use min increment size, maybe in relation to current size
		char * new_buffer = (char *) palloc0(new_size);
		// TODO: out of memory error if !new_buffer
		if (used_size > 0)
		{
			memmove(new_buffer, *buffer, used_size);
			pfree(*buffer);
		}
		*buffer = new_buffer;
		*size = new_size;
	}
}

static const char * HEX_DIGITS = "0123456789ABCDEF";

static char * binary_to_hex(char * buffer, int buffer_size)
{
	int i;
	int hex_size = buffer_size*2;
	char * hex = (char *) palloc0(hex_size + 1);
	hex[hex_size] = 0;
	for (i=0; i<buffer_size; i++)
	{
		unsigned char byte = buffer[i];
		hex[i*2] = HEX_DIGITS[(byte >> 4)];
		hex[i*2+1] = HEX_DIGITS[(byte & 0xF)];
	}
	return hex;
}

/*
 * SQL functions
 */
PGDLLEXPORT Datum odbc_fdw_handler(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum odbc_fdw_validator(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum odbc_tables_list(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum odbc_table_size(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum odbc_query_size(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(odbc_fdw_handler);
PG_FUNCTION_INFO_V1(odbc_fdw_validator);
PG_FUNCTION_INFO_V1(odbc_tables_list);
PG_FUNCTION_INFO_V1(odbc_table_size);
PG_FUNCTION_INFO_V1(odbc_query_size);

/*
 * FDW callback routines
 */
static void odbcExplainForeignScan(ForeignScanState *node, ExplainState *es);
static void odbcBeginForeignScan(ForeignScanState *node, int eflags);
static TupleTableSlot *odbcIterateForeignScan(ForeignScanState *node);
static void odbcReScanForeignScan(ForeignScanState *node);
static void odbcEndForeignScan(ForeignScanState *node);
static void odbcGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid);
static void odbcEstimateCosts(PlannerInfo *root, RelOptInfo *baserel, Cost *startup_cost, Cost *total_cost, Oid foreigntableid);
static void odbcGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid);
static bool odbcAnalyzeForeignTable(Relation relation, AcquireSampleRowsFunc *func, BlockNumber *totalpages);
static ForeignScan* odbcGetForeignPlan(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid, ForeignPath *best_path, List *tlist, List *scan_clauses, Plan *outer_plan);
List* odbcImportForeignSchema(ImportForeignSchemaStmt *stmt, Oid serverOid);
static List *odbcPlanForeignModify(PlannerInfo *root, ModifyTable *plan, Index resultRelation, int subplan_index);
static void odbcBeginForeignModify(ModifyTableState *mtstate, ResultRelInfo *resultRelInfo, List *fdw_private, int subplan_index, int eflags);
static void odbcEndForeignModify(EState *estate, ResultRelInfo *resultRelInfo);
static TupleTableSlot *odbcExecForeignInsert(EState *estate, ResultRelInfo *resultRelInfo, TupleTableSlot *slot, TupleTableSlot *planSlot);
#if (PG_VERSION_NUM < 140000)
static void odbcAddForeignUpdateTargets(Query *parsetree, RangeTblEntry *target_rte, Relation target_relation);
#else
static void odbcAddForeignUpdateTargets(PlannerInfo *root, Index rtindex, RangeTblEntry *target_rte, Relation target_relation);
#endif
static TupleTableSlot *odbcExecForeignUpdate(EState *estate, ResultRelInfo *resultRelInfo, TupleTableSlot *slot, TupleTableSlot *planSlot);
static TupleTableSlot *odbcExecForeignDelete(EState *estate, ResultRelInfo *resultRelInfo, TupleTableSlot *slot, TupleTableSlot *planSlot);
static int	odbcIsForeignRelUpdatable(Relation rel);
static void odbcExplainForeignModify(ModifyTableState *mtstate, ResultRelInfo *rinfo, List *fdw_private, int subplan_index, ExplainState *es);
static void odbcBeginForeignInsert(ModifyTableState *mtstate, ResultRelInfo *resultRelInfo);
static void odbcEndForeignInsert(EState *estate, ResultRelInfo *resultRelInfo);
static void odbcGetForeignUpperPaths(PlannerInfo *root,
									  UpperRelationKind stage,
									  RelOptInfo *input_rel,
									  RelOptInfo *output_rel,
									  void *extra);

/*
 * helper functions
 */
static bool odbcIsValidOption(const char *option, Oid context);
static void check_return(SQLRETURN ret, char *msg, SQLHANDLE handle, SQLSMALLINT type);
static const char* empty_string_if_null(char *string);
static void extract_odbcFdwOptions(List *options_list, odbcFdwOptions *extracted_options);
static void init_odbcFdwOptions(odbcFdwOptions* options);
static void copy_odbcFdwOptions(odbcFdwOptions* to, odbcFdwOptions* from);
static void odbc_connection(odbcFdwOptions* options, SQLHENV *env, SQLHDBC *dbc);
static void odbc_disconnection(SQLHENV *env, SQLHDBC *dbc);
static void sql_data_type(SQLSMALLINT odbc_data_type, SQLULEN column_size, SQLSMALLINT decimal_digits, SQLSMALLINT nullable, StringInfo sql_type);
static void odbcGetOptions(Oid server_oid, List *add_options, odbcFdwOptions *extracted_options, Oid userid);
static void odbcGetTableOptions(Oid foreigntableid, odbcFdwOptions *extracted_options, Oid userid);
static void odbcGetTableInfo(odbcFdwOptions* options, unsigned int *size, char **quote_char_out, char **name_qualifier_char_out);
static void check_return(SQLRETURN ret, char *msg, SQLHANDLE handle, SQLSMALLINT type);
static void odbcConnStr(StringInfoData *conn_str, odbcFdwOptions* options);
static char* get_schema_name(odbcFdwOptions *options);
static inline bool is_blank_string(const char *s);
static Oid oid_from_server_name(char *serverName);
static odbcFdwModifyState *create_foreign_modify(EState *estate, ResultRelInfo *resultRelInfo, CmdType operation, Plan *subplan, char *query, List *target_attrs);
static void finish_foreign_modify(odbcFdwModifyState *fmstate);
static TupleTableSlot *execute_foreign_modify(EState *estate, ResultRelInfo *resultRelInfo, CmdType operation, TupleTableSlot *slot, TupleTableSlot *planSlot);
static void bind_stmt_params(odbcFdwModifyState *fmstate, TupleTableSlot *slot);
static void bind_stmt_param(odbcFdwModifyState *fmstate, Oid type, int attnum, Datum value);
static void bindJunkColumnValue(odbcFdwModifyState *fmstate, TupleTableSlot *slot, TupleTableSlot *planSlot, Oid foreignTableId, int bindnum);
static void release_odbc_resources(odbcFdwModifyState *fmstate);
static SQLRETURN validate_retrieved_string(SQLHSTMT stmt, SQLUSMALLINT ColumnNumber, const char *string_value, bool *is_mapped, bool *is_empty_retrieved_string);
static void odbc_get_column_info(SQLHSTMT *stmt, ForeignScanState *node, odbcFdwScanState *festate);
static char* odbc_get_attr_value(odbcFdwScanState *festate, int attid, Oid pgtype, SQLLEN *result_size, ColumnConversion conversion);
static Datum odbc_convert_to_pg(Oid pgtyp, int pgtypmod, char* value, int size, ColumnConversion conversion);
static void odbc_make_tuple_from_result_row(SQLHSTMT * stmt,
											TupleDesc tupleDescriptor,
											List *retrieved_attrs,
											Datum *row,
											bool *is_null,
											odbcFdwScanState * festate);
static void odbc_add_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
											RelOptInfo *grouped_rel, GroupPathExtraData *extra);

#define REL_ALIAS_PREFIX	"r"
/* Handy macro to add relation name qualification */
#define ADD_REL_QUALIFIER(buf, varno)	\
		appendStringInfo((buf), "%s%d.", REL_ALIAS_PREFIX, (varno))
static void deparseInsertSql(StringInfo buf, RangeTblEntry *rte, Index rtindex, Relation rel, List *targetAttrs, bool doNothing, List *withCheckOptionList, char *name_qualifier_char, char *quote_char);
static void deparseUpdateSql(StringInfo buf, RangeTblEntry *rte, Index rtindex, Relation rel, List *attname, List *targetAttrs, List *withCheckOptionList, char *name_qualifier_char, char *quote_char);
static void deparseDeleteSql(StringInfo buf, RangeTblEntry *rte, Index rtindex, Relation rel, List *name, char *name_qualifier_char, char *quote_char);

/*
 * Check if string pointer is NULL or points to empty string
 */
static inline bool is_blank_string(const char *s)
{
	return s == NULL || s[0] == '\0';
}

Datum
odbc_fdw_handler(PG_FUNCTION_ARGS)
{
	FdwRoutine *fdwroutine = makeNode(FdwRoutine);
	/* Functions for scanning foreign tables */
	fdwroutine->GetForeignRelSize = odbcGetForeignRelSize;
	fdwroutine->GetForeignPaths = odbcGetForeignPaths;
	fdwroutine->GetForeignPlan = odbcGetForeignPlan;
	fdwroutine->BeginForeignScan = odbcBeginForeignScan;
	fdwroutine->IterateForeignScan = odbcIterateForeignScan;
	fdwroutine->ReScanForeignScan = odbcReScanForeignScan;
	fdwroutine->EndForeignScan = odbcEndForeignScan;

	/* Functions for updating foreign tables */
	fdwroutine->AddForeignUpdateTargets = odbcAddForeignUpdateTargets;
	fdwroutine->PlanForeignModify = odbcPlanForeignModify;
	fdwroutine->BeginForeignModify = odbcBeginForeignModify;
	fdwroutine->ExecForeignInsert = odbcExecForeignInsert;
	fdwroutine->ExecForeignUpdate = odbcExecForeignUpdate;
	fdwroutine->ExecForeignDelete = odbcExecForeignDelete;
	fdwroutine->EndForeignModify = odbcEndForeignModify;
	fdwroutine->BeginForeignInsert = odbcBeginForeignInsert;
	fdwroutine->EndForeignInsert = odbcEndForeignInsert;
	fdwroutine->IsForeignRelUpdatable = odbcIsForeignRelUpdatable;
	fdwroutine->PlanDirectModify = NULL;
	fdwroutine->BeginDirectModify = NULL;
	fdwroutine->IterateDirectModify = NULL;
	fdwroutine->EndDirectModify = NULL;

	/* Function for EvalPlanQual rechecks */
	fdwroutine->RecheckForeignScan = NULL;
	/* Support functions for EXPLAIN */
	fdwroutine->ExplainForeignScan = odbcExplainForeignScan;
	fdwroutine->ExplainForeignModify = odbcExplainForeignModify;
	fdwroutine->ExplainDirectModify = NULL;

	/* Support functions for ANALYZE */
	fdwroutine->AnalyzeForeignTable = odbcAnalyzeForeignTable;

	/* Support functions for IMPORT FOREIGN SCHEMA */
	fdwroutine->ImportForeignSchema = odbcImportForeignSchema;

	/* Support functions for join push-down */
	fdwroutine->GetForeignJoinPaths = NULL;

	/* Support functions for upper relation push-down */
	fdwroutine->GetForeignUpperPaths = odbcGetForeignUpperPaths;

	PG_RETURN_POINTER(fdwroutine);
}

static void
init_odbcFdwOptions(odbcFdwOptions* options)
{
	memset(options, 0, sizeof(odbcFdwOptions));
}

static void
copy_odbcFdwOptions(odbcFdwOptions* to, odbcFdwOptions* from)
{
	if (to && from)
	{
		*to = *from;
	}
}

/*
 * Avoid NULL string: return original string, or empty string if NULL
 */
static const char*
empty_string_if_null(char *string)
{
	static const char* empty_string = "";
	return string == NULL ? empty_string : string;
}

static const char   odbc_attribute_prefix[] = "odbc_";
static const size_t odbc_attribute_prefix_len = sizeof(odbc_attribute_prefix) - 1; /*  strlen(odbc_attribute_prefix); */

static bool
is_odbc_attribute(const char* defname)
{
	return (strlen(defname) > odbc_attribute_prefix_len && strncmp(defname, odbc_attribute_prefix, odbc_attribute_prefix_len) == 0);
}

/* These ODBC attributes names are always uppercase */
static const char *normalized_attributes[] = { "DRIVER", "DSN", "UID", "PWD" };
static const char *normalized_attribute(const char* attribute_name)
{
	size_t i;
	for (i=0; i < sizeof(normalized_attributes)/sizeof(normalized_attributes[0]); i++)
	{
		if (strcasecmp(attribute_name, normalized_attributes[i])==0)
		{
			attribute_name = normalized_attributes[i];
			break;
		}
	}
	return 	attribute_name;
}

static const char*
get_odbc_attribute_name(const char* defname)
{
	int offset = is_odbc_attribute(defname) ? odbc_attribute_prefix_len : 0;
	return normalized_attribute(defname + offset);
}

static void
extract_odbcFdwOptions(List *options_list, odbcFdwOptions *extracted_options)
{
	ListCell        *lc;

	elog_debug("%s", __func__);

	init_odbcFdwOptions(extracted_options);

	/* Loop through the options, and get the foreign table options */
	foreach(lc, options_list)
	{
		DefElem *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "dsn") == 0)
		{
			extracted_options->connection_list = lappend(extracted_options->connection_list, def);
			continue;
		}

		if (strcmp(def->defname, "driver") == 0)
		{
			extracted_options->connection_list = lappend(extracted_options->connection_list, def);
			continue;
		}

		if (strcmp(def->defname, "schema") == 0)
		{
			extracted_options->schema = defGetString(def);
			continue;
		}

		if (strcmp(def->defname, "table") == 0)
		{
			extracted_options->table = defGetString(def);
			continue;
		}

		if (strcmp(def->defname, "prefix") == 0)
		{
			extracted_options->prefix = defGetString(def);
			continue;
		}

		if (strcmp(def->defname, "sql_query") == 0)
		{
			extracted_options->sql_query = defGetString(def);
			continue;
		}

		if (strcmp(def->defname, "sql_count") == 0)
		{
			extracted_options->sql_count = defGetString(def);
			continue;
		}

		if (strcmp(def->defname, "encoding") == 0)
		{
			extracted_options->encoding = defGetString(def);
			continue;
		}

		if (is_odbc_attribute(def->defname))
		{
			extracted_options->connection_list = lappend(extracted_options->connection_list, def);
			continue;
		}
	}
}

/*
 * Get the schema name from the options
 */
static char* get_schema_name(odbcFdwOptions *options)
{
	return options->schema;
}

/*
 * Establish ODBC connection
 */
static void
odbc_connection(odbcFdwOptions* options, SQLHENV *env, SQLHDBC *dbc)
{
	StringInfoData  conn_str;
	SQLCHAR OutConnStr[1024];
	SQLSMALLINT OutConnStrLen;
	SQLRETURN ret;

	odbcConnStr(&conn_str, options);

	/* Allocate an environment handle */
	ret = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, env);
	check_return(ret, "Allocate hENV", NULL, SQL_INVALID_HANDLE);
	/* We want ODBC 3 support */
	ret = SQLSetEnvAttr(*env, SQL_ATTR_ODBC_VERSION, (void *) SQL_OV_ODBC3, 0);
	if (!SQL_SUCCEEDED(ret))
	{
		SQLFreeHandle(SQL_HANDLE_ENV, env);
		env = NULL;
	}
	check_return(ret, "set ODBC version", NULL, SQL_INVALID_HANDLE);

	/* Allocate a connection handle */
	ret = SQLAllocHandle(SQL_HANDLE_DBC, *env, dbc);
	if (!SQL_SUCCEEDED(ret))
	{
		SQLFreeHandle(SQL_HANDLE_ENV, env);
		env = NULL;
	}
	check_return(ret, "Allocate hDBC", NULL, SQL_INVALID_HANDLE);
	/* Connect to the DSN */
	ret = SQLDriverConnect(*dbc, NULL, (SQLCHAR *) conn_str.data, SQL_NTS,
	                       OutConnStr, 1024, &OutConnStrLen, SQL_DRIVER_COMPLETE);
	if (!SQL_SUCCEEDED(ret))
	{
		SQLFreeHandle(SQL_HANDLE_DBC, dbc);
		dbc = NULL;
		SQLFreeHandle(SQL_HANDLE_ENV, env);
		env = NULL;
	}
	check_return(ret, "Connecting to driver", dbc, SQL_HANDLE_DBC);
	elog_debug("Connection opened");
}

/*
 * Close the ODBC connection
 */
static void
odbc_disconnection(SQLHENV *env, SQLHDBC *dbc)
{
	SQLRETURN ret;

	if (*dbc)
	{
		ret = SQLDisconnect(*dbc);
		check_return(ret, "dbc disconnect", *dbc, SQL_HANDLE_DBC);
		ret = SQLFreeHandle(SQL_HANDLE_DBC, *dbc);
		check_return(ret, "dbc free handle", *dbc, SQL_HANDLE_DBC);
		dbc = NULL;
		if (*env)
		{
			ret = SQLFreeHandle(SQL_HANDLE_ENV, *env);
			check_return(ret, "env free handle", *env, SQL_HANDLE_ENV);
			env = NULL;
		}
	}
	elog_debug("Connection closed");
}

/*
 * Validate function
 */
Datum
odbc_fdw_validator(PG_FUNCTION_ARGS)
{
	List  *options_list = untransformRelOptions(PG_GETARG_DATUM(0));
	Oid   catalog = PG_GETARG_OID(1);
	char  *svr_schema   = NULL;
	char  *svr_table    = NULL;
	char  *svr_prefix   = NULL;
	char  *sql_query    = NULL;
	char  *sql_count    = NULL;
	ListCell *cell;

	elog_debug("%s", __func__);

	/*
	 * Check that the necessary options: address, port, database
	 */
	foreach(cell, options_list)
	{
		DefElem    *def = (DefElem *) lfirst(cell);

		/* Complain invalid options */
		if (!odbcIsValidOption(def->defname, catalog))
		{
			/*
			 * Unknown option specified, complain about it. Provide a hint
			 * with a valid option that looks similar, if there is one.
			 */
			struct odbcFdwOption *opt;
#if (PG_VERSION_NUM >= 160000)
			const char *closest_match;
			ClosestMatchState match_state;
			bool		has_valid_options = false;

			initClosestMatch(&match_state, def->defname, 4);
			for (opt = valid_options; opt->optname; opt++)
			{
				if (catalog == opt->optcontext)
				{
					has_valid_options = true;
					updateClosestMatch(&match_state, opt->optname);
				}
			}

			closest_match = getClosestMatch(&match_state);
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname),
					 has_valid_options ? closest_match ?
					 errhint("Perhaps you meant the option \"%s\".",
							 closest_match) : 0 :
					 errhint("There are no valid options in this context.")));
		}
#else
			StringInfoData buf;

			initStringInfo(&buf);
			for (opt = valid_options; opt->optname; opt++)
			{
				if (catalog == opt->optcontext)
					appendStringInfo(&buf, "%s%s", (buf.len > 0) ? ", " : "",
					                 opt->optname);
			}

			ereport(ERROR,
			        (errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
			         errmsg("invalid option \"%s\"", def->defname),
			         errhint("Valid options in this context are: %s", buf.len ? buf.data : "<none>")
			        ));
		}
#endif

		/* TODO: detect redundant connection attributes and missing required attributs (dsn or driver)
		 * Complain about redundent options
		 */
		if (strcmp(def->defname, "schema") == 0)
		{
			if (!is_blank_string(svr_schema))
				ereport(ERROR,
				        (errcode(ERRCODE_SYNTAX_ERROR),
				         errmsg("conflicting or redundant options: schema (%s)", defGetString(def))
				        ));

			svr_schema = defGetString(def);
		}
		else if (strcmp(def->defname, "table") == 0)
		{
			if (!is_blank_string(svr_table))
				ereport(ERROR,
				        (errcode(ERRCODE_SYNTAX_ERROR),
				         errmsg("conflicting or redundant options: table (%s)", defGetString(def))
				        ));

			svr_table = defGetString(def);
		}
		else if (strcmp(def->defname, "prefix") == 0)
		{
			if (!is_blank_string(svr_prefix))
				ereport(ERROR,
				        (errcode(ERRCODE_SYNTAX_ERROR),
				         errmsg("conflicting or redundant options: prefix (%s)", defGetString(def))
				        ));

			svr_prefix = defGetString(def);
		}
		else if (strcmp(def->defname, "sql_query") == 0)
		{
			if (sql_query)
				ereport(ERROR,
				        (errcode(ERRCODE_SYNTAX_ERROR),
				         errmsg("conflicting or redundant options: sql_query (%s)", defGetString(def))
				        ));

			sql_query = defGetString(def);
		}
		else if (strcmp(def->defname, "sql_count") == 0)
		{
			if (!is_blank_string(sql_count))
				ereport(ERROR,
				        (errcode(ERRCODE_SYNTAX_ERROR),
				         errmsg("conflicting or redundant options: sql_count (%s)", defGetString(def))
				        ));

			sql_count = defGetString(def);
		}
	}

	PG_RETURN_VOID();
}

/*
 * Map ODBC data types to PostgreSQL
 */
static void
sql_data_type(
    SQLSMALLINT odbc_data_type,
    SQLULEN     column_size,
    SQLSMALLINT decimal_digits,
    SQLSMALLINT nullable,
    StringInfo sql_type
)
{
	initStringInfo(sql_type);
	switch(odbc_data_type)
	{
	case SQL_CHAR:
	case SQL_WCHAR :
		appendStringInfo(sql_type, "char(%u)", (unsigned)column_size);
		break;
	case SQL_VARCHAR :
	case SQL_WVARCHAR :
		if (column_size <= 255 && column_size > 0)
		{
			appendStringInfo(sql_type, "varchar(%u)", (unsigned)column_size);
		}
		else
		{
			appendStringInfo(sql_type, "text");
		}
		break;
	case SQL_LONGVARCHAR :
	case SQL_WLONGVARCHAR :
		appendStringInfo(sql_type, "text");
		break;
	case SQL_DECIMAL :
		appendStringInfo(sql_type, "decimal(%u,%d)", (unsigned)column_size, decimal_digits);
		break;
	case SQL_NUMERIC :
		appendStringInfo(sql_type, "numeric(%u,%d)", (unsigned)column_size, decimal_digits);
		break;
	case SQL_INTEGER :
		appendStringInfo(sql_type, "integer");
		break;
	case SQL_REAL :
		appendStringInfo(sql_type, "real");
		break;
	case SQL_FLOAT :
		appendStringInfo(sql_type, "real");
		break;
	case SQL_DOUBLE :
		appendStringInfo(sql_type, "float8");
		break;
	case SQL_BIT :
		/* Use boolean instead of bit(1) because:
		 * * binary types are not yet fully supported
		 * * boolean is more commonly used in PG
		 * * With options BoolsAsChar=0 this allows
		 *   preserving boolean columns from pSQL ODBC.
		 */
		appendStringInfo(sql_type, "boolean");
		break;
	case SQL_SMALLINT :
	case SQL_TINYINT :
		appendStringInfo(sql_type, "smallint");
		break;
	case SQL_BIGINT :
		appendStringInfo(sql_type, "bigint");
		break;
	/*
	 * TODO: Implement these cases properly. See #23
	 *
	case SQL_BINARY :
		appendStringInfo(sql_type, "bit(%u)", (unsigned)column_size);
		break;
	case SQL_VARBINARY :
		appendStringInfo(sql_type, "varbit(%u)", (unsigned)column_size);
		break;
	*/
	case SQL_LONGVARBINARY :
		appendStringInfo(sql_type, "bytea");
		break;
	case SQL_TYPE_DATE :
	case SQL_DATE :
		appendStringInfo(sql_type, "date");
		break;
	case SQL_TYPE_TIME :
	case SQL_TIME :
		appendStringInfo(sql_type, "time");
		break;
	case SQL_TYPE_TIMESTAMP :
	case SQL_TIMESTAMP :
		appendStringInfo(sql_type, "timestamp");
		break;
	case SQL_GUID :
		appendStringInfo(sql_type, "uuid");
		break;
	};
}

/*
 * Fetch the options for a server and options list
 */
static void
odbcGetOptions(Oid server_oid, List *add_options, odbcFdwOptions *extracted_options, Oid userid)
{
	ForeignServer   *server;
	UserMapping     *mapping;
	List            *options;

	elog_debug("%s", __func__);

	server  = GetForeignServer(server_oid);

	if (userid == InvalidOid)
		mapping = GetUserMapping(GetUserId(), server_oid);
	else
		mapping = GetUserMapping(userid, server_oid);

	options = NIL;
	options = list_concat(options, add_options);
	options = list_concat(options, server->options);
	options = list_concat(options, mapping->options);

	extract_odbcFdwOptions(options, extracted_options);
}

/*
 * Fetch the options for a odbc_fdw foreign table.
 */
static void
odbcGetTableOptions(Oid foreigntableid, odbcFdwOptions *extracted_options, Oid userid)
{
	ForeignTable    *table;

	elog_debug("%s", __func__);

	table = GetForeignTable(foreigntableid);
	odbcGetOptions(table->serverid, table->options, extracted_options, userid);

	if (is_blank_string(extracted_options->table))
		extracted_options->table = get_rel_name(foreigntableid);
}

#define MAX_ERROR_MSG_LENGTH 512
#define ERROR_MSG_SEP "\n"

static void
check_return(SQLRETURN ret, char *msg, SQLHANDLE handle, SQLSMALLINT type)
{
	SQLINTEGER   i = 0;
	SQLINTEGER   native;
	SQLCHAR  state[ 7 ];
	SQLCHAR  text[256];
	SQLSMALLINT  len;
	SQLRETURN    diag_ret;
	static char error_msg[MAX_ERROR_MSG_LENGTH+1];
	int err_code = ERRCODE_SYSTEM_ERROR;

	strncpy(error_msg, msg, MAX_ERROR_MSG_LENGTH);

	if (!SQL_SUCCEEDED(ret))
	{
		elog_debug("Error result (%d): %s", ret, error_msg);
		if (handle)
		{
			do
			{
				diag_ret = SQLGetDiagRec(type, handle, ++i, state, &native, text,
				                         sizeof(text), &len );
				if (SQL_SUCCEEDED(diag_ret))
				{
					elog_debug(" %s:%ld:%ld:%s\n", state, (long int) i, (long int) native, text);
					strncat(error_msg, ERROR_MSG_SEP, MAX_ERROR_MSG_LENGTH - strlen(ERROR_MSG_SEP));
					strncat(error_msg, (char *)text, MAX_ERROR_MSG_LENGTH - strlen(error_msg));
				}
			}
			while( diag_ret == SQL_SUCCESS );
		}
		ereport(ERROR, (errcode(err_code), errmsg("%s", error_msg)));
	}
}

/*
 * Get name qualifier char
 */
static void
getNameQualifierChar(SQLHDBC dbc, StringInfoData *nq_char)
{
	SQLCHAR name_qualifier_char[2];

	elog_debug("%s", __func__);

	SQLGetInfo(dbc,
	           SQL_CATALOG_NAME_SEPARATOR,
	           (SQLPOINTER)&name_qualifier_char,
	           2,
	           NULL);
	name_qualifier_char[1] = 0; // some drivers fail to copy the trailing zero

	initStringInfo(nq_char);
	appendStringInfo(nq_char, "%s", (char *) name_qualifier_char);
}

/*
 * Get quote cahr
 */
static void
getQuoteChar(SQLHDBC dbc, StringInfoData *q_char)
{
	SQLCHAR quote_char[2];

	elog_debug("%s", __func__);

	SQLGetInfo(dbc,
	           SQL_IDENTIFIER_QUOTE_CHAR,
	           (SQLPOINTER)&quote_char,
	           2,
	           NULL);
	quote_char[1] = 0; // some drivers fail to copy the trailing zero

	initStringInfo(q_char);
	appendStringInfo(q_char, "%s", (char *) quote_char);
}

static bool appendConnAttribute(bool sep, StringInfoData *conn_str, const char* name, const char* value)
{
	static const char *sep_str = ";";
	if (!is_blank_string(value))
	{
		if (sep)
			appendStringInfoString(conn_str, sep_str);
		appendStringInfo(conn_str, "%s=%s", name, value);
		sep = true;
	}
	return sep;
}

static void odbcConnStr(StringInfoData *conn_str, odbcFdwOptions* options)
{
	bool sep = false;
	ListCell *lc;

	initStringInfo(conn_str);

	foreach(lc, options->connection_list)
	{
		DefElem *def = (DefElem *) lfirst(lc);
		sep = appendConnAttribute(sep, conn_str, get_odbc_attribute_name(def->defname), defGetString(def));
	}
	elog_debug("CONN STR: %s", conn_str->data);
}

/*
 * odbcGetTableInfo:
 *	- table size
 *	- quote indentifier char
 *	- name qualifier char
 */
static void
odbcGetTableInfo(odbcFdwOptions* options, unsigned int *size, char **quote_char_out, char **name_qualifier_char_out)
{
	SQLHENV env;
	SQLHDBC dbc;
	SQLHSTMT stmt;
	SQLRETURN ret;

	StringInfoData  sql_str;

	SQLUBIGINT table_size;
	SQLLEN indicator;

	StringInfoData name_qualifier_char;
	StringInfoData quote_char;

	const char* schema_name;

	schema_name = get_schema_name(options);

	odbc_connection(options, &env, &dbc);

	/* Allocate a statement handle */
	SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);

	/* Get quote char */
	getQuoteChar(dbc, &quote_char);

	/* Get name qualifier char */
	getNameQualifierChar(dbc, &name_qualifier_char);

	if (quote_char_out)
		*quote_char_out = quote_char.data;

	if (name_qualifier_char_out)
		*name_qualifier_char_out = name_qualifier_char.data;

	if (is_blank_string(options->sql_count))
	{
		initStringInfo(&sql_str);
		if (is_blank_string(options->sql_query))
		{
			if (is_blank_string(schema_name))
			{
				appendStringInfo(&sql_str, "SELECT COUNT(*) FROM %s",
				                 odbc_quote_identifier(options->table, quote_char.data, false));
			}
			else
			{
				appendStringInfo(&sql_str, "SELECT COUNT(*) FROM %s%s%s",
				                 odbc_quote_identifier(schema_name, quote_char.data, false),
				                 name_qualifier_char.data,
				                 odbc_quote_identifier(options->table, quote_char.data, false));
			}
		}
		else
		{
			if (options->sql_query[strlen(options->sql_query)-1] == ';')
			{
				/* Remove trailing semicolon if present */
				options->sql_query[strlen(options->sql_query)-1] = 0;
			}
			appendStringInfo(&sql_str, "SELECT COUNT(*) FROM (%s) AS _odbc_fwd_count_wrapped", options->sql_query);
		}
	}
	else
	{
		initStringInfo(&sql_str);
		appendStringInfo(&sql_str, "%s", options->sql_count);
	}

	elog_debug("Count query: %s", sql_str.data);

	ret = SQLExecDirect(stmt, (SQLCHAR *) sql_str.data, SQL_NTS);
	check_return(ret, "Executing ODBC query to get table size", stmt, SQL_HANDLE_STMT);
	if (SQL_SUCCEEDED(ret))
	{
		SQLFetch(stmt);
		/* retrieve column data as a big int */
		ret = SQLGetData(stmt, 1, SQL_C_UBIGINT, &table_size, 0, &indicator);
		if (SQL_SUCCEEDED(ret))
		{
			*size = (unsigned int) table_size;
			elog_debug("Count query result: %lu", table_size);
		}
	}
	else
	{
		elog(WARNING, "Error getting the table %s size", options->table);
	}

	/* Free handles, and disconnect */
	if (stmt)
	{
		SQLFreeHandle(SQL_HANDLE_STMT, stmt);
		stmt = NULL;
	}
	odbc_disconnection(&env, &dbc);
}

static int strtoint(const char *nptr, char **endptr, int base)
{
	long val = strtol(nptr, endptr, base);
	return (int) val;
}

static Oid oid_from_server_name(char *serverName)
{
	char *serverOidString;
	char sql[1024];
	int serverOid;
	HeapTuple tuple;
	TupleDesc tupdesc;
	int ret;

	if ((ret = SPI_connect()) < 0) {
		elog(ERROR, "oid_from_server_name: SPI_connect returned %d", ret);
	}

	sprintf(sql, "SELECT oid FROM pg_foreign_server where srvname = '%s'", serverName);
	if ((ret = SPI_execute(sql, true, 1)) != SPI_OK_SELECT) {
		elog(ERROR, "oid_from_server_name: Get server name from Oid query Failed, SP_exec returned %d.", ret);
	}

	if (SPI_tuptable->vals[0] != NULL)
	{
		tupdesc  = SPI_tuptable->tupdesc;
		tuple    = SPI_tuptable->vals[0];

		serverOidString = SPI_getvalue(tuple, tupdesc, 1);
		serverOid = strtoint(serverOidString, NULL, 10);
	} else {
		elog(ERROR, "Foreign server %s doesn't exist", serverName);
	}

	SPI_finish();
	return serverOid;
}

Datum
odbc_table_size(PG_FUNCTION_ARGS)
{
	char *serverName = text_to_cstring(PG_GETARG_TEXT_PP(0));
	char *tableName = text_to_cstring(PG_GETARG_TEXT_PP(1));
	char *defname = "table";
	unsigned int tableSize;
	List *tableOptions = NIL;
	Node *val = (Node *) makeString(tableName);
#if PG_VERSION_NUM >= 100000
	DefElem *elem = (DefElem *) makeDefElem(defname, val, -1);
#else
	DefElem *elem = (DefElem *) makeDefElem(defname, val);
#endif
	Oid serverOid = oid_from_server_name(serverName);
	odbcFdwOptions options;

	tableOptions = lappend(tableOptions, elem);
	odbcGetOptions(serverOid, tableOptions, &options, InvalidOid);
	odbcGetTableInfo(&options, &tableSize, NULL, NULL);

	PG_RETURN_INT32(tableSize);
}

Datum
odbc_query_size(PG_FUNCTION_ARGS)
{
	char *serverName = text_to_cstring(PG_GETARG_TEXT_PP(0));
	char *sqlQuery = text_to_cstring(PG_GETARG_TEXT_PP(1));
	char *defname = "sql_query";
	unsigned int querySize;
	List *queryOptions = NIL;
	Node *val = (Node *) makeString(sqlQuery);
#if PG_VERSION_NUM >= 100000
	DefElem *elem = (DefElem *) makeDefElem(defname, val, -1);
#else
	DefElem *elem = (DefElem *) makeDefElem(defname, val);
#endif
	Oid serverOid;
	odbcFdwOptions options;

	queryOptions = lappend(queryOptions, elem);
	serverOid = oid_from_server_name(serverName);
	odbcGetOptions(serverOid, queryOptions, &options, InvalidOid);
	odbcGetTableInfo(&options, &querySize, NULL, NULL);

	PG_RETURN_INT32(querySize);
}

/*
 * Get the list of tables for the current datasource
 */
typedef struct {
	SQLSMALLINT TargetType;
	SQLPOINTER TargetValuePtr;
	SQLINTEGER BufferLength;
	SQLLEN StrLen_or_Ind;
} DataBinding;

typedef struct {
	Oid serverOid;
	DataBinding* tableResult;
	SQLHENV env;
	SQLHDBC dbc;
	SQLHSTMT stmt;
	SQLCHAR schema;
	SQLCHAR name;
	SQLUINTEGER rowLimit;
	SQLUINTEGER currentRow;
} TableDataCtx;


Datum odbc_tables_list(PG_FUNCTION_ARGS)
{
	SQLHENV		env;
	SQLHDBC		dbc;
	SQLHSTMT	stmt;
	SQLUSMALLINT i;
	SQLUSMALLINT numColumns = 5;
	SQLUSMALLINT bufferSize = 1024;
	SQLUINTEGER rowLimit;
	SQLUINTEGER currentRow;
	SQLRETURN	retCode;

	FuncCallContext *funcctx;
	TupleDesc	tupdesc;
	TableDataCtx *datafctx;
	DataBinding *tableResult;
	AttInMetadata *attinmeta;

	if (SRF_IS_FIRSTCALL()) {
		MemoryContext oldcontext;
		char   *serverName;
		int		serverOid;
		odbcFdwOptions options;

		funcctx = SRF_FIRSTCALL_INIT();
		oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);
		datafctx = (TableDataCtx *) palloc0(sizeof(TableDataCtx));
		tableResult = (DataBinding*) palloc0( numColumns * sizeof(DataBinding) );

		serverName = text_to_cstring(PG_GETARG_TEXT_PP(0));
		serverOid = oid_from_server_name(serverName);

		rowLimit = PG_GETARG_INT32(1);
		currentRow = 0;

		odbcGetOptions(serverOid, NULL, &options, InvalidOid);
		odbc_connection(&options, &env, &dbc);
		SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);

		for ( i = 0 ; i < numColumns ; i++ ) {
			tableResult[i].TargetType = SQL_C_CHAR;
			tableResult[i].BufferLength = (bufferSize + 1);
			tableResult[i].TargetValuePtr = palloc0( sizeof(char)*tableResult[i].BufferLength );
		}

		for ( i = 0 ; i < numColumns ; i++ ) {
			retCode = SQLBindCol(stmt, i + 1, tableResult[i].TargetType, tableResult[i].TargetValuePtr, tableResult[i].BufferLength, &(tableResult[i].StrLen_or_Ind));
		}

		if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
			ereport(ERROR,
			        (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
			         errmsg("function returning record called in context "
			                "that cannot accept type record")));

		attinmeta = TupleDescGetAttInMetadata(tupdesc);

		datafctx->serverOid = serverOid;
		datafctx->tableResult = tableResult;
		datafctx->dbc = dbc;
		datafctx->env = env;
		datafctx->stmt = stmt;
		datafctx->rowLimit = rowLimit;
		datafctx->currentRow = currentRow;
		funcctx->user_fctx = datafctx;
		funcctx->attinmeta = attinmeta;

		MemoryContextSwitchTo(oldcontext);
	}

	funcctx = SRF_PERCALL_SETUP();

	datafctx = funcctx->user_fctx;
	stmt = datafctx->stmt;
	tableResult = datafctx->tableResult;
	rowLimit = datafctx->rowLimit;
	currentRow = datafctx->currentRow;
	attinmeta = funcctx->attinmeta;

	retCode = SQLTables( stmt, NULL, SQL_NTS, NULL, SQL_NTS, NULL, SQL_NTS, (SQLCHAR*)"TABLE", SQL_NTS );
	if (SQL_SUCCEEDED(retCode = SQLFetch(stmt)) && (rowLimit == 0 || currentRow < rowLimit)) {
		char       **values;
		HeapTuple    tuple;
		Datum        result;

		values = (char **) palloc0(2 * sizeof(char *));
		values[0] = (char *) palloc0(256 * sizeof(char));
		values[1] = (char *) palloc0(256 * sizeof(char));
		snprintf(values[0], 256, "%s", (char *)tableResult[SQLTABLES_SCHEMA_COLUMN-1].TargetValuePtr);
		snprintf(values[1], 256, "%s", (char *)tableResult[SQLTABLES_NAME_COLUMN-1].TargetValuePtr);
		tuple = BuildTupleFromCStrings(attinmeta, values);
		result = HeapTupleGetDatum(tuple);
		currentRow++;
		datafctx->currentRow = currentRow;
		SRF_RETURN_NEXT(funcctx, result);
	} else {
		SQLFreeHandle(SQL_HANDLE_STMT, &stmt);
		odbc_disconnection(&datafctx->env, &datafctx->dbc);
		SRF_RETURN_DONE(funcctx);
	}
}

/*
 * Check if the provided option is one of the valid options.
 * context is the Oid of the catalog holding the object the option is for.
 */
static bool
odbcIsValidOption(const char *option, Oid context)
{
	struct odbcFdwOption *opt;

	elog_debug("%s", __func__);

	/* Check if the options presents in the valid option list */
	for (opt = valid_options; opt->optname; opt++)
	{
		if (context == opt->optcontext && strcmp(opt->optname, option) == 0)
			return true;
	}

	return false;
}

static void odbcGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	unsigned int table_size   = 0;
	odbcFdwOptions options;
	OdbcFdwRelationInfo *fpinfo;
	ListCell   *lc;
#if PG_VERSION_NUM >= 160000
	Oid userid;
#endif

	elog_debug("%s", __func__);

	/*
	 * We use OdbcFdwRelationInfo to pass various information to subsequent
	 * functions.
	 */
	fpinfo = (OdbcFdwRelationInfo *) palloc0(sizeof(OdbcFdwRelationInfo));
	baserel->fdw_private = (void *) fpinfo;

	/* Base foreign tables need to be pushed down always. */
	fpinfo->pushdown_safe = true;

	/* Look up foreign-table catalog info. */
	fpinfo->table = GetForeignTable(foreigntableid);
	fpinfo->server = GetForeignServer(fpinfo->table->serverid);

	/* Fetch the foreign table options */
#if PG_VERSION_NUM >= 160000
	/*
	 * If the table or the server is configured to use remote estimates,
	 * identify which user to do remote access as during planning.  This
	 * should match what ExecCheckPermissions() does.  If we fail due to lack
	 * of permissions, the query would have failed at runtime anyway.
	 */
	userid = OidIsValid(baserel->userid) ? baserel->userid : GetUserId();

	odbcGetTableOptions(foreigntableid, &options, userid);
#else
	odbcGetTableOptions(foreigntableid, &options, InvalidOid);
#endif
	odbcGetTableInfo(&options, &table_size, &fpinfo->q_char, &fpinfo->name_qualifier_char);

	/*
	 * Identify which baserestrictinfo clauses can be sent to the remote
	 * server and which can't.
	 */
	odbc_classify_conditions(root, baserel, baserel->baserestrictinfo,
							&fpinfo->remote_conds, &fpinfo->local_conds);

	/*
	 * Identify which attributes will need to be retrieved from the remote
	 * server.  These include all attrs needed for joins or final output, plus
	 * all attrs used in the local_conds.  (Note: if we end up using a
	 * parameterized scan, it's possible that some of the join clauses will be
	 * sent to the remote and thus we wouldn't really need to retrieve the
	 * columns used in them.  Doesn't seem worth detecting that case though.)
	 */
	fpinfo->attrs_used = NULL;
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid,
				   &fpinfo->attrs_used);
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		pull_varattnos((Node *) rinfo->clause, baserel->relid,
					   &fpinfo->attrs_used);
	}

	baserel->rows = table_size;
	baserel->tuples = baserel->rows;
}

static void odbcEstimateCosts(PlannerInfo *root, RelOptInfo *baserel, Cost *startup_cost, Cost *total_cost, Oid foreigntableid)
{
	unsigned int table_size   = 0;
	odbcFdwOptions options;
#if PG_VERSION_NUM >= 160000
	Oid userid;
#endif

	elog_debug("----> starting %s", __func__);

	/* Fetch the foreign table options */
#if PG_VERSION_NUM >= 160000
	/*
	 * If the table or the server is configured to use remote estimates,
	 * identify which user to do remote access as during planning.  This
	 * should match what ExecCheckPermissions() does.  If we fail due to lack
	 * of permissions, the query would have failed at runtime anyway.
	 */
	userid = OidIsValid(baserel->userid) ? baserel->userid : GetUserId();

	odbcGetTableOptions(foreigntableid, &options, userid);
#else
	odbcGetTableOptions(foreigntableid, &options, InvalidOid);
#endif

	odbcGetTableInfo(&options, &table_size, NULL, NULL);

	*startup_cost = 25;

	*total_cost = baserel->rows + *startup_cost;

	elog_debug("----> finishing %s", __func__);

}

static void odbcGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	Cost startup_cost;
	Cost total_cost;

	elog_debug("----> starting %s", __func__);

	odbcEstimateCosts(root, baserel, &startup_cost, &total_cost, foreigntableid);

	add_path(baserel,
	         (Path *) create_foreignscan_path(root, baserel,
#if PG_VERSION_NUM >= 90600
	                 NULL, /* PathTarget */
#endif
	                 baserel->rows,
	                 startup_cost,
	                 total_cost,
	                 NIL, /* no pathkeys */
	                 baserel->lateral_relids,
	                 NULL, /* no extra plan */
	                 NIL /* no fdw_private list */));

	elog_debug("----> finishing %s", __func__);
}

static bool odbcAnalyzeForeignTable(Relation relation, AcquireSampleRowsFunc *func, BlockNumber *totalpages)
{
	elog_debug("----> starting %s", __func__);
	elog_debug("----> finishing %s", __func__);

	return false;
}

static ForeignScan* odbcGetForeignPlan(PlannerInfo *root, RelOptInfo *baserel,
                                       Oid foreigntableid, ForeignPath *best_path, List *tlist, List *scan_clauses, Plan *outer_plan)
{
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) baserel->fdw_private;
	Index		scan_relid;
	List	   *fdw_private;
	List	   *remote_exprs = NIL;
	List	   *local_exprs = NIL;
	List	   *retrieved_attrs;
	StringInfoData sql;
	ListCell   *lc;
	List	   *fdw_scan_tlist = NIL;
	List	   *fdw_recheck_quals = NIL;

	if (IS_SIMPLE_REL(baserel))
	{
		/*
		 * For base relations, set scan_relid as the relid of the relation.
		 */
		scan_relid = baserel->relid;

		/*
		 * In a base-relation scan, we must apply the given scan_clauses.
		 *
		 * Separate the scan_clauses into those that can be executed remotely
		 * and those that can't.  baserestrictinfo clauses that were
		 * previously determined to be safe or unsafe by odbc_classify_conditions
		 * are found in fpinfo->remote_conds and fpinfo->local_conds. Anything
		 * else in the scan_clauses list will be a join clause, which we have
		 * to check for remote-safety.
		 *
		 * Note: the join clauses we see here should be the exact same ones
		 * previously examined by postgresGetForeignPaths.  Possibly it'd be
		 * worth passing forward the classification work done then, rather
		 * than repeating it here.
		 *
		 * This code must match "extract_actual_clauses(scan_clauses, false)"
		 * except for the additional decision about remote versus local
		 * execution.
		 */
		foreach(lc, scan_clauses)
		{
			RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);


			Assert(IsA(rinfo, RestrictInfo));

			/*
			 * Ignore any pseudoconstants, they're dealt with elsewhere
			 */
			if (rinfo->pseudoconstant)
				continue;

			if (list_member_ptr(fpinfo->remote_conds, rinfo))
			{
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else if (list_member_ptr(fpinfo->local_conds, rinfo))
				local_exprs = lappend(local_exprs, rinfo->clause);
			else if (odbc_is_foreign_expr(root, baserel, rinfo->clause))
			{
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else
				local_exprs = lappend(local_exprs, rinfo->clause);
		}

		/*
		 * For a base-relation scan, we have to support EPQ recheck, which
		 * should recheck all the remote quals.
		 */
		fdw_recheck_quals = remote_exprs;
	}
	else
	{
		/*
		 * Join relation or upper relation - set scan_relid to 0.
		 */
		scan_relid = 0;

		/*
		 * For a join rel, baserestrictinfo is NIL and we are not considering
		 * parameterization right now, so there should be no scan_clauses for
		 * a joinrel or an upper rel either.
		 */
		Assert(!scan_clauses);

		/*
		 * Instead we get the conditions to apply from the fdw_private
		 * structure.
		 */
		remote_exprs = extract_actual_clauses(fpinfo->remote_conds, false);
		local_exprs = extract_actual_clauses(fpinfo->local_conds, false);

		/*
		 * We leave fdw_recheck_quals empty in this case, since we never need
		 * to apply EPQ recheck clauses.  In the case of a joinrel, EPQ
		 * recheck is handled elsewhere --- see GetForeignJoinPaths(). If
		 * we're planning an upperrel (ie, remote grouping or aggregation)
		 * then there's no EPQ to do because SELECT FOR UPDATE wouldn't be
		 * allowed, and indeed we *can't* put the remote clauses into
		 * fdw_recheck_quals because the unaggregated Vars won't be available
		 * locally.
		 */

		/*
		 * Build the list of columns to be fetched from the foreign server.
		 */

		fdw_scan_tlist = odbc_build_tlist_to_deparse(baserel);

		/*
		 * Ensure that the outer plan produces a tuple whose descriptor
		 * matches our scan tuple slot.  Also, remove the local conditions
		 * from outer plan's quals, lest they be evaluated twice, once by the
		 * local plan and once by the scan.
		 */
		if (outer_plan)
		{
			ListCell   *lc;

			/*
			 * Right now, we only consider grouping and aggregation beyond
			 * joins. Queries involving aggregates or grouping do not require
			 * EPQ mechanism, hence should not have an outer plan here.
			 */
			Assert(!IS_UPPER_REL(baserel));

			/*
			 * First, update the plan's qual list if possible. In some cases
			 * the quals might be enforced below the topmost plan level, in
			 * which case we'll fail to remove them; it's not worth working
			 * harder than this.
			 */
			foreach(lc, local_exprs)
			{
				Node	   *qual = lfirst(lc);

				outer_plan->qual = list_delete(outer_plan->qual, qual);

				/*
				 * For an inner join the local conditions of foreign scan plan
				 * can be part of the joinquals as well.  (They might also be
				 * in the mergequals or hashquals, but we can't touch those
				 * without breaking the plan.)
				 */
				if (IsA(outer_plan, NestLoop) ||
					IsA(outer_plan, MergeJoin) ||
					IsA(outer_plan, HashJoin))
				{
					Join	   *join_plan = (Join *) outer_plan;

					if (join_plan->jointype == JOIN_INNER)
						join_plan->joinqual = list_delete(join_plan->joinqual,
														  qual);
				}
			}

			/*
			 * Now fix the subplan's tlist --- this might result in inserting
			 * a Result node atop the plan tree.
			 */
			outer_plan = change_plan_targetlist(outer_plan, fdw_scan_tlist,
												best_path->path.parallel_safe);
		}
	}

	/*
	 * Build the query string to be sent for execution, and identify
	 * expressions to be sent as parameters.
	 */
	initStringInfo(&sql);
	odbc_deparse_select_stmt_for_rel(&sql, root, baserel, fdw_scan_tlist,
							remote_exprs, best_path->path.pathkeys,
							false, false, false,
							&retrieved_attrs);

	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match order in enum FdwScanPrivateIndex.
	 */
	fdw_private = list_make2(makeString(sql.data), retrieved_attrs);

	return make_foreignscan(tlist, local_exprs,
							scan_relid, NIL, fdw_private,
							fdw_scan_tlist,
							fdw_recheck_quals,
							outer_plan);
}

/*
 * odbcBeginForeignScan
 *
 */
static void
odbcBeginForeignScan(ForeignScanState *node, int eflags)
{
	SQLHENV env;
	SQLHDBC dbc;
	odbcFdwScanState *festate;
	odbcFdwOptions options;
	int encoding = -1;
	EState	   *estate = node->ss.ps.state;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	RangeTblEntry *rte;
	int			rtindex;
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	TupleDesc	tupleDescriptor = tupleSlot->tts_tupleDescriptor;
#if PG_VERSION_NUM >= 160000
	Oid userid;
#endif

	elog_debug("%s", __func__);

	if (fsplan->scan.scanrelid > 0)
		rtindex = fsplan->scan.scanrelid;
	else
#if (PG_VERSION_NUM >= 160000)
		rtindex = bms_next_member(fsplan->fs_base_relids, -1);
#else
		rtindex = bms_next_member(fsplan->fs_relids, -1);
#endif
	rte = exec_rt_fetch(rtindex, estate);

	/* Fetch the foreign table options */
#if PG_VERSION_NUM >= 160000
	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckPermissions() does.
	 */
	userid = OidIsValid(fsplan->checkAsUser) ? fsplan->checkAsUser : GetUserId();
	odbcGetTableOptions(rte->relid, &options, userid);
#else
	odbcGetTableOptions(rte->relid, &options, InvalidOid);
#endif

	odbc_connection(&options, &env, &dbc);

	if (!is_blank_string(options.encoding))
	{
		encoding = pg_char_to_encoding(options.encoding);
		if (encoding < 0)
		{
			ereport(ERROR,
			        (errcode(ERRCODE_FDW_INVALID_ATTRIBUTE_VALUE),
			         errmsg("invalid encoding name \"%s\"", options.encoding)
			        ));
		}
	}

	festate = (odbcFdwScanState *) palloc0(sizeof(odbcFdwScanState));
	festate->attinmeta = TupleDescGetAttInMetadata(tupleDescriptor);
	copy_odbcFdwOptions(&(festate->options), &options);
	festate->env = env;
	festate->dbc = dbc;
	festate->query =  strVal(list_nth(fsplan->fdw_private, FdwScanPrivateSelectSql));
	festate->retrieved_attrs = (List *) list_nth(fsplan->fdw_private,
												 FdwScanPrivateRetrievedAttrs);
	/* prepare for the first iteration, there will be some precalculation needed in the first iteration */
	festate->query_executed = false;
	festate->first_iteration = true;
	festate->encoding = encoding;
	node->fdw_state = (void *) festate;
}

/*
 * odbcIterateForeignScan
 *		Retrieve next row from the result set, or clear tuple slot to indicate
 *		EOF.
 */
static TupleTableSlot *
odbcIterateForeignScan(ForeignScanState *node)
{
	odbcFdwScanState *festate = (odbcFdwScanState *) node->fdw_state;
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	TupleDesc	tupleDescriptor = tupleSlot->tts_tupleDescriptor;
	int			ret = 0;
	SQLHSTMT	stmt;

	elog(DEBUG1, "odbc_fdw : %s", __func__);

	ExecClearTuple(tupleSlot);

	PG_TRY();
	{
		/*
		 * If this is the first call after Begin or ReScan, we need to
		 * execute the query.
		 */
		if (!festate->query_executed)
		{
			/* Allocate a statement handle */
			SQLAllocHandle(SQL_HANDLE_STMT, festate->dbc, &stmt);

			elog_debug("Executing query: %s", festate->query);
			/* Retrieve a list of rows */
			ret = SQLExecDirect(stmt, (SQLCHAR *) festate->query, SQL_NTS);
			check_return(ret, "Executing ODBC query", stmt, SQL_HANDLE_STMT);
			festate->query_executed = true;
			festate->stmt = stmt;
		}
		else
			stmt = festate->stmt;

		ret = SQLFetch(stmt);

		if (SQL_SUCCEEDED(ret))
		{
			/*
			 * If this is the first iteration,
			 * we need to calculate the column size as well as the column conversion
			 */
			if (festate->first_iteration == true)
			{
				odbc_get_column_info(stmt, node, festate);
				festate->first_iteration = false;
			}

			odbc_make_tuple_from_result_row(festate->stmt, tupleDescriptor, festate->retrieved_attrs,
											tupleSlot->tts_values, tupleSlot->tts_isnull, festate);
			ExecStoreVirtualTuple(tupleSlot);
		}
	}
	PG_CATCH();
	{
		/* Release resources related ODBC connections safely. */
		if(festate->stmt)
		{
			ret = SQLFreeHandle(SQL_HANDLE_STMT, festate->stmt);
			check_return(ret, "SQLFreeHandle",  festate->stmt, SQL_HANDLE_STMT);
			festate->stmt = NULL;
		}

		if(festate->dbc)
		{
			ret = SQLDisconnect(festate->dbc);
			check_return(ret, "SQLDisconnect", festate->dbc, SQL_HANDLE_DBC);
			ret = SQLFreeHandle(SQL_HANDLE_DBC, festate->dbc);
			check_return(ret, "SQLFreeHandle", festate->dbc, SQL_HANDLE_DBC);
			festate->dbc = NULL;
		}

		if(festate->env)
		{
			ret = SQLFreeHandle(SQL_HANDLE_ENV, festate->env);
			check_return(ret, "SQLFreeHandle", festate->env, SQL_HANDLE_ENV);
			festate->env = NULL;
		}
		PG_RE_THROW();
	}
	PG_END_TRY();

	return tupleSlot;
}

/*
 * Get column describe from remote server:
 *		- Column size
 *		- Data type (column conversion)
 */
static void
odbc_get_column_info(SQLHSTMT *stmt, ForeignScanState *node, odbcFdwScanState *festate)
{
	MemoryContext prev_context;
	SQLCHAR *ColumnName;
	SQLSMALLINT NameLengthPtr;
	SQLSMALLINT DataTypePtr;
	SQLULEN     ColumnSizePtr;
	SQLSMALLINT DecimalDigitsPtr;
	SQLSMALLINT NullablePtr;
	SQLRETURN	ret;
	SQLSMALLINT columns;
	int			i;
	StringInfoData sql_type;
	List	   *col_size_array;
	List	   *col_conversion_array;

	/* Get number of column */
	ret = SQLNumResultCols(stmt, &columns);
	check_return(ret, "SQLNumResultCols()", stmt, SQL_HANDLE_STMT);

	prev_context = MemoryContextSwitchTo(node->ss.ps.state->es_query_cxt);
	col_size_array = NIL;
	col_conversion_array = NIL;

	/* Obtain the column information of the first row. */
	for (i = 1; i <= columns; i++)
	{
		ColumnConversion conversion = TEXT_CONVERSION;
		ColumnName = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN);

		ret = SQLDescribeCol(stmt,
							i,                       /* ColumnName */
							ColumnName,
							sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN, /* BufferLength */
							&NameLengthPtr,
							&DataTypePtr,
							&ColumnSizePtr,
							&DecimalDigitsPtr,
							&NullablePtr);
		check_return(ret, "SQLDescribeCol()", stmt, SQL_HANDLE_STMT);
		col_size_array = lappend_int(col_size_array, (int) ColumnSizePtr);

		/* get column conversion */
		sql_data_type(DataTypePtr, ColumnSizePtr, DecimalDigitsPtr, NullablePtr, &sql_type);
		if (strcmp("bytea", (char*)sql_type.data) == 0)
		{
			conversion = BIN_CONVERSION;
		}
		if (strcmp("boolean", (char*)sql_type.data) == 0)
		{
			conversion = BOOL_CONVERSION;
		}
		else if (strncmp("bit(",(char*)sql_type.data,4)==0 || strncmp("varbit(",(char*)sql_type.data,7)==0)
		{
			conversion = BIN_CONVERSION;
		}
		col_conversion_array = lappend_int(col_conversion_array, (int) conversion);

		pfree(ColumnName);
	}

	festate->col_size_array = col_size_array;
	festate->col_conversion_array = col_conversion_array;
	MemoryContextSwitchTo(prev_context);
}

/*
 * odbc_make_tuple_from_result_row:
 * 		Create a tuple from the specified row of the ODBC resultset.
 */
static void
odbc_make_tuple_from_result_row(SQLHSTMT * stmt,
						 		TupleDesc tupleDescriptor,
								List *retrieved_attrs,
								Datum *row,
								bool *is_null,
								odbcFdwScanState * festate)
{
	ListCell   *lc = NULL;
	int			attid = 0;
	char	   *value;
	SQLLEN		result_size;

	memset(row, 0, sizeof(Datum) * tupleDescriptor->natts);
	memset(is_null, true, sizeof(bool) * tupleDescriptor->natts);

	foreach(lc, retrieved_attrs)
	{
		int			attnum = lfirst_int(lc) - 1;
		Oid			pgtype = TupleDescAttr(tupleDescriptor, attnum)->atttypid;
		int32		pgtypmod = TupleDescAttr(tupleDescriptor, attnum)->atttypmod;
		ColumnConversion conversion = list_nth_int(festate->col_conversion_array, attid);

		/* Get column value */
		value = odbc_get_attr_value(festate, attid, pgtype, &result_size, conversion);
		if (result_size != SQL_NULL_DATA)
		{
			is_null[attnum] = false;
			row[attnum] = odbc_convert_to_pg(pgtype, pgtypmod, value, result_size, conversion);
		}
		attid++;
	}
}

/*
 * odbc_get_attr_value:
 * 		Get attr value from remote server as a string value.
 */
static char*
odbc_get_attr_value(odbcFdwScanState *festate, int attid, Oid pgtype, SQLLEN *result_size, ColumnConversion conversion)
{
	int			col_size = list_nth_int(festate->col_size_array, attid);
	SQLHSTMT	stmt = festate->stmt;
	SQLRETURN	ret = 0;
	SQLSMALLINT	target_type = SQL_C_CHAR;
	int			chunk_size, effective_chunk_size;
	int			buffer_size = 0;
	char	   *buffer = 0;
	int			used_buffer_size = 0;
	GetDataTruncation truncation;
	bool		binary_data = false;

	if (conversion == BIN_CONVERSION)
	{
		target_type	= SQL_C_BINARY;
		binary_data = true;
	}

	if (col_size == 0)
	{
		col_size = 1024;
	}

	chunk_size = binary_data ? col_size : col_size + 1;

	do // Loop for reading the field in chunks
	{
		resize_buffer(&buffer, &buffer_size, used_buffer_size, used_buffer_size + chunk_size);
		ret = SQLGetData(stmt, attid + 1, target_type, buffer + used_buffer_size, chunk_size, result_size);
		check_return(ret, "SQLGetData()", stmt, SQL_HANDLE_STMT);
		effective_chunk_size = chunk_size;
		if (!binary_data && buffer[used_buffer_size + chunk_size - 1] == 0)
		{
			effective_chunk_size--;
		}
		truncation = result_truncation(ret, stmt);
		if (truncation == STRING_TRUNCATION)
		{
			if (*result_size == SQL_NO_TOTAL)
			{
				// no info about remaining data size; keep reading with same chunk_size
				used_buffer_size += effective_chunk_size;
			}
			else
			{
				// we read chunk_size, but there was result_size pending in total;
				// adjust chunk_size for the remaining, so next wil hopely be the final chunk
				used_buffer_size += effective_chunk_size;
				// note that we need to read result_size - effective_chunk_size more data bytes,
				chunk_size = (int)*result_size - effective_chunk_size;
				// wait, maybe we don't need to read, just append a zero!
				if (chunk_size == 0)
				{
					if (!binary_data)
					{
						resize_buffer(&buffer, &buffer_size, used_buffer_size, used_buffer_size + 1);
						buffer[used_buffer_size - 1] = 0;
					}
					break;
				}
				if (!binary_data)
				{
					chunk_size += 1;
				}
			}
		}
		else if (truncation == FRACTIONAL_TRUNCATION)
		{
			/*
			 * Fractional truncation has occurred;
			 * at this point we cannot obtain the lost digits
			 */
			used_buffer_size += effective_chunk_size;
			if (chunk_size == effective_chunk_size)
			{
				/* The driver has omitted the trailing zero */
				resize_buffer(&buffer, &buffer_size, used_buffer_size, used_buffer_size + 1);
				buffer[used_buffer_size] = 0;
			}
			elog_debug("Truncating number: %s", buffer);
		}
		else // NO_TRUNCATION: finish reading
		{
			used_buffer_size += *result_size;
		}
	} while (truncation == STRING_TRUNCATION && chunk_size > 0);

	if (!binary_data)
	{
		used_buffer_size = strnlen(buffer, used_buffer_size);
	}

	if (ret != SQL_SUCCESS_WITH_INFO)
	{
		// TODO: review check_result behaviour for SQL_SUCCESS_WITH_INFO (it should not fail right?)
		check_return(ret, "Reading data", stmt, SQL_HANDLE_STMT);
	}
	if (festate->encoding != -1 && !binary_data)
	{
		/* Convert character encoding */
		buffer = pg_any_to_server(buffer, used_buffer_size, festate->encoding);
	}

	return buffer;
}

/*
 * odbc_convert_to_pg:
 * 		Convert ODBC data into PostgreSQL's compatible data types
 */
static Datum
odbc_convert_to_pg(Oid pgtyp, int pgtypmod, char* value, int size, ColumnConversion conversion)
{
	Datum		value_datum = 0;
	Datum		valueDatum = 0;
	regproc		typeinput;
	HeapTuple	tuple;
	char	   *hex;

	/* get the type's output function */
	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(pgtyp));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for type%u", pgtyp);

	typeinput = ((Form_pg_type) GETSTRUCT(tuple))->typinput;
	ReleaseSysCache(tuple);

	switch (conversion)
	{
		case BOOL_CONVERSION:
		{
			if (value[0] == 0)
				strcpy(value, "F");
			else if (value[0] == 1)
				strcpy(value, "T");
			valueDatum = PointerGetDatum(value);
			break;
		}
		case BIN_CONVERSION:
		{
			hex = binary_to_hex(value, size);
			valueDatum = (Datum) palloc0(strlen(hex) + VARHDRSZ);
			memcpy(VARDATA(valueDatum), hex, strlen(hex));
			SET_VARSIZE(valueDatum, strlen(hex) + VARHDRSZ);
			break;
		}
		default:
			/* TEXT_CONVERSION */
			valueDatum = CStringGetDatum((char *) value);
			break;
	}

	value_datum = OidFunctionCall3(typeinput, valueDatum,
								   ObjectIdGetDatum(pgtyp),
								   Int32GetDatum(pgtypmod));

	return value_datum;
}

/*
 * odbcExplainForeignScan
 *
 */
static void
odbcExplainForeignScan(ForeignScanState *node, ExplainState *es)
{
	odbcFdwScanState *festate = (odbcFdwScanState *) node->fdw_state;
	unsigned int table_size = 0;

	elog_debug("%s", __func__);

	odbcGetTableInfo(&(festate->options), &table_size, NULL, NULL);

	/* Suppress file size if we're not showing cost details */
	if (es->costs)
	{
#if PG_VERSION_NUM >= 110000
		ExplainPropertyInteger("Foreign Table Size", "b", table_size, es);
#else
		ExplainPropertyLong("Foreign Table Size", table_size, es);
#endif
	}

	/*
	 * Add remote query, when VERBOSE option is specified.
	 */
	if (es->verbose)
		ExplainPropertyText("Remote SQL", festate->query, es);
}

/*
 * odbcEndForeignScan
 *      Finish scanning foreign table and dispose objects used for this scan
 */
static void
odbcEndForeignScan(ForeignScanState *node)
{
	odbcFdwScanState *festate = (odbcFdwScanState *) node->fdw_state;

	elog_debug("%s", __func__);

	/* if festate is NULL, nothing to do */
	if (festate)
	{
		if (festate->stmt)
		{
			SQLFreeHandle(SQL_HANDLE_STMT, festate->stmt);
			festate->stmt = NULL;
		}
		odbc_disconnection(&festate->env, &festate->dbc);
	}
}

/*
 * odbcReScanForeignScan
 *      Rescan table, possibly with new parameters
 */
static void
odbcReScanForeignScan(ForeignScanState *node)
{
	odbcFdwScanState *festate = (odbcFdwScanState *) node->fdw_state;

	elog_debug("%s", __func__);

	if (festate->stmt)
	{
		SQLFreeHandle(SQL_HANDLE_STMT, festate->stmt);
	}
	/*
	 * Set the query_executed flag to false so that the query will be executed
	 * in odbcIterateForeignScan().
	 */
	festate->query_executed = false;
}


static void
appendQuotedString(StringInfo buffer, const char* text)
{
	static const char SINGLE_QUOTE = '\'';
	const char *p;

	appendStringInfoChar(buffer, SINGLE_QUOTE);

	while (*text)
	{
		p = text;
		while (*p && *p != SINGLE_QUOTE)
		{
			p++;
		}
		appendBinaryStringInfo(buffer, text, p - text);
		if (*p == SINGLE_QUOTE)
		{
			appendStringInfoChar(buffer, SINGLE_QUOTE);
			appendStringInfoChar(buffer, SINGLE_QUOTE);
			p++;
		}
		text = p;
	}

	appendStringInfoChar(buffer, SINGLE_QUOTE);
}

static void
appendOption(StringInfo str, bool first, const char* option_name, const char* option_value)
{
	if (!first)
	{
		appendStringInfo(str, ",\n");
	}
	appendStringInfo(str, "\"%s\" ", option_name);
	appendQuotedString(str, option_value);
}

List *
odbcImportForeignSchema(ImportForeignSchemaStmt *stmt, Oid serverOid)
{
	/* TODO: review memory management in this function; any leaks? */
	odbcFdwOptions options;

	List* create_statements = NIL;
	List* tables = NIL;
	List* table_columns = NIL;
	ListCell *tables_cell;
	ListCell *table_columns_cell;
	RangeVar *table_rangevar;

	SQLHENV env;
	SQLHDBC dbc;
	SQLHSTMT query_stmt = NULL;
	SQLHSTMT columns_stmt;
	SQLHSTMT tables_stmt;
	SQLRETURN ret;
	SQLSMALLINT result_columns;
	StringInfoData col_str;
	SQLCHAR *ColumnName;
	SQLCHAR *TableName;
	SQLSMALLINT NameLength;
	SQLSMALLINT DataType;
	SQLULEN     ColumnSize;
	SQLINTEGER	ColumnSizeInt;
	SQLSMALLINT DecimalDigits;
	SQLSMALLINT Nullable;
	int i;
	StringInfoData sql_type;
	SQLLEN indicator;
	const char* schema_name;
	bool missing_foreign_schema = false;
	bool first_column = true;
	bool use_table_catalog = false;

	elog_debug("%s", __func__);

	odbcGetOptions(serverOid, stmt->options, &options, InvalidOid);

	schema_name = get_schema_name(&options);
	if (schema_name == NULL)
	{
		schema_name = stmt->remote_schema;
		missing_foreign_schema = true;
	}
	else if (is_blank_string(schema_name))
	{
		// This allows overriding and removing the schema, which is necessary
		// for some schema-less ODBC data sources (e.g. Hive)
		schema_name = NULL;
	}

	if (!is_blank_string(options.sql_query))
	{
		/* Generate foreign table for a query */
		if (is_blank_string(options.table))
		{
			elog(ERROR, "Must provide 'table' option to name the foreign table");
		}

		odbc_connection(&options, &env, &dbc);
		PG_TRY();
		{
			/* Allocate a statement handle */
			ret = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &query_stmt);
			check_return(ret, "SQLAllocHandle", query_stmt, SQL_HANDLE_STMT);

			/* Retrieve a list of rows */
			ret = SQLExecDirect(query_stmt, (SQLCHAR *) options.sql_query, SQL_NTS);
			check_return(ret, "Executing ODBC query to get schema", query_stmt, SQL_HANDLE_STMT);

			SQLNumResultCols(query_stmt, &result_columns);

			initStringInfo(&col_str);
			ColumnName = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN);

			for (i = 1; i <= result_columns; i++)
			{
				SQLDescribeCol(query_stmt,
							i,                       /* ColumnName */
							ColumnName,
							sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN, /* BufferLength */
							&NameLength,
							&DataType,
							&ColumnSize,
							&DecimalDigits,
							&Nullable);

				sql_data_type(DataType, ColumnSize, DecimalDigits, Nullable, &sql_type);
				if (is_blank_string(sql_type.data))
				{
					elog(NOTICE, "Data type not supported (%d) for column %s", DataType, ColumnName);
					continue;
				}
				if (!first_column)
				{
					appendStringInfo(&col_str, ", ");
				}
				else
				{
					first_column = false;
				}

				appendStringInfo(&col_str, "\"%s\" %s", ColumnName, (char *) sql_type.data);
			}
			SQLCloseCursor(query_stmt);
		}
		PG_FINALLY();
		{
			SQLFreeHandle(SQL_HANDLE_STMT, query_stmt);
			odbc_disconnection(&env, &dbc);
		}
		PG_END_TRY();

		tables        = lappend(tables, (void*)options.table);
		table_columns = lappend(table_columns, (void*)col_str.data);
	}
	else
	{
		/* Reflect one or more foreign tables */
		if (!is_blank_string(options.table))
		{
			tables = lappend(tables, (void*)options.table);
		}
		else if (stmt->list_type == FDW_IMPORT_SCHEMA_ALL || stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT)
		{
			odbc_connection(&options, &env, &dbc);
			PG_TRY();
			{
				/* Allocate a statement handle */
				ret = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &tables_stmt);
				check_return(ret, "SQLAllocHandle", tables_stmt, SQL_HANDLE_STMT);

				ret = SQLTables(
						tables_stmt,
						NULL, 0, /* Catalog: (SQLCHAR*)SQL_ALL_CATALOGS, SQL_NTS would include also tables from internal catalogs */
						NULL, 0, /* Schema: we avoid filtering by schema here to avoid problems with some drivers */
						NULL, 0, /* Table */
						(SQLCHAR*)"TABLE", SQL_NTS /* Type of table (we're not interested in views, temporary tables, etc.) */
					);
				check_return(ret, "Obtaining ODBC tables", tables_stmt, SQL_HANDLE_STMT);

				ret = SQL_SUCCESS;
				initStringInfo(&col_str);
				while (SQL_SUCCESS == ret)
				{
					ret = SQLFetch(tables_stmt);
					if (SQL_SUCCESS == ret)
					{
						int excluded = false;
						SQLRETURN getdata_ret;
						bool	is_empty_retrieved_string = false;
						bool	is_mapped = false;

						TableName = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_TABLE_NAME_LEN);
						getdata_ret = SQLGetData(tables_stmt, SQLTABLES_NAME_COLUMN, SQL_C_CHAR, TableName, MAXIMUM_TABLE_NAME_LEN, &indicator);
						check_return(getdata_ret, "Reading table name", tables_stmt, SQL_HANDLE_STMT);

						/* Since we're not filtering the SQLTables call by schema
						 * we must exclude here tables that belong to other schemas.
						 * For some ODBC drivers tables may not be organized into
						 * schemas and the schema of the table will be blank.
						 * So we only reject tables for which the schema is not
						 * blank and different from the desired schema.
						 */

						/* check schema name with table schema */
						getdata_ret = validate_retrieved_string(tables_stmt, SQLTABLES_SCHEMA_COLUMN, schema_name, &is_mapped, &is_empty_retrieved_string);

						if ( getdata_ret == SQL_SUCCESS && is_empty_retrieved_string == true)
						{
							/* if can not compare with table schema, try to compare with table catalog */
							getdata_ret = validate_retrieved_string(tables_stmt, SQLTables_TABLE_CATALOG, schema_name, &is_mapped, &is_empty_retrieved_string);
							if (getdata_ret == SQL_SUCCESS && is_empty_retrieved_string == false)
							{
								use_table_catalog = true;
							}
						}
						if (getdata_ret == SQL_SUCCESS)
						{
							/* if schema name is not mapped with table schema or table catalog,
							 * set excluded = true to remove it from table list
							 */
							if (is_mapped == false)
								excluded = true;
						}
						else
						{
							/* Some drivers don't support schemas and may return an error code here;
							 * in that case we must avoid using an schema to query the table columns.
							 */
							schema_name = NULL;
							missing_foreign_schema = false;
						}
						/* Since we haven't specified SQL_ALL_CATALOGS in the
						 * call to SQLTables we shouldn't get tables from special
						 * catalogs and only from the regular catalog of the database
						 * (the catalog name is usually the name of the database or blank,
						 * but depends on the driver and may vary, and can be obtained with:
						 * 	SQLCHAR *table_catalog = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_CATALOG_NAME_LEN);
						 * 	SQLGetData(tables_stmt, 1, SQL_C_CHAR, table_catalog, MAXIMUM_CATALOG_NAME_LEN, &indicator);
						 */

						/* And now we'll handle tables excluded by an EXCEPT clause */
						if (!excluded && stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT)
						{
							foreach(tables_cell,  stmt->table_list)
							{
								table_rangevar = (RangeVar*)lfirst(tables_cell);
								if (strcmp((char*)TableName, table_rangevar->relname) == 0)
								{
									excluded = true;
								}
							}
						}

						if (!excluded)
						{
							tables = lappend(tables, (void*)TableName);
						}
					}
				}

				SQLCloseCursor(tables_stmt);
			}
			PG_FINALLY();
			{
				SQLFreeHandle(SQL_HANDLE_STMT, tables_stmt);
				odbc_disconnection(&env, &dbc);
			}
			PG_END_TRY();
		}
		else if (stmt->list_type == FDW_IMPORT_SCHEMA_LIMIT_TO)
		{
			foreach(tables_cell, stmt->table_list)
			{
				table_rangevar = (RangeVar*)lfirst(tables_cell);
				tables = lappend(tables, (void*)table_rangevar->relname);
			}
		}
		else
		{
			elog(ERROR,"Unknown list type in IMPORT FOREIGN SCHEMA");
		}

		odbc_connection(&options, &env, &dbc);
		foreach(tables_cell, tables)
		{
			char *table_name = (char*)lfirst(tables_cell);
			List* pkeyList = NIL;
			SQLCHAR* primaryKeyName = NULL;

			elog(DEBUG1, "table_name : %s", table_name);

			/* Allocate a statement handle */
			SQLAllocHandle(SQL_HANDLE_STMT, dbc, &columns_stmt);

			/* Obtain primary keys in ODBC table */
			if (use_table_catalog == true)
				ret = SQLPrimaryKeys(columns_stmt,
									(SQLCHAR *)schema_name,
									SQL_NTS,
									NULL,		/* table schema */
									0,
									(SQLCHAR *)table_name,  SQL_NTS);
			else
				ret = SQLPrimaryKeys(columns_stmt,
									NULL,		/* table catalog */
									0,
									(SQLCHAR *)schema_name,
									SQL_NTS,
									(SQLCHAR*)table_name,  SQL_NTS);

			check_return(ret, "Obtaining ODBC primary keys", columns_stmt, SQL_HANDLE_STMT);

			ret = SQL_SUCCESS;
			while ((ret == SQL_SUCCESS) || (ret == SQL_SUCCESS_WITH_INFO))
			{
				ret = SQLFetch(columns_stmt);
				if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO)
				{
					primaryKeyName = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN);
					ret = SQLGetData(columns_stmt, 4, SQL_C_CHAR, primaryKeyName, MAXIMUM_COLUMN_NAME_LEN, &indicator);
					elog(DEBUG1, "primaryKeyName : %ld : %s", indicator, primaryKeyName);
					pkeyList = lappend(pkeyList, primaryKeyName);
				}
				else if (ret != SQL_NO_DATA)
				{
					elog(ERROR, "error fetch primary keys");
				}
			}
			SQLCloseCursor(columns_stmt);

			if (use_table_catalog == true)
			{
				ret = SQLColumns(columns_stmt,
								(SQLCHAR *)schema_name,
								SQL_NTS,
								NULL,
								0,
								(SQLCHAR*)table_name,  SQL_NTS,
								NULL, 0);
			}
			else
			{
				ret = SQLColumns(columns_stmt,
								NULL,
								0,
								(SQLCHAR *)schema_name,
								SQL_NTS,
								(SQLCHAR*)table_name,  SQL_NTS,
								NULL, 0);
			}

			check_return(ret, "Obtaining ODBC columns", columns_stmt, SQL_HANDLE_STMT);

			ret = SQL_SUCCESS;
			i = 0;
			initStringInfo(&col_str);
			ColumnName = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_COLUMN_NAME_LEN);
			while (SQL_NO_DATA != ret && SQL_SUCCESS_WITH_INFO != ret)
			{
				ret = SQLFetch(columns_stmt);
				if (SQL_SUCCESS == ret)
				{
					bool isKey = false;
					ListCell *pkeyCell;

					ret = SQLGetData(columns_stmt, 4, SQL_C_CHAR, ColumnName, MAXIMUM_COLUMN_NAME_LEN, &indicator);
					elog(DEBUG1, "ColumnName : %s", ColumnName);
					ret = SQLGetData(columns_stmt, 5, SQL_C_SSHORT, &DataType, MAXIMUM_COLUMN_NAME_LEN, &indicator);
					/* SQL_C_SLONG is mapped with SQLINTEGER, use ColumnSizeInt instead of ColumnSize (SQLULEN) */
					ret = SQLGetData(columns_stmt, 7, SQL_C_SLONG, &ColumnSizeInt, 0, &indicator);
					ret = SQLGetData(columns_stmt, 9, SQL_C_SSHORT, &DecimalDigits, 0, &indicator);
					ret = SQLGetData(columns_stmt, 11, SQL_C_SSHORT, &Nullable, 0, &indicator);
					sql_data_type(DataType, (SQLULEN)ColumnSizeInt, DecimalDigits, Nullable, &sql_type);
					if (is_blank_string(sql_type.data))
					{
						elog(NOTICE, "Data type not supported (%d) for column %s", DataType, ColumnName);
						continue;
					}
					foreach(pkeyCell, pkeyList)
					{
						SQLCHAR* keyName = lfirst(pkeyCell);
						if(strcmp((char *)keyName, (char *)ColumnName) == 0)
						{
							isKey = true;
							break;
						}
					}
					if (++i > 1)
					{
						appendStringInfo(&col_str, ", ");
					}
					/* set 'key' OPTION if there is column name in pkeyList */
					if(isKey)
					{
						appendStringInfo(&col_str, "\"%s\" %s OPTIONS (key 'true')", ColumnName, (char *) sql_type.data);
					} else {
						appendStringInfo(&col_str, "\"%s\" %s", ColumnName, (char *) sql_type.data);
					}
				}
				#ifdef DEBUG
				if (ret == SQL_ERROR || ret == SQL_SUCCESS_WITH_INFO)
				{
					SQLINTEGER   j = 1;
					SQLINTEGER   native;
					SQLCHAR  state[ 7 ];
					SQLCHAR  text[256];
					SQLSMALLINT  len;
					SQLRETURN    diag_ret;
					do
					{
				        diag_ret = SQLGetDiagRec(SQL_HANDLE_STMT, columns_stmt, j++, state, &native, text, sizeof(text), &len);
						if (SQL_SUCCEEDED(diag_ret))
							elog(DEBUG1, "FETCHING %s:%ld:%ld:%s\n", state, (long int) j, (long int) native, text);
					}
					while( diag_ret == SQL_SUCCESS );
				}
				#endif
			}
			SQLCloseCursor(columns_stmt);

			SQLFreeHandle(SQL_HANDLE_STMT, columns_stmt);
			elog(DEBUG1, "col_str : %s", col_str.data);
			table_columns = lappend(table_columns, (void*)col_str.data);
		}
		odbc_disconnection(&env, &dbc);
	}

	/* Generate create statements */
	table_columns_cell = list_head(table_columns);
	foreach(tables_cell, tables)
	{
		// temporarily define vars here...
		char *table_name = (char*)lfirst(tables_cell);
		char *columns    = (char*)lfirst(table_columns_cell);
		StringInfoData create_statement;
		ListCell *option;
		int option_count = 0;
		const char *prefix = empty_string_if_null(options.prefix);

#if PG_VERSION_NUM >= 130000
		table_columns_cell = lnext(table_columns, table_columns_cell);
#else
		table_columns_cell = lnext(table_columns_cell);
#endif

		initStringInfo(&create_statement);
		appendStringInfo(&create_statement, "CREATE FOREIGN TABLE \"%s\".\"%s%s\" (", stmt->local_schema, prefix, (char *) table_name);
		appendStringInfo(&create_statement, "%s", columns);
		appendStringInfo(&create_statement, ") SERVER %s\n", stmt->server_name);
		appendStringInfo(&create_statement, "OPTIONS (\n");
		foreach(option, stmt->options)
		{
			DefElem *def = (DefElem *) lfirst(option);
#if PG_VERSION_NUM >= 100000
			// options not in the CREATE FOREIGN TABLE statement will have location == -1
			// we'll ignore them as they are defined by the SERVER or USER MAPPING, and including them here
			// would be functional but could expose sensitive information
			if (def->location != -1) {
				appendOption(&create_statement, ++option_count == 1, def->defname, defGetString(def));
			}
#else
			appendOption(&create_statement, ++option_count == 1, def->defname, defGetString(def));
#endif
		}
		if (is_blank_string(options.table))
		{
			appendOption(&create_statement, ++option_count == 1, "table", table_name);
		}
		if (missing_foreign_schema)
		{
			appendOption(&create_statement, ++option_count == 1, "schema", schema_name);
		}
		appendStringInfo(&create_statement, ");");
		elog(DEBUG1, "CREATE: %s", create_statement.data);
		create_statements = lappend(create_statements, (void*)create_statement.data);
	}

	return create_statements;
}

/*
 * odbcPlanForeignModify
 *		Plan an insert/update/delete operation on a foreign table
 */
static List *
odbcPlanForeignModify(PlannerInfo *root,
					  ModifyTable *plan,
					  Index resultRelation,
					  int subplan_index)
{
	CmdType		operation = plan->operation;
	RangeTblEntry *rte = planner_rt_fetch(resultRelation, root);
	Relation	rel;
	StringInfoData sql;
	Oid foreignTableId;
	TupleDesc tupdesc;
	List	   *targetAttrs = NIL;
	List	   *withCheckOptionList = NIL;
	bool		doNothing = false;
	List       *condAttrs = NIL;
	StringInfoData name_qualifier_char;
	StringInfoData quote_char;
	odbcFdwOptions options;
	SQLHENV		env;
	SQLHDBC		dbc;
	int			i;

	elog(DEBUG1, "----> starting %s", __func__);
	elog(DEBUG1, "resultRelation %d subplan_index %d", resultRelation, subplan_index);

	initStringInfo(&sql);

    /*
	 * Core code already has some lock on each rel being planned, so we can
     * use NoLock here.
     */
	rel = table_open(rte->relid, NoLock);

	/*
	 * get quote/qualifier chars for sql sentence
	 */
	odbcGetTableOptions(RelationGetRelid(rel), &options, InvalidOid);
	odbc_connection(&options, &env, &dbc);
	PG_TRY();
	{
		getQuoteChar(dbc, &quote_char);
		getNameQualifierChar(dbc, &name_qualifier_char);
	}
	PG_FINALLY();
	{
		odbc_disconnection(&env, &dbc);
	}
	PG_END_TRY();

	foreignTableId = RelationGetRelid(rel);
	tupdesc = RelationGetDescr(rel);
	elog(DEBUG1, "columns %d", tupdesc->natts);  // <- 列の一覧っぽい

	/*
	 * In an INSERT, we transmit all columns that are defined in the foreign
	 * table.  In an UPDATE, if there are BEFORE ROW UPDATE triggers on the
	 * foreign table, we transmit all columns like INSERT; else we transmit
	 * only columns that were explicitly targets of the UPDATE, so as to avoid
	 * unnecessary data transmission.  (We can't do that for INSERT since we
	 * would miss sending default values for columns not listed in the source
	 * statement, and for UPDATE if there are BEFORE ROW UPDATE triggers since
	 * those triggers might change values for non-target columns, in which
	 * case we would miss sending changed values for those columns.)
	 */
	if (operation == CMD_INSERT ||
		(operation == CMD_UPDATE &&
		 rel->trigdesc &&
		 rel->trigdesc->trig_update_before_row))
	{
		int attnum;
		for (attnum = 1; attnum <= tupdesc->natts; attnum++)
		{
			// VALUESのとこの一覧を取ってくる。いろいろ書いてあるはず?
			// しかし添字だけlistに追加して後段に渡す
			// やっぱり型もlistに追加し後段に渡す。postgres_fdwと違い全部文字列で渡すわけにいかないようなので。
			// やっぱり全部文字列にして渡すのでもいいのかもしれない。要検討。
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
			elog(DEBUG1, "attname %d %s", attnum, attr->attname.data);
			elog(DEBUG1, (attr->attbyval)?("\tbyval:true"):("\tbyval:false"));
			elog(DEBUG1, "\tlength:%d", attr->attlen);
			if (!attr->attisdropped) {
				targetAttrs = lappend_int(targetAttrs, attnum);
				elog(DEBUG1, "odbcPlanForeignModify %s", format_type_be(attr->atttypid));
			}
		}
	}
	else if (operation == CMD_UPDATE)
	{
		int			col;
#if ((PG_VERSION_NUM >= 130010 && PG_VERSION_NUM < 140000) || \
	 (PG_VERSION_NUM >= 140007 && PG_VERSION_NUM < 150000) || \
	  PG_VERSION_NUM >= 150002)
	  	/* get_rel_all_updated_cols is supported from pg 13.10, 14.7, 15.2 and 16 */
		RelOptInfo *rel = find_base_rel(root, resultRelation);
		Bitmapset  *allUpdatedCols = get_rel_all_updated_cols(root, rel);
#else
		Bitmapset  *allUpdatedCols = bms_union(rte->updatedCols, rte->extraUpdatedCols);
#endif

		col = -1;
		while ((col = bms_next_member(allUpdatedCols, col)) >= 0)
		{
			/* bit numbers are offset by FirstLowInvalidHeapAttributeNumber */
			AttrNumber	attno = col + FirstLowInvalidHeapAttributeNumber;

			Form_pg_attribute attr = TupleDescAttr(tupdesc, attno - 1);
			elog(DEBUG1, "attname %d %s", attno, attr->attname.data);

			if (attno <= InvalidAttrNumber) /* shouldn't happen */
				elog(ERROR, "system-column update is not supported");

			targetAttrs = lappend_int(targetAttrs, attno);
		}
	}

	// withCheckOptionList の作成 is 何
	/*
	 * Extract the relevant WITH CHECK OPTION list if any.
	 */
	if (plan->withCheckOptionLists)
		withCheckOptionList = (List *) list_nth(plan->withCheckOptionLists,
												subplan_index);

	/*
	 * Add all primary key attribute names to condAttr used in where clause of
	 * update
	 */
	if (operation == CMD_UPDATE || operation == CMD_DELETE)
	{
		for (i = 0; i < tupdesc->natts; ++i)
		{
			Form_pg_attribute att = TupleDescAttr(tupdesc, i);
			AttrNumber	attrno = att->attnum;
			List	   *options;
			ListCell   *option;

			/* look for the "key" option on this column */
			options = GetForeignColumnOptions(foreignTableId, attrno);
			foreach(option, options)
			{
				DefElem    *def = (DefElem *) lfirst(option);
				elog(DEBUG1, "column %d %d option %s", i, attrno, def->defname);
				if (IS_KEY_COLUMN(def))
				{
					elog(DEBUG1, "column %d %d is key column", i, attrno);
					condAttrs = lappend_int(condAttrs, attrno);
				}
			}
		}
	}

	/*
	 * Construct the SQL command string.
	 */
	switch (operation) {
	case CMD_INSERT:
		elog(DEBUG1, "INSERT");
		deparseInsertSql(&sql, rte, resultRelation, rel,
						 targetAttrs, doNothing,
						 withCheckOptionList, name_qualifier_char.data, quote_char.data);
		elog(DEBUG1, "sql %s", sql.data);
		break;
	case CMD_UPDATE:
		elog(DEBUG1, "UPDATE");
		deparseUpdateSql(&sql, rte, resultRelation, rel,
						 condAttrs, targetAttrs,
						 withCheckOptionList, name_qualifier_char.data, quote_char.data);
		elog(DEBUG1, "sql %s", sql.data);
		break;
	case CMD_DELETE:
		elog(DEBUG1, "DELETE");
		deparseDeleteSql(&sql, rte, resultRelation, rel,
						 condAttrs, name_qualifier_char.data, quote_char.data);
		elog(DEBUG1, "sql %s", sql.data);
		break;
	default:
		break;
	}

	table_close(rel, NoLock);

	elog(DEBUG1, "----> finishing %s", __func__);
	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwModifyPrivateIndex, above.
	 */
	return list_make2(makeString(sql.data), targetAttrs);
}

/*
 * deparse remote INSERT statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by WITH CHECK OPTION or RETURNING (if any),
 * which is returned to *retrieved_attrs.
 */
static void
deparseInsertSql(StringInfo buf, RangeTblEntry *rte,
				 Index rtindex, Relation rel,
				 List *targetAttrs, bool doNothing,
				 List *withCheckOptionList,
				 char *name_qualifier_char,
				 char *quote_char)
{
	AttrNumber	pindex;
	bool		first;
	ListCell   *lc;
	deparse_expr_cxt deparse_cxt;

	deparse_cxt.buf = buf;
	deparse_cxt.name_qualifier_char = name_qualifier_char;
	deparse_cxt.q_char = quote_char;

	appendStringInfoString(buf, "INSERT INTO ");
	odbc_deparse_relation(buf, rel, name_qualifier_char, quote_char);

	if (targetAttrs)
	{
		appendStringInfoChar(buf, '(');

		first = true;
		foreach(lc, targetAttrs)
		{
			int attnum = lfirst_int(lc);

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			odbc_deparse_column_ref(buf, rtindex, attnum, rte, false, &deparse_cxt);
		}

		appendStringInfoString(buf, ") VALUES (");

		pindex = 1;
		first = true;
		foreach(lc, targetAttrs)
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			appendStringInfo(buf, "?");
			pindex++;
		}

		appendStringInfoChar(buf, ')');
	}
	else
		appendStringInfoString(buf, " DEFAULT VALUES");

	if (doNothing)
		appendStringInfoString(buf, " ON CONFLICT DO NOTHING");
}

/*
 * deparse remote UPDATE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by WITH CHECK OPTION or RETURNING (if any),
 * which is returned to *retrieved_attrs.
 */
static void
deparseUpdateSql(StringInfo buf, RangeTblEntry *rte,
				 Index rtindex, Relation rel,
				 List *attname,
				 List *targetAttrs,
				 List *withCheckOptionList,
				 char *name_qualifier_char,
				 char *quote_char)
{
	bool		first;
	ListCell   *lc;
	deparse_expr_cxt deparse_cxt;

	deparse_cxt.buf = buf;
	deparse_cxt.name_qualifier_char = name_qualifier_char;
	deparse_cxt.q_char = quote_char;

	appendStringInfoString(buf, "UPDATE ");
	odbc_deparse_relation(buf, rel, name_qualifier_char, quote_char);
	appendStringInfoString(buf, " SET ");

	first = true;
	foreach(lc, targetAttrs)
	{
		int attnum = lfirst_int(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		odbc_deparse_column_ref(buf, rtindex, attnum, rte, false, &deparse_cxt);
		appendStringInfo(buf, " = ?");
	}

	// NULLでなければ、でいいのか? NULLでなく要素が0のパターンは?
	if (attname)
	{
		first = true;
		foreach(lc, attname)
		{
			int attnum = lfirst_int(lc);

			if (first)
				appendStringInfoString(buf, " WHERE ");
			else
				appendStringInfoString(buf, " AND ");
			first = false;

			odbc_deparse_column_ref(buf, rtindex, attnum, rte, false, &deparse_cxt);
			appendStringInfoString(buf, " = ?");
		}
	}
}

/*
 * deparse remote DELETE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned
 * to *retrieved_attrs.
 */
static void
deparseDeleteSql(StringInfo buf, RangeTblEntry *rte,
				 Index rtindex, Relation rel,
				 List *attname,
				 char *name_qualifier_char,
				 char *quote_char)
{
	bool		first;
	ListCell   *lc;
	deparse_expr_cxt deparse_cxt;

	deparse_cxt.buf = buf;
	deparse_cxt.name_qualifier_char = name_qualifier_char;
	deparse_cxt.q_char = quote_char;

	appendStringInfoString(buf, "DELETE FROM ");
	odbc_deparse_relation(buf, rel, name_qualifier_char, quote_char);

	// NULLでなければ、でいいのか? NULLでなく要素が0のパターンは?
	if (attname)
	{
		first = true;
		foreach(lc, attname)
		{
			int attnum = lfirst_int(lc);

			if (first)
				appendStringInfoString(buf, " WHERE ");
			else
				appendStringInfoString(buf, " AND ");
			first = false;

			odbc_deparse_column_ref(buf, rtindex, attnum, rte, false, &deparse_cxt);
			appendStringInfoString(buf, " = ?");
		}
	}
}

/*
 * odbcBeginForeignModify
 *		Begin an insert/update/delete operation on a foreign table
 */
static void
odbcBeginForeignModify(ModifyTableState *mtstate,
					   ResultRelInfo *resultRelInfo,
					   List *fdw_private,
					   int subplan_index,
					   int eflags)
{
	odbcFdwModifyState *fmstate;
	char *query;
	List *target_attrs;
	Plan *subplan = NULL;
	Relation rel;
	Oid foreignTableId = InvalidOid;
	ListCell *lc;

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case.  resultRelInfo->ri_FdwState
	 * stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/* Deconstruct fdw_private data. */
	query = strVal(list_nth(fdw_private, OdbcFdwModifyPrivateUpdateSql));
	target_attrs = (List *) list_nth(fdw_private, OdbcFdwModifyPrivateTargetAttnums);
#if (PG_VERSION_NUM >=140000)
	subplan = outerPlanState(mtstate)->plan;
#else
	subplan = mtstate->mt_plans[subplan_index]->plan;
#endif
	elog(DEBUG1, "subplan %d", subplan?subplan->plan_node_id:-1);
	/* Construct an execution state. */
	fmstate = create_foreign_modify(mtstate->ps.state,
									resultRelInfo,
								    mtstate->operation,
									subplan,
									query,
									target_attrs);
	resultRelInfo->ri_FdwState = fmstate;

	rel = resultRelInfo->ri_RelationDesc;
	foreignTableId = RelationGetRelid(rel);
	if (mtstate->operation == CMD_UPDATE || mtstate->operation == CMD_DELETE)
	{
		fmstate->junk_idx = palloc0(RelationGetDescr(rel)->natts * sizeof(AttrNumber));
		elog(DEBUG1, "subplan->targetlist %d", list_length(subplan->targetlist));
		foreach(lc, subplan->targetlist){
			TargetEntry *tle = lfirst(lc);

			/* Refer to PostgreSQL-13.0: L.477 of print_tl() in "nodes/print.c". */
			elog(DEBUG1, "%s", tle->resname ? tle->resname : "<null>");
		}
		for (int i = 0; i < RelationGetDescr(rel)->natts; ++i)
		{
			fmstate->junk_idx[i] =ExecFindJunkAttributeInTlist(subplan->targetlist, get_attname(foreignTableId, i+1, false));
			elog(DEBUG1, "ExecFindJunkAttributeInTlist %d %s %d", i, get_attname(foreignTableId, i+1, false), fmstate->junk_idx[i]);
		}
	}
	else
	{
		fmstate->junk_idx = NULL;
	}
}

/*
 * create_foreign_modify
 *		Construct an execution state of a foreign insert/update/delete
 *		operation
 */
static odbcFdwModifyState *
create_foreign_modify(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  CmdType operation,
					  Plan *subplan,
					  char *query,
					  List *target_attrs)
{
	SQLHENV env;
	SQLHDBC dbc;
	SQLRETURN ret;
	odbcFdwModifyState *fmstate;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	TupleDesc	tupdesc = RelationGetDescr(rel);
	AttrNumber	n_params;
	Oid			typefnoid;
	bool		isvarlena;
	ListCell   *lc;
#if PG_VERSION_NUM >= 160000
	Oid userid;
#endif

	elog_debug("%s", __func__);

	fmstate = (odbcFdwModifyState *) palloc0(sizeof(odbcFdwModifyState));
#if PG_VERSION_NUM >= 160000
	/* Identify which user to do the remote access as. */
	userid = ExecGetResultRelCheckAsUser(resultRelInfo, estate);
	odbcGetTableOptions(RelationGetRelid(rel), &fmstate->options, userid);
#else
	odbcGetTableOptions(RelationGetRelid(rel), &fmstate->options, InvalidOid);
#endif
	elog(DEBUG1, "remote table : %s", fmstate->options.table);

	odbc_connection(&fmstate->options, &env, &dbc);

	fmstate->env = env;
	fmstate->dbc = dbc;
	/* Allocate a statement handle */
	ret = SQLAllocHandle(SQL_HANDLE_STMT, fmstate->dbc, &fmstate->stmt);
	if(!SQL_SUCCEEDED(ret)){
		elog(ERROR, "failed alloc");
	}
	fmstate->query = query;
	fmstate->target_attrs = target_attrs;

	/* Create context for per-tuple temp workspace. */
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "odbc_fdw temporary data",
											  ALLOCSET_SMALL_SIZES);

	/* Prepare for output conversion of parameters used in prepared stmt. */
	n_params = list_length(fmstate->target_attrs) + 1;
	fmstate->p_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * n_params);
	fmstate->p_nums = 0;

	if (operation == CMD_INSERT || operation == CMD_UPDATE)
	{
		/* Set up for remaining transmittable parameters */
		foreach(lc, fmstate->target_attrs)
		{
			int			attnum = lfirst_int(lc);
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);

			Assert(!attr->attisdropped);

			elog(DEBUG1, "%s %s", __func__, format_type_be(attr->atttypid));

			getTypeOutputInfo(attr->atttypid, &typefnoid, &isvarlena);
			fmgr_info(typefnoid, &fmstate->p_flinfo[fmstate->p_nums]);
			fmstate->p_nums++;
		}
	}
	Assert(fmstate->p_nums <= n_params);

	return fmstate;
}

/*
 * odbcEndForeignModify
 *		Finish an insert/update/delete operation on a foreign table
 */
static void
odbcEndForeignModify(EState *estate,
					 ResultRelInfo *resultRelInfo)
{
	odbcFdwModifyState *fmstate = (odbcFdwModifyState *) resultRelInfo->ri_FdwState;

	/* If fmstate is NULL, we are in EXPLAIN; nothing to do */
	if (fmstate == NULL)
		return;

	/* Destroy the execution state */
	finish_foreign_modify(fmstate);
}

/*
 * finish_foreign_modify
 *		Release resources for a foreign insert/update/delete operation
 */
static void
finish_foreign_modify(odbcFdwModifyState *fmstate)
{
	Assert(fmstate != NULL);

	/* Release remote connection */
	if (fmstate->stmt)
	{
		SQLFreeHandle(SQL_HANDLE_STMT, fmstate->stmt);
		fmstate->stmt = NULL;
	}
	odbc_disconnection(&fmstate->env, &fmstate->dbc);
	fmstate->env = NULL;
	fmstate->dbc = NULL;
}

/*
 * odbcExecForeignInsert
 *		Insert one row into a foreign table
 */
static TupleTableSlot *
odbcExecForeignInsert(EState *estate,
						  ResultRelInfo *resultRelInfo,
						  TupleTableSlot *slot,
						  TupleTableSlot *planSlot)
{
	TupleTableSlot *rslot;
	PG_TRY();
	{
		rslot = execute_foreign_modify(estate, resultRelInfo, CMD_INSERT,
								   slot, planSlot);
	}
	PG_CATCH();
	{
		release_odbc_resources(resultRelInfo->ri_FdwState);
		PG_RE_THROW();
	}
	PG_END_TRY();

	return rslot;
}

/*
 * execute_foreign_modify
 *		Perform foreign-table modification as required, and fetch RETURNING
 *		result if any.  (This is the shared guts of odbcExecForeignInsert,
 *		odbcExecForeignUpdate, and odbcExecForeignDelete.)
 */
static TupleTableSlot *
execute_foreign_modify(EState *estate,
					   ResultRelInfo *resultRelInfo,
					   CmdType operation,
					   TupleTableSlot *slot,
					   TupleTableSlot *planSlot)
{
	odbcFdwModifyState *fmstate = (odbcFdwModifyState *)resultRelInfo->ri_FdwState;
	SQLLEN n_rows=0;
	SQLRETURN ret;

	elog_debug("%s", __func__);

	/* The operation should be INSERT, UPDATE, or DELETE */
	Assert(operation == CMD_INSERT ||
		   operation == CMD_UPDATE ||
		   operation == CMD_DELETE);

	bind_stmt_params(fmstate, slot);

	elog(DEBUG1, "%s %d", __func__, fmstate->p_nums);

	if(operation==CMD_DELETE)
	{
		Relation	rel = resultRelInfo->ri_RelationDesc;
		Oid			foreignTableId = RelationGetRelid(rel);
		bindJunkColumnValue(fmstate, slot, planSlot, foreignTableId, 0);
	}
	else if(operation==CMD_UPDATE)
	{
		Relation	rel = resultRelInfo->ri_RelationDesc;
		Oid			foreignTableId = RelationGetRelid(rel);
		bindJunkColumnValue(fmstate, slot, planSlot, foreignTableId, fmstate->p_nums);
	}

	ret = SQLExecDirect(fmstate->stmt, (SQLCHAR *) fmstate->query, SQL_NTS);
	if (!SQL_SUCCEEDED(ret))
		check_return(ret, "Executing ODBC query", fmstate->stmt, SQL_HANDLE_STMT);
	if (SQL_SUCCEEDED(ret))
	{
		SQLLEN rowCount;
		SQLRowCount(fmstate->stmt, &rowCount);
		elog(DEBUG1, "rowCount %ld", rowCount);
		n_rows = rowCount;
	}
	else
	{
		elog(WARNING, "Error modify");
	}

	MemoryContextReset(fmstate->temp_cxt);

	/*
	 * Return NULL if nothing was inserted/updated/deleted on the remote end
	 */
	return (n_rows > 0) ? slot : NULL;
}

/*
 * bind_stmt_params
 *		Bind parameter values to SQLHSTMT
 *
 * slot is slot to get remaining parameters from, or NULL if none
 *
 * Data is constructed in temp_cxt; caller should reset that after use.
 */
void
bind_stmt_params(odbcFdwModifyState *fmstate,
						 TupleTableSlot *slot)
{
	int			pindex = 0;
	MemoryContext previousCxt;
	TupleDesc tupdesc = slot->tts_tupleDescriptor;

	elog_debug("%s", __func__);

	previousCxt = MemoryContextSwitchTo(fmstate->temp_cxt);

	/* get following parameters from slot */
	if (slot != NULL && fmstate->target_attrs != NIL)
	{
		int			nestlevel;
		ListCell   *lc;

		nestlevel = odbc_set_transmission_modes();

		foreach(lc, fmstate->target_attrs)
		{
			int			attnum = lfirst_int(lc);
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
			Datum		value;
			bool		isnull;

			value = slot_getattr(slot, attnum, &isnull);
			if (isnull)
			{
				SQLLEN *cbValue = NULL;
				SQLRETURN ret;

				cbValue = palloc0(sizeof(SQLLEN));
				*cbValue = SQL_NULL_DATA;
				ret = SQLBindParameter(fmstate->stmt, pindex+1, SQL_PARAM_INPUT, SQL_C_DEFAULT, SQL_TYPE_NULL, 0, 0, NULL, 0, cbValue);
				check_return(ret, "BIND NULL", NULL, SQL_INVALID_HANDLE);
			}
			else
			{
				bind_stmt_param(fmstate, attr->atttypid, pindex, value);
			}
			pindex++;
		}

		odbc_reset_transmission_modes(nestlevel);
	}

	Assert(pindex == fmstate->p_nums);

	MemoryContextSwitchTo(previousCxt);

	return;
}

/*
 * bind_stmt_param
 *		Bind parameter value to SQLHSTMT
 *
 */
void bind_stmt_param(odbcFdwModifyState *fmstate, Oid type, int attnum, Datum value)
{
	attnum++;
	elog(DEBUG1, "odbc_fdw : %s %d type=%u ", __func__, attnum, type);

	switch(type)
	{
		case INT2OID:
			{
				int16 *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(int16));
				*dat = DatumGetInt16(value);
				elog(DEBUG1, "integer16 %d", *dat);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_SSHORT, SQL_SMALLINT, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND INT20ID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case INT4OID:
			{
				int32 *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(int32));
				*dat = DatumGetInt32(value);
				elog(DEBUG1, "integer32 %d", *dat);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND INT4OID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case INT8OID:
			{
				int64 *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(int64));
				*dat = DatumGetInt64(value);
				elog(DEBUG1, "integer64 %ld", *dat);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_SBIGINT, SQL_BIGINT, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND INT8OID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case FLOAT4OID:
			{
				float4 *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(float4));
				*dat = DatumGetFloat4(value);
				elog(DEBUG1, "real %lf", *dat);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_FLOAT, SQL_C_FLOAT, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND FLOAT4OID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case FLOAT8OID:
			{
				float8 *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(float8));
				*dat = DatumGetFloat8(value);
				elog(DEBUG1, "double %lf", *dat);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_DOUBLE, SQL_DOUBLE, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND FLOAT8OID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case NUMERICOID:
			{
				char* pgString = NULL;
				char* odbcString = NULL;
				Oid outputFunctionId = InvalidOid;
				bool typeVarLength = false;
				SQLLEN *cbValue = NULL;
				SQLRETURN ret;

				elog(DEBUG1, "character varying %ld", VARSIZE_ANY_EXHDR(value));

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				pgString = OidOutputFunctionCall(outputFunctionId, value);

				odbcString = palloc0(strlen(pgString)+1);
				strcpy(odbcString, pgString);

				cbValue = palloc0(sizeof(SQLLEN));
				*cbValue = SQL_NTS;
				elog(DEBUG1, "numeric %ld %s", strlen(odbcString), odbcString);
				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_NUMERIC, VARSIZE_ANY_EXHDR(value), 0, odbcString, VARSIZE_ANY_EXHDR(value)+1, cbValue);
				check_return(ret, "BIND NUMERICOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case BOOLOID:
			{
				bool *dat = NULL;
				SQLRETURN ret;

				dat = palloc0(sizeof(bool));
				*dat = DatumGetBool(value);
				elog(DEBUG1, "boolean %s", *dat?"true":"false");

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_BIT, SQL_BIT, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND BOOLOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case DATEOID:
			{
				DateADT pgDat;
				int year, month, day;
				DATE_STRUCT *odbcDate = NULL;
				SQLRETURN ret;

				pgDat = DatumGetDateADT(value);
				elog(DEBUG1, "date %d", pgDat);

				j2date(pgDat+POSTGRES_EPOCH_JDATE, &year, &month, &day);

				odbcDate = palloc0(sizeof(DATE_STRUCT));

				/* Because PostgreSQL calculate BC year start by 0, so
				 * we need to minus 1 year */
				if (year <= 0)
					year--;
				odbcDate->year = year;
				odbcDate->month = month;
				odbcDate->day = day;

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_TYPE_DATE, SQL_DATETIME, sizeof(DATE_STRUCT), 0, odbcDate, sizeof(DATE_STRUCT), NULL);
				check_return(ret, "BIND DATEOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case TIMEOID:
			{
				TimeADT *dat = NULL;
				struct pg_tm tt, *tm = &tt;
				fsec_t		fsec;
				SQLRETURN ret;

				elog(DEBUG1, "time");
				dat = palloc0(sizeof(TimeADT));
				*dat = DatumGetTimeADT(value);

				/* Same as time_out(), but forcing DateStyle */
				time2tm(*dat, tm, &fsec);

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_DOUBLE, SQL_DOUBLE, 0, 0, dat, 0, NULL);
				check_return(ret, "BIND TIMEOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case TIMESTAMPOID:
			{
				Timestamp pgDat;
				struct pg_tm tm;
				fsec_t fsec;
				SQL_TIMESTAMP_STRUCT *odbcTimestamp = NULL;
				SQLRETURN ret;

				elog(DEBUG1, "timestamp");
				pgDat = DatumGetTimestamp(value);

				/* Same as timestamp_out(), but forcing DateStyle */
				if (TIMESTAMP_NOT_FINITE(pgDat)) {
					elog(ERROR, "TIMESTAMP_NOT_FINITE");
				}
				else
				{
					timestamp2tm(pgDat, NULL, &tm, &fsec, NULL, NULL);
				}

				odbcTimestamp = palloc0(sizeof(SQL_TIMESTAMP_STRUCT));

				/* Because PostgreSQL calculate BC year start by 0, so
				 * we need to minus 1 year */
				if (tm.tm_year <= 0)
					odbcTimestamp->year = tm.tm_year - 1;
				else
					odbcTimestamp->year = tm.tm_year;
				odbcTimestamp->month = tm.tm_mon;
				odbcTimestamp->day = tm.tm_mday;
				odbcTimestamp->hour = tm.tm_hour;
				odbcTimestamp->minute = tm.tm_min;
				odbcTimestamp->second = tm.tm_sec;

				/*
				 * The resolution of PostgreSQL is microsecond (6 digits) but
				 * The resolution of timestamp struct is nanosecond (9 digits),
				 * so we need append 3 number zero at the end of fraction.
				 */
				odbcTimestamp->fraction = fsec * 1000;

				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_TYPE_TIMESTAMP, SQL_TYPE_TIMESTAMP, sizeof(SQL_TIMESTAMP_STRUCT), 0, odbcTimestamp, sizeof(SQL_TIMESTAMP_STRUCT), NULL);
				check_return(ret, "BIND TIMESTAMPOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
		case BPCHAROID:
		case VARCHAROID:
		case TEXTOID:
			{
				char* pgString = NULL;
				char* odbcString = NULL;
				Oid outputFunctionId = InvalidOid;
				bool typeVarLength = false;
				SQLLEN *cbValue = NULL;
				SQLRETURN ret;

				elog(DEBUG1, "character varying %ld", VARSIZE_ANY_EXHDR(value));

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				pgString = OidOutputFunctionCall(outputFunctionId, value);

				odbcString = palloc0(strlen(pgString)+1);
				strcpy(odbcString, pgString);

				cbValue = palloc0(sizeof(SQLLEN));
				*cbValue = SQL_NTS;
				elog(DEBUG1, "character varying %ld %s", strlen(odbcString), odbcString);
				ret = SQLBindParameter(fmstate->stmt, attnum, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR, VARSIZE_ANY_EXHDR(value), 0, odbcString, VARSIZE_ANY_EXHDR(value)+1, cbValue);
				check_return(ret, "BIND TEXTOID", NULL, SQL_INVALID_HANDLE);
				break;
			}
	}
}

/*
 * bindJunkColumnValue
 *		from sqlite_fdw
 *		key 'true' の列の値をbindする
 *
 */
static void
bindJunkColumnValue(odbcFdwModifyState *fmstate, TupleTableSlot *slot, TupleTableSlot *planSlot, Oid foreignTableId, int bindnum)
{
	int			i;
	Datum		value;
	Oid			typeoid;

	/* Bind where condition using junk column */
	for (i = 0; i < slot->tts_tupleDescriptor->natts; ++i)
	{
		Form_pg_attribute att = TupleDescAttr(slot->tts_tupleDescriptor, i);
		AttrNumber	attrno = att->attnum;
		List	   *options;
		ListCell   *option;

		elog(DEBUG1, "%s %02d:%s is %d", __func__, i, att->attname.data, fmstate->junk_idx[i]);
		/* look for the "key" option on this column */
		if (fmstate->junk_idx[i] == InvalidAttrNumber)
			continue;
		options = GetForeignColumnOptions(foreignTableId, attrno);
		foreach(option, options)
		{
			DefElem    *def = (DefElem *) lfirst(option);
			bool		is_null = false;

			if (IS_KEY_COLUMN(def))
			{
				/* Get the id that was passed up as a resjunk column */
				value = ExecGetJunkAttribute(planSlot, fmstate->junk_idx[i], &is_null);
				typeoid = att->atttypid;

				if (is_null)
					elog(ERROR, "Value of key column is NULL");

				/* Bind qual */
				bind_stmt_param(fmstate, typeoid, bindnum, value);
				bindnum++;
			}
		}

	}
}

/*
 * Force assorted GUC parameters to settings that ensure that we'll output
 * data values in a form that is unambiguous to the remote server.
 *
 * This is rather expensive and annoying to do once per row, but there's
 * little choice if we want to be sure values are transmitted accurately;
 * we can't leave the settings in place between rows for fear of affecting
 * user-visible computations.
 *
 * We use the equivalent of a function SET option to allow the settings to
 * persist only until the caller calls odbc_reset_transmission_modes().  If an
 * error is thrown in between, guc.c will take care of undoing the settings.
 *
 * The return value is the nestlevel that must be passed to
 * odbc_reset_transmission_modes() to undo things.
 */
int
odbc_set_transmission_modes(void)
{
	int			nestlevel = NewGUCNestLevel();

	/*
	 * The values set here should match what pg_dump does.  See also
	 * configure_remote_session in connection.c.
	 */
	if (DateStyle != USE_ISO_DATES)
		(void) set_config_option("datestyle", "ISO",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (IntervalStyle != INTSTYLE_POSTGRES)
		(void) set_config_option("intervalstyle", "postgres",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (extra_float_digits < 3)
		(void) set_config_option("extra_float_digits", "3",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	/*
	 * In addition force restrictive search_path, in case there are any
	 * regproc or similar constants to be printed.
	 */
	(void) set_config_option("search_path", "pg_catalog",
							 PGC_USERSET, PGC_S_SESSION,
							 GUC_ACTION_SAVE, true, 0, false);

	return nestlevel;
}

/*
 * Undo the effects of odbc_set_transmission_modes().
 */
void
odbc_reset_transmission_modes(int nestlevel)
{
	AtEOXact_GUC(true, nestlevel);
}

/*
 * release_odbc_resources
 *      release resources related ODBC connections safely.
 */
static void
release_odbc_resources(odbcFdwModifyState *fmstate)
{
	SQLRETURN ret;

	if(fmstate->stmt)
	{
		ret = SQLFreeHandle(SQL_HANDLE_STMT, fmstate->stmt);
		if (!SQL_SUCCEEDED(ret))
		{
			elog(DEBUG1, "error free hSTMT %d", ret);
		}
		fmstate->stmt = NULL;
	}

	if(fmstate->dbc)
	{
		ret = SQLDisconnect(fmstate->dbc);
		if (!SQL_SUCCEEDED(ret))
		{
			elog(DEBUG1, "error close hDBC %d", ret);
		}
		ret = SQLFreeHandle(SQL_HANDLE_DBC, fmstate->dbc);
		if (!SQL_SUCCEEDED(ret))
		{
			elog(DEBUG1, "error free hDBC %d", ret);
		}
		fmstate->dbc = NULL;
	}

	if(fmstate->env)
	{
		ret = SQLFreeHandle(SQL_HANDLE_ENV, fmstate->env);
		if (!SQL_SUCCEEDED(ret))
		{
			elog(DEBUG1, "error free hENV %d", ret);
		}
		fmstate->env = NULL;
	}
}

/*
 * odbcAddForeignUpdateTargets: Add column(s) needed for update/delete on a foreign table,
 * we are using first column as row identification column, so we are adding that into target
 * list.
 */

#if (PG_VERSION_NUM < 140000)
static void
odbcAddForeignUpdateTargets(Query *parsetree, RangeTblEntry *target_rte,
							Relation target_relation)
#else
static void
odbcAddForeignUpdateTargets(PlannerInfo *root, Index rtindex,
							RangeTblEntry *target_rte, Relation target_relation)
#endif
{
	Oid			relid = RelationGetRelid(target_relation);
	TupleDesc	tupdesc = target_relation->rd_att;
	int			i;
	bool		has_key = false;

	/* loop through all columns of the foreign table */
	for (i = 0; i < tupdesc->natts; ++i)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);
		AttrNumber	attrno = att->attnum;
		List	   *options;
		ListCell   *option;

		/* look for the "key" option on this column */
		options = GetForeignColumnOptions(relid, attrno);
		foreach(option, options)
		{
			DefElem    *def = (DefElem *) lfirst(option);

			/* if "key" is set, add a resjunk for this column */
			if (IS_KEY_COLUMN(def))
			{
				Var		   *var;
				const char *attrname;
#if (PG_VERSION_NUM < 140000)
				TargetEntry *tle;
				Index rtindex = parsetree->resultRelation;
#endif
				/* Make a Var representing the desired value */
				var = makeVar(rtindex,
							  attrno,
							  att->atttypid,
							  att->atttypmod,
							  att->attcollation,
							  0);
				/* Get name of the row identifier column */
				attrname = NameStr(att->attname);
#if (PG_VERSION_NUM < 140000)
				/* Wrap it in a resjunk TLE with the right name ... */
				tle = makeTargetEntry((Expr *) var,
									  list_length(parsetree->targetList) + 1,
									  pstrdup(attrname),
									  true);
				/* ... and add it to the query's targetlist */
				parsetree->targetList = lappend(parsetree->targetList, tle);
#else
				add_row_identity_var(root, var, rtindex, attrname);
#endif
				has_key = true;
			}
			else if (strcmp(def->defname, "key") == 0)
			{
				elog(ERROR, "impossible column option \"%s\"", def->defname);
			}
		}
	}

	if (!has_key)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("no primary key column specified for foreign table"),
				 errdetail("For UPDATE or DELETE, at least one foreign table column must be marked as primary key column."),
				 errhint("Set the option \"%s\" on the columns that belong to the primary key.", "key")));
}

/*
 * odbcExecForeignUpdate
 *		Update one row in a foreign table
 */
static TupleTableSlot *
odbcExecForeignUpdate(EState *estate,
						  ResultRelInfo *resultRelInfo,
						  TupleTableSlot *slot,
						  TupleTableSlot *planSlot)
{
	TupleTableSlot *rslot;
	PG_TRY();
	{
		rslot = execute_foreign_modify(estate, resultRelInfo, CMD_UPDATE, slot, planSlot);
	}
	PG_CATCH();
	{
		release_odbc_resources(resultRelInfo->ri_FdwState);
		PG_RE_THROW();
	}
	PG_END_TRY();

	return rslot;
}

/*
 * odbcExecForeignDelete
 *		Delete one row from a foreign table
 */
static TupleTableSlot *
odbcExecForeignDelete(EState *estate,
						  ResultRelInfo *resultRelInfo,
						  TupleTableSlot *slot,
						  TupleTableSlot *planSlot)
{
	TupleTableSlot *rslot;
	PG_TRY();
	{
		rslot = execute_foreign_modify(estate, resultRelInfo, CMD_DELETE, slot, planSlot);
	}
	PG_CATCH();
	{
		release_odbc_resources(resultRelInfo->ri_FdwState);
		PG_RE_THROW();
	}
	PG_END_TRY();

	return rslot;
}

/*
 * odbcIsForeignRelUpdatable
 *		Determine whether a foreign table supports INSERT, UPDATE and/or
 *		DELETE.
 */
static int
odbcIsForeignRelUpdatable(Relation rel)
{
	bool		updatable;
	ForeignTable *table;
	ForeignServer *server;
	ListCell   *lc;

	/*
	 * By default, all odbc_fdw foreign tables are assumed updatable. This
	 * can be overridden by a per-server setting, which in turn can be
	 * overridden by a per-table setting.
	 */
	updatable = true;

	table = GetForeignTable(RelationGetRelid(rel));
	server = GetForeignServer(table->serverid);

	foreach(lc, server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "updatable") == 0)
			updatable = defGetBoolean(def);
	}
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "updatable") == 0)
			updatable = defGetBoolean(def);
	}

	/*
	 * Currently "updatable" means support for INSERT, UPDATE and DELETE.
	 */
	return updatable ?
		(1 << CMD_INSERT) | (1 << CMD_UPDATE) | (1 << CMD_DELETE) : 0;
}

/*
 * odbcExplainForeignModify
 *		Produce extra output for EXPLAIN of a ModifyTable on a foreign table
 */
static void
odbcExplainForeignModify(ModifyTableState *mtstate,
							 ResultRelInfo *rinfo,
							 List *fdw_private,
							 int subplan_index,
							 ExplainState *es)
{
	if (es->verbose)
	{
		char *sql = strVal(list_nth(fdw_private, OdbcFdwModifyPrivateUpdateSql));

		ExplainPropertyText("Remote SQL", sql, es);
	}
}

/*
 * odbcBeginForeignInsert
 *         Prepare for an insert operation triggered by partition routing
 *         or COPY FROM.
 *
 * This is not yet supported, so raise an error.
 */
static void
odbcBeginForeignInsert(ModifyTableState *mtstate,
                        ResultRelInfo *resultRelInfo)
{
    ereport(ERROR,
            (errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
             errmsg("COPY and foreign partition routing not supported in odbc_fdw")));
}

/*
 * odbcEndForeignInsert
 *         BeginForeignInsert() is not yet implemented, hence we do not
 *         have anything to cleanup as of now. We throw an error here just
 *         to make sure when we do that we do not forget to cleanup
 *         resources.
 */
static void
odbcEndForeignInsert(EState *estate, ResultRelInfo *resultRelInfo)
{
    ereport(ERROR,
            (errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
             errmsg("COPY and foreign partition routing not supported in odbc_fdw")));
}

/*
 * Compare input string_value with the string get from remote database
 */
static SQLRETURN
validate_retrieved_string(SQLHSTMT stmt, SQLUSMALLINT ColumnNumber, const char *string_value, bool *is_mapped, bool *is_empty_retrieved_string)
{
	SQLRETURN	ret;
	SQLLEN		indicator;
	SQLCHAR	   *result = (SQLCHAR *) palloc0(sizeof(SQLCHAR) * MAXIMUM_BUFFER_SIZE);

	*is_mapped = false;
	*is_empty_retrieved_string = false;
	ret = SQLGetData(stmt, ColumnNumber, SQL_C_CHAR, result, MAXIMUM_SCHEMA_NAME_LEN, &indicator);

	if (ret == SQL_SUCCESS)
	{
		if (is_blank_string((char *)result))
		{
			*is_empty_retrieved_string = true;
		}
		else if (strcmp((char *)result, string_value) == 0)
		{
			*is_mapped = true;
		}
	}
	pfree(result);
	return ret;
}

/*
 * Assess whether the aggregation, grouping and having operations can be
 * pushed down to the foreign server.  As a side effect, save information we
 * obtain in this function to OdbcFdwRelationInfo of the input relation.
 */
static bool
odbc_foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel, Node *havingQual)
{
	Query	   *query = root->parse;
	OdbcFdwRelationInfo *fpinfo = (OdbcFdwRelationInfo *) grouped_rel->fdw_private;
	PathTarget *grouping_target;
	OdbcFdwRelationInfo *ofpinfo;
	ListCell   *lc;
	int			i;
	List	   *tlist = NIL;

	/* We currently don't support pushing Grouping Sets. */
	if (query->groupingSets)
		return false;

	/* Get the fpinfo of the underlying scan relation. */
	ofpinfo = (OdbcFdwRelationInfo *) fpinfo->outerrel->fdw_private;

	/*
	 * If underlying scan relation has any local conditions, those conditions
	 * are required to be applied before performing aggregation.  Hence the
	 * aggregate cannot be pushed down.
	 */
	if (ofpinfo->local_conds)
		return false;

	/*
	 * The targetlist expected from this node and the targetlist pushed down
	 * to the foreign server may be different. The latter requires
	 * sortgrouprefs to be set to push down GROUP BY clause, but should not
	 * have those arising from ORDER BY clause. These sortgrouprefs may be
	 * different from those in the plan's targetlist. Use a copy of path
	 * target to record the new sortgrouprefs.
	 */
	grouping_target = grouped_rel->reltarget;

	/*
	 * Examine grouping expressions, as well as other expressions we'd need to
	 * compute, and check whether they are safe to push down to the foreign
	 * server.  All GROUP BY expressions will be part of the grouping target
	 * and thus there is no need to search for them separately.  Add grouping
	 * expressions into target list which will be passed to foreign server.
	 *
	 * A tricky fine point is that we must not put any expression into the
	 * target list that is just a foreign param (that is, something that
	 * deparse.c would conclude has to be sent to the foreign server).  If we
	 * do, the expression will also appear in the fdw_exprs list of the plan
	 * node, and setrefs.c will get confused and decide that the fdw_exprs
	 * entry is actually a reference to the fdw_scan_tlist entry, resulting in
	 * a broken plan.  Somewhat oddly, it's OK if the expression contains such
	 * a node, as long as it's not at top level; then no match is possible.
	 */
	i = 0;

	foreach(lc, grouping_target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		ListCell   *l;

		/*
		 * Non-grouping expression we need to compute.  Can we ship it as-is
		 * to the foreign server?
		 */
		if (odbc_is_foreign_expr(root, grouped_rel, expr))
		{
			/*
			 * Yes, so add to tlist as-is; OK to suppress duplicates
			 */
			tlist = add_to_flat_tlist(tlist, list_make1(expr));
		}
		else
		{
			/*
			 * Not pushable as a whole; extract its Vars and aggregates
			 */
			List	   *aggvars;

			aggvars = pull_var_clause((Node *) expr,
									  PVC_INCLUDE_AGGREGATES);

			/*
			 * If any aggregate expression is not shippable, then we cannot
			 * push down aggregation to the foreign server.  (We don't have to
			 * check is_foreign_param, since that certainly won't return true
			 * for any such expression.)
			 */
			if (!odbc_is_foreign_expr(root, grouped_rel, (Expr *) aggvars))
				return false;

			/*
			 * Add aggregates, if any, into the targetlist. Plain Vars outside
			 * an aggregate can be ignored, because they should be either same
			 * as some GROUP BY column or part of some GROUP BY expression. In
			 * either case, they are already part of the targetlist and thus
			 * no need to add them again.  In fact including plain Vars in the
			 * tlist when they do not match a GROUP BY column would cause the
			 * foreign server to complain that the shipped query is invalid.
			 */
			foreach(l, aggvars)
			{
				Expr	   *aggref = (Expr *) lfirst(l);

				if (IsA(aggref, Aggref))
					tlist = add_to_flat_tlist(tlist, list_make1(aggref));
			}
		}

		i++;
	}

	/*
	 * Classify the pushable and non-pushable HAVING clauses and save them in
	 * remote_conds and local_conds of the grouped rel's fpinfo.
	 */
	if (havingQual)
	{
		foreach(lc, (List *) havingQual)
		{
			Expr	   *expr = (Expr *) lfirst(lc);
			RestrictInfo *rinfo;

			/*
			 * Currently, the core code doesn't wrap havingQuals in
			 * RestrictInfos, so we must make our own.
			 */
			Assert(!IsA(expr, RestrictInfo));
			rinfo = make_restrictinfo(root,
									  expr,
									  true,
									  false,
									  false,
#if PG_VERSION_NUM  >= 160000
									  false,
#endif
									  root->qual_security_level,
									  grouped_rel->relids,
									  NULL,
									  NULL);
			/*
			 * Currently, ODBC_fdw does not support push down HAVING clause,
			 * so, add all havingQuals to local_conds
			 */
			fpinfo->local_conds = lappend(fpinfo->local_conds, rinfo);
		}
	}

	/*
	 * If there are any local conditions, pull Vars and aggregates from it and
	 * check whether they are safe to pushdown or not.
	 */
	if (fpinfo->local_conds)
	{
		List	   *aggvars = NIL;
		ListCell   *lc;

		foreach(lc, fpinfo->local_conds)
		{
			RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

			aggvars = list_concat(aggvars,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_INCLUDE_AGGREGATES));
		}

		foreach(lc, aggvars)
		{
			Expr	   *expr = (Expr *) lfirst(lc);

			/*
			 * If aggregates within local conditions are not safe to push
			 * down, then we cannot push down the query. Vars are already part
			 * of GROUP BY clause which are checked above, so no need to
			 * access them again here.  Again, we need not check
			 * is_foreign_param for a foreign aggregate.
			 */
			if (IsA(expr, Aggref))
			{
				if (!odbc_is_foreign_expr(root, grouped_rel, expr))
					return false;

				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
		}
	}

	/* Store generated targetlist */
	fpinfo->grouped_tlist = tlist;

	/* Safe to pushdown */
	fpinfo->pushdown_safe = true;

	return true;
}

/*
 * odbcGetForeignUpperPaths
 *		Add paths for post-join operations like aggregation, grouping etc. if
 *		corresponding operations are safe to push down.
 */
static void
odbcGetForeignUpperPaths(PlannerInfo *root, UpperRelationKind stage,
						  RelOptInfo *input_rel, RelOptInfo *output_rel,
						  void *extra)
{
	OdbcFdwRelationInfo *fpinfo;

	/*
	 * If input rel is not safe to pushdown, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	if (!input_rel->fdw_private ||
		!((OdbcFdwRelationInfo *) input_rel->fdw_private)->pushdown_safe)
		return;

	/* Ignore stages we don't support; and skip any duplicate calls. */
	if (stage != UPPERREL_GROUP_AGG ||
		output_rel->fdw_private)
		return;

	fpinfo = (OdbcFdwRelationInfo *) palloc0(sizeof(OdbcFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	output_rel->fdw_private = fpinfo;

	switch (stage)
	{
		case UPPERREL_GROUP_AGG:
			odbc_add_foreign_grouping_paths(root, input_rel, output_rel,
									   (GroupPathExtraData *) extra);
			break;
		default:
			elog(ERROR, "unexpected upper relation: %d", (int) stage);
			break;
	}
}

/*
 * odbc_add_foreign_grouping_paths Add foreign path for grouping and/or
 * aggregation.
 *
 * Given input_rel represents the underlying scan.  The paths are added to
 * the given grouped_rel.
 */
static void
odbc_add_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
								RelOptInfo *grouped_rel, GroupPathExtraData *extra)
{
	Query	   *parse = root->parse;
	OdbcFdwRelationInfo *ifpinfo = input_rel->fdw_private;
	OdbcFdwRelationInfo *fpinfo = grouped_rel->fdw_private;
	ForeignPath *grouppath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Nothing to be done, if there is no aggregation required. Odbc_fdw does not
	 * support GROUP BY, GROUPING SET so also return when there are those clauses.
	 */
	if (parse->groupClause ||
		parse->groupingSets ||
		!parse->hasAggs)
		return;

#if (PG_VERSION_NUM >= 110000)
	Assert(extra->patype == PARTITIONWISE_AGGREGATE_NONE ||
		   extra->patype == PARTITIONWISE_AGGREGATE_FULL);
#endif

	/* save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;
	fpinfo->q_char = ifpinfo->q_char;
	fpinfo->name_qualifier_char = ifpinfo->name_qualifier_char;

	/*
	 * Assess if it is safe to push down aggregation and grouping.
	 *
	 * Use HAVING qual from extra. In case of child partition, it will have
	 * translated Vars.
	 */
	if (!odbc_foreign_grouping_ok(root, grouped_rel, extra->havingQual))
		return;

	/* Use small cost to push down aggregate always */
	rows = width = startup_cost = total_cost = 1;

	/* Create and add foreign path to the grouping relation. */
#if (PG_VERSION_NUM >= 120000)
	grouppath = create_foreign_upper_path(root,
										  grouped_rel,
										  grouped_rel->reltarget,
										  rows,
										  startup_cost,
										  total_cost,
										  NIL,	/* no pathkeys */
										  NULL,
										  NIL); /* no fdw_private */
#else
	grouppath = create_foreignscan_path(root,
										grouped_rel,
										root->upper_targets[UPPERREL_GROUP_AGG],
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										NULL,	/* no required_outer */
										NULL,
										NIL);	/* no fdw_private */
#endif

	/* Add generated path into grouped_rel by add_path(). */
	add_path(grouped_rel, (Path *) grouppath);
}
