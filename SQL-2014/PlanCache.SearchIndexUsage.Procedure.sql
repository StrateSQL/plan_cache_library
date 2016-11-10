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
 @IndexName VARCHAR(512)
)
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SET @IndexName = QUOTENAME(REPLACE(REPLACE(@IndexName, '[', ''), ']', ''));
	
    WITH XMLNAMESPACES  (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
		,[IndexSearch]
		AS (
			SELECT [qp].[query_plan],
				[cp].[plan_handle],
				[cp].[usecounts],
				[ix].[query]('.') AS [StmtSimple]
			FROM [sys].[dm_exec_cached_plans] [cp]
				OUTER APPLY [sys].[dm_exec_query_plan]([cp].[plan_handle]) [qp]   
				CROSS APPLY [qp].[query_plan].[nodes]('//StmtSimple') AS [p]([ix])
			WHERE [qp].[query_plan].[exist]('//Object[@Index = sql:variable("@IndexName")]') = 1
		)
		SELECT [ixs].[StmtSimple].[value]('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS [sql_text],
			[obj].[value]('@Database','sysname') AS [database_name],
			[obj].[value]('@Schema','sysname') AS [schema_name],
			[obj].[value]('@Table','sysname') AS [table_name],
			[obj].[value]('@Index','sysname') AS [index_name],
			[ixs].[query_plan],
			[ixs].[usecounts]
		FROM [IndexSearch] [ixs]
			CROSS APPLY [StmtSimple].[nodes]('//Object') AS [o]([obj])
		WHERE [obj].[exist]('//Object[@Index = sql:variable("@IndexName")]') = 1 
		OPTION (RECOMPILE);
END;
GO

EXEC PlanCache.SearchObjectUsage 'PK__syspolic__72E12F1A62458BBE'