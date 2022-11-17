 Use Mosaiq;
SET NOCOUNT ON; 
DECLARE @TwoWeeksOut VARCHAR(10);
DECLARE @Today VARCHAR(10);
Set @Today =  CONVERT(VARCHAR(10),GETDATE(),112);
Set @TwoWeeksOut = CONVERT(VARCHAR(10),DATEADD(day,14,GETDATE()),112);

 SELECT DISTINCT 
 Pat.IDA, 
 Pat.BIRTH_DTTM, 
 Sched.PAT_NAME, 
 Sched.App_DtTm, 
-- Sched.Location_ID,
 --dbo.fn_GetLastOrNextVisit(0,Pat.PAT_ID1,Sched.App_DtTm)
   ( SELECT TOP 1 convert(varchar(10),SCH.App_DtTm,121) from schedule SCH  where dbo.fn_Date(SCH.App_DtTm) < dbo.fn_Date(Sched.App_DtTm) AND 
      (SCH.Pat_ID1 = Pat.PAT_ID1) and SCH.Version = 0 and SCH.SchStatus_Hist_SD in (' C',' D','E')
     ORDER BY SCH.App_DtTm DESC) as Last_Appt

 FROM   vw_Patient Pat
 INNER JOIN vw_Schedule Sched ON Pat.PAT_ID1=Sched.Pat_ID1
 WHERE  (convert(varchar(10),Sched.App_DtTm,112) >= @Today 
 AND convert(varchar(10),Sched.App_DtTm,112) < @TwoWeeksOut) 
 AND Sched.Location_ID=799
 ORDER BY Sched.App_DtTm, Sched.PAT_NAME
