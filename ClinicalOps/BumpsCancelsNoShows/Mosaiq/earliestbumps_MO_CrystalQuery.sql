/*12.6.12 Schedule History for Location = UNM Reschedule MO; purpose is to see w/in 29 to 30 days is a bump but Brenda
wants to see all even deleted ones*/
use Mosaiq;

DECLARE  @FIRSTDAYOFMONTH CHAR(10);
SET @FIRSTDAYOFMONTH = CONVERT(char(10),GETDATE()-DAY(GETDATE())+1,120); 

select distinct 
QUOTENAME((ISNULL(DBO.FN_GETPATIENTNAME(PAT.Pat_ID1,'NAMELFM'),'')),'"') AS [PATIENT]
,REPLACE(ID.IDA,',',' ') AS [MRN]
,REPLACE(SCH.ACTIVITY,',',' ') AS [ACTIVITY]
,QUOTENAME(REPLACE(RTRIM(ISNULL(PROV.First_Name, '')) + ' ' + RTRIM(ISNULL(PROV.Last_Name, '')), ',', ' '),'"') AS PROVIDER
,MIN(CONVERT(CHAR(10),SCH.Edit_DtTm,101)) AS [EDIT DATE] 
,CONVERT(CHAR(10),SCH.APP_DTTM,101) AS [APPT DATE]
,DATEDIFF(day,CONVERT(CHAR(10),min(SCH.Edit_DtTm),101),CONVERT(CHAR(10),SCH.APP_DTTM,101)) AS [CALCULATED DAYS]


from Schedule SCH
LEFT JOIN PATIENT PAT WITH(NOLOCK) ON SCH.PAT_ID1 = PAT.PAT_ID1
LEFT JOIN IDENT ID WITH(NOLOCK) ON PAT.PAT_ID1 = ID.PAT_ID1
LEFT JOIN STAFF LOC WITH(NOLOCK) ON SCH.Location = LOC.STAFF_ID
LEFT OUTER JOIN Staff AS PROV WITH (NOLOCK) ON SCH.Staff_ID = PROV.Staff_ID

where LOC.Last_Name = 'UNM Reschedule MO'
and sch.app_dttm >= @FIRSTDAYOFMONTH  -- this is from midnight: includes this day
and sch.app_dttm <= EOMONTH(GETDATE()) -- if using yyyy-mm-dd, place the day+1 of the intended day to include the day.

group by App_DtTm, pat.Pat_Id1,id.ida,sch.Activity,prov.First_Name,prov.Last_Name
order by [APPT DATE], [mrn]