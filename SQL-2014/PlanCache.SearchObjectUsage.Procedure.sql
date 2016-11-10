IF NOT EXISTS ( SELECT  *
                FROM    [sys].[schemas] AS [S]
                WHERE   [S].[name] = 'PlanCache' )
    EXEC('CREATE SCHEMA PlanCache');
GO

IF OBJECT_ID('PlanCache.SearchObjectUsage') IS NULL
    EXEC('CREATE PROCEDURE PlanCache.SearchObjectUsage AS PRINT 1');
GO

ALTER PROCEDURE [PlanCache].[SearchObjectUsage]
/* ==============================================================================================
 Author:		jstrate	
 Creation Date: 11/10/2016
 Description:   

Changed By      ChangeDate  Risk    Description
--------------  ----------  ------  -------------------------------------------------------------

-------------------------------------------------------------------------------------------------

Example:
    EXEC PlanCache.SearchObjectUsage 'PK__syspolic__72E12F1A62458BBE'

============================================================================================== */
(
 @SchemaName VARCHAR(512) = 'dbo' ,
 @TableName VARCHAR(512)
)
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @TableName IS NULL
    BEGIN	
        RAISERROR('The parameter @TableName cannot be NULL', 16, 1);
        RETURN;
    END;	

    SET @SchemaName = QUOTENAME(REPLACE(REPLACE(COALESCE(@SchemaName, 'dbo'), '[', ''), ']', ''));
    SET @TableName = QUOTENAME(REPLACE(REPLACE(@TableName, '[', ''), ']', ''));
	
    WITH XMLNAMESPACES  (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
		,[IndexSearch]
		AS (
			SELECT 
				OBJECT_SCHEMA_NAME([qp].[objectid], [qp].[dbid]) AS [schema_name],
				OBJECT_NAME([qp].[objectid], [qp].[dbid]) AS [object_name],
				[qp].[query_plan],
				[cp].[plan_handle],
				[cp].[usecounts] AS [use_counts],
				[ix].[query]('.') AS [stmt_simple]
			FROM [sys].[dm_exec_cached_plans] [cp]
				OUTER APPLY [sys].[dm_exec_query_plan]([cp].[plan_handle]) [qp]   
				CROSS APPLY [qp].[query_plan].[nodes]('//StmtSimple') AS [p]([ix])
			WHERE [qp].[query_plan].[exist]('//Object[@Schema = sql:variable("@SchemaName")]') = 1
			AND [qp].[query_plan].[exist]('//Object[@Table = sql:variable("@TableName")]') = 1
		)
		SELECT [ixs].[schema_name],
			[ixs].[object_name],
			[ixs].[stmt_simple].[value]('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS [sql_text],
			[obj].[value]('@Database','sysname') AS [database_name],
			[obj].[value]('@Schema','sysname') AS [schema_name],
			[obj].[value]('@Table','sysname') AS [table_name],
			[obj].[value]('@Index','sysname') AS [index_name],
			[ixs].[query_plan],
			[ixs].[use_counts]
		FROM [IndexSearch] [ixs]
			CROSS APPLY [stmt_simple].[nodes]('//Object') AS [o]([obj])
		WHERE [obj].[exist]('//Object[@Schema = sql:variable("@SchemaName")]') = 1 
		AND [obj].[exist]('//Object[@Table = sql:variable("@TableName")]') = 1
		OPTION (RECOMPILE);
END;
GO