IF EXISTS ( SELECT  *
            FROM    [sys].[objects] AS [O]
            WHERE   [object_id] = OBJECT_ID('Utility.CachedPlanSearch') )
    DROP FUNCTION [Utility].[CachedPlanSearch];
GO
/* ==============================================================================================
Function: [Utility].[CachedPlanSearch]
Author: Jason Strate
Date: June 1, 2009

Synopsis:
	Searches cache for all occurances of a plan based on an
	procedure and or database name. Results assumes that average
	execution time for returned results are less than 24 hours.

Example:
	SELECT * FROM[Utility].[CachedPlanSearch] ('msdb', 'dbo', NULL)
	ORDER BY [avg_elapsed_time] DESC
	OPTION (RECOMPILE)

=================================================================================================
Revision History:

Date		Author			Description
-------------------------------------------------------------------------------------------------
2016-11-10	JStrate			Converted from procedure to function
============================================================================================== */
CREATE FUNCTION [Utility].[CachedPlanSearch]
(
 @DatabaseName sysname = NULL ,
 @SchemaName sysname = NULL ,
 @ObjectName sysname = NULL 
)
RETURNS TABLE
AS
RETURN
WITH    [cteExecInfo]
          AS (SELECT    DB_NAME([st].[dbid]) AS [database_name] ,
						OBJECT_SCHEMA_NAME([st].[objectid], [st].[dbid]) AS [object_schema_name] ,
                        OBJECT_NAME([st].[objectid], [st].[dbid]) AS [object_name] ,
                        [cp].[usecounts] -- Use in place of qs.execution_count for whole plan count
                        ,
                        CAST(SUM([qs].[total_worker_time]) / ([cp].[usecounts] * 1.) AS DECIMAL(12, 2)) AS [avg_cpu_time] ,
                        CAST(SUM([qs].[total_logical_reads] + [qs].[total_logical_writes]) / ([cp].[usecounts] * 1.) AS DECIMAL(12, 2)) AS [avg_io] ,
                        SUM([qs].[total_elapsed_time]) / ([cp].[usecounts]) / 1000 AS [avg_elapsed_time_ms] ,
                        [st].[text] AS [sql_text] ,
                        [qs].[plan_handle]
              FROM      [sys].[dm_exec_query_stats] [qs]
              INNER JOIN [sys].[dm_exec_cached_plans] [cp] ON [qs].[plan_handle] = [cp].[plan_handle]
              CROSS APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) [st]
              WHERE     (DB_NAME([st].[dbid]) = @DatabaseName
                        OR NULLIF(@DatabaseName, '') IS NULL
                        )
						AND (OBJECT_SCHEMA_NAME([st].[objectid], [st].[dbid]) = @SchemaName
                        OR NULLIF(@SchemaName, '') IS NULL
                        )
                        AND (OBJECT_NAME([st].[objectid], [st].[dbid]) = @ObjectName
                        OR NULLIF(@ObjectName, '') IS NULL
                        )
              GROUP BY  [st].[dbid] ,
                        [st].[objectid] ,
                        [cp].[usecounts] ,
                        [st].[text] ,
                        [qs].[plan_handle]
             )
    SELECT  [cte].[database_name] ,
			Cte.[object_schema_name],
            [cte].[object_name] ,
            [cte].[usecounts] ,
            [cte].[avg_cpu_time] ,
            [cte].[avg_io] ,
            CONVERT(VARCHAR, DATEADD(ms, [cte].[avg_elapsed_time_ms], 0), 114) AS [avg_elapsed_time] ,
            [qp].[query_plan] ,
            [cte].[sql_text]
    FROM    [cteExecInfo] [cte]
    OUTER APPLY [sys].[dm_exec_query_plan]([cte].[plan_handle]) [qp]
GO

