-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
USE ReportServer
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sandi Pounder
-- Create date: 04/23/2018
-- Description:	Retrieve raw data for Snowsports daily reporting
-- =============================================
ALTER PROCEDURE [dbo].[_ss_GetSnowsportsDailyData3] 
	-- Add the parameters for the stored procedure here
	( 
    @pdtStart           DATETIME,       -- Start Date
    @pdtEnd             DATETIME,       -- End Date
    @pvcItem            VARCHAR(MAX)    -- Comma-delimited list of items
 )

as
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

set transaction isolation level read uncommitted

-- =================================================
-- Declare and set variables for individual days within
-- reporting range
declare @dayVar		DATETIME
declare @dayVar_txt	VARCHAR(100)

--set 	@dayVar = @pdtStart
--set		@dayVar_txt	= RIGHT(CAST(CONVERT(DATE,@dayVar) AS VARCHAR),5) + ' ' + DATENAME(dw, @dayVar)
declare	@cnt 	INT = 0
	

-- =============================================

if object_id('tempdb..#DCI') is not null drop table #DCI
create table #DCI
(
      DCI          varchar(100) collate database_default,
      dciDepartment   char(10) collate database_default,
      dciCategory     char(10) collate database_default,
      dciItem         char(10) collate database_default
)
insert into #DCI
select Item, 
       left(Item,10), 
       substring(Item,11,10), 
       substring(Item,21,10)
  from SiriusSQL.dbo.siriusfn_SplitMultiValue(@pvcItem, ',')
-- =============================================

-- =============================================
;
IF OBJECT_ID('tempdb..#DaysAll') IS NOT NULL DROP TABLE #DaysAll
CREATE TABLE #DaysAll
(
		source VARCHAR(20), today DATETIME, range_begin DATETIME, range_end DATETIME, 
		[Day] VARCHAR(100), mod_department CHAR(10), mod_category CHAR(10), mod_item CHAR(10),  
		mod_startdate DATETIME, mod_trans VARCHAR(20), 
		t_department CHAR(10), t_category CHAR(10), t_item CHAR(10), quantity INT, [cluster] CHAR(10),
		start_date DATETIME, end_date DATETIME, Trans_Date_Time DATETIME, t_quantity INTEGER,
		DayDate DATETIME
)
-- ==============================================


WHILE @cnt < 8
	BEGIN 
		SET 	@dayVar = @pdtStart + @cnt		
		SET		@dayVar_txt	= RIGHT(CAST(CONVERT(DATE,@dayVar) AS VARCHAR),5) + ' ' + DATENAME(dw, @dayVar)
		;
		-- Use a cte inside while loop to iterate for each day in the range and 
		-- include txt label for that day in 'Day' column;
		-- retrieve records (from transact table and from tr_save table) 
		-- for which that day is within the item's Start/End range
		WITH
		cteLessonsDay
		AS
		(		   
			SELECT 
				'transact' as source, GETDATE() as today, @pdtStart as range_begin,		
				(@pdtStart + 9) as range_end, @dayVar_txt as 'Day',
				t1.department as mod_department, t1.category as mod_category, t1.item as mod_item,  
				t1.start_date as mod_startdate, t1.trans_no as mod_trans,
				t2.department AS t_department, t2.category AS t_category, t2.item AS t_item, t2.quantity, t2.cluster,
				t2.start_date, t2.end_date, t2.Date_Time, CAST(t2.quantity AS INTEGER) AS t_quantity,
				@dayVar AS 'DayDate'
			FROM SiriusSQL.dbo.transact t1
				JOIN SiriusSQL.dbo.transact t2
				ON t1.mastertran = t2.trans_no
			WHERE t2.department IN ('A-ASNOSP','C-CSNOSP') 
				AND CONVERT(DATE,t2.end_date) >= CONVERT(DATE,@dayVar)
				AND CONVERT(DATE,t2.start_date) <= CONVERT(DATE,@dayVar)
				AND t1.category IN ('A-SSMODS', 'C-JEMODS') 
				
			
			UNION

			SELECT 
				'tr_save' as source, GETDATE() as today, @pdtStart as range_begin,		
				(@pdtStart + 9) as range_end, @dayVar_txt as 'Day',
				t1.department as mod_department, t1.category as mod_category, t1.item as mod_item,  
				t1.start_date as mod_startdate, t1.trans_no as mod_trans,
				t2.department AS t_department, t2.category AS t_category, t2.item AS t_item, t2.quantity, t2.cluster,
				t2.start_date, t2.end_date, t2.Date_Time, CAST(t2.quantity AS INTEGER) AS t_quantity,
				@dayVar AS 'DayDate'
			FROM SiriusSQL.dbo.tr_save t1
				JOIN SiriusSQL.dbo.tr_save t2
				ON t1.mastertran = t2.trans_no
			WHERE t2.department IN ('A-ASNOSP  ','C-CSNOSP  ')
				AND CONVERT(DATE,t2.end_date) >= CONVERT(DATE,@dayVar)
				AND CONVERT(DATE,t2.start_date) <= CONVERT(DATE,@dayVar)
				AND t1.category IN ('A-SSMODS', 'C-JEMODS')
		)
		INSERT INTO #DaysAll
			SELECT ld.*
			FROM cteLessonsDay ld
		
		SET @cnt = @cnt + 1
	END


-- Compile data from all days and add readability columns
SELECT DISTINCT da.*, 	
	CONVERT(DATE,da.start_date) AS start_date_zero,
	IIF(da.DayDate = CONVERT(DATE,da.start_date), 'Arrive','Return') AS 'Arrivals',
	d.descrip AS dept_descrip, c.descrip AS cat_descrip, i.descrip AS item_descrip, 
	CASE da.mod_item 
			WHEN 'AMODSKI' THEN 'Ski'
			WHEN 'AMODSNB' THEN 'Ride'
			WHEN 'CMODSKI' THEN 'Ski'
			WHEN 'CMODSNB' THEN 'Ride'
			ELSE ''
			END AS 'Modality',
	CASE da.mod_item
			WHEN 'AMODSKI' THEN 'Adult Ski'
			WHEN 'AMODSNB' THEN 'Adult Ride'
			WHEN 'CMODSKI' THEN 'Child Ski'
			WHEN 'CMODSNB' THEN 'Child Ride'
			ELSE ''
			END AS 'ModGrp'
FROM #DaysAll da
LEFT JOIN SiriusSQL.dbo.items i
	ON (da.t_department + da.t_category + da.t_item) = (i.department + i.category + i.item)
LEFT JOIN SiriusSQL.dbo.category c
	ON (da.t_department + da.t_category) = (c.department + c.category)
LEFT JOIN SiriusSQL.dbo.departme d
	ON da.t_department = d.department
WHERE mod_item IN ('AMODSKI','AMODSNB','CMODSKI','CMODSNB')
	AND da.t_department IN ('A-ASNOSP','C-CSNOSP')
