-- USAGE be used at the MQ rep. server (needs Mosaiq and MosaiqAdmin)
-- PURPOSE : For the MO BUMPS rate, this is the denominator.
-- Calcs # of appointments (includes cancels, bumps, no-shows, c, d, es and others)
-- Excludes ROs (cause this is the MO bump denominator)
-- Excludes Financials and Notes.

SET NOCOUNT ON;

DECLARE  @FIRSTDAYOFMONTH CHAR(10);
SET @FIRSTDAYOFMONTH = CONVERT(char(10),GETDATE()-DAY(GETDATE())+1,120); 

SELECT distinct count(*) as TotalMoAppts, CONVERT(char(10),GETDATE(),120) as runDate
FROM [Mosaiq].[dbo].[vw_Schedule] 
WHERE App_DtTm>=@FIRSTDAYOFMONTH 
 and App_DtTm<=EOMONTH(GETDATE())
 and Activity not in ('Financial','Finan Asst','NOTE')
 and DEPT not like 'CRTC'
 and Mosaiq.dbo.fn_GetPatientName(Pat_id1, 'NAMELFM') not in ('BLOCK, SCHEDULE', 'DO NOT BOOK, DO NOT BOOK', 'SAMPLE, PATIENT', 'TEST, A', 'TEST, BASIL B.', 'TEST, JUSTIN B.', 'TEST, PROVIDER', 'TESTER, TESTY', 'TESTOFC, PATIENT7','HOLD, HOLD', 'NEW/OLD, START', 'PHYSICS, AGILITY', 'PHYSICS, TOMO','IMPAC, IMPAC', 'AAAAAAAAA, AAAAAAAAAAA','NEW, NEW','XXXXXXXXXXXXXXXXXXX, XXXXXXXXXXXXXXXXXXXX','MOUSE, MICKEY','PHANTOM 2, V15','ZZZ - TEST, MED ONC','ECLIPSE, WATERPHANTOM','SNOOPY, DOGGIE','NEW START, PT')