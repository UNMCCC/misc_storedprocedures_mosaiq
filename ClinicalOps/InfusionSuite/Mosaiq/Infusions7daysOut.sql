---
--- Look at appts 7 days from now.  run after 6pm.
---
use mosaiq;
set nocount on;
select distinct 
   vw_Schedule.App_DtTm
  ,Quotename(vw_Schedule.PAT_NAME,'"') as PAT_NAME
  ,Ident.IDA as MRN
  ,Quotename(vw_Schedule.LOCATION,'"') as Location
  ,vw_schedule.Activity
  ,Quotename(Short_Desc,'"') as Short_Desc
from vw_schedule 
join staff on staff.Staff_ID=vw_Schedule.Staff_ID
join Ident on vw_Schedule.Pat_ID1=Ident.Pat_ID1
--join Schedule on vw_Schedule.Sch_Id=Schedule.Sch_Id
where 
 --( Schedule.Create_DtTm >= DATEADD(DAY,-1,GETDATE())  and Schedule.Create_DtTm<GETDATE())
 --AND  
  vw_schedule.App_DtTm >  DATEADD(DAY,6,GETDATE()) 
  AND vw_schedule.App_DtTm <= DATEADD(DAY,7,GETDATE()) 
  AND STF_LAST_NAME = 'Infusion'
  AND vw_schedule.Activity not in ('11201 SO','1 Hr Obs','4 Hr Obs','4thFlov','30 Min Obs','36000','36512','36592 MO','51720','96360','96365',
   '96367','96372','96374','96401','96402','96409','96416','Chemo Tch', 'ChemoStart','DC Pump','DMQ_pc','EKG','EMY_pc',
   ' Injection','INFAPPT','INnp','IT Chemo','NOTE','Nurse','P-Access','P-DeAccess','PICC Care','PICC Line','Platelet','PrtFlush',
   'Port Draw','StmCellCol','StmCellInf')   
order by App_DtTm asc

---
--- STF_LAST_NAME==Infusion
--- ACTI 1 Hr Infus, 1.5 Hr Inf, 2 Hr Infus, 2.5 Hr Inf, 3 Hr Infus, 3.5 Hr Infus, 3.5 Hr, 4 Hr Infus, 4.5 Hr, 
  ---    5 Hr Infus, 5.5 Hr, 6 Hr Infus, 6.5 Hr, 7 Hr Infus, 8 Hr Inf, 99195, Hydration, Phlebo, Phlebotomy
  ---    Bed Infus3, Bed Infus7
  --     36430  Blood Transfusion 
  --     BloodT (multiple locations) 
  --     96413 IV Chemo Initial Hr
   ---    Plt Trans
--- DO NOT COUNT Port Draw, PreChem, StmCellCol, StmCellInf, Trans 2 H, Trans 3 H, Injection, 4thFlov, BloodT, DC Pump
-- 36000  IV Start
-- DC Pump (multiple floors)
-- IT CHemo (sounds like 3rd fl, Fero).
-- Nurse @4th Floor Infusion, Nurse visit, Okino
-- P-DeAccess  (port de-access)
-- 36512 apheresis (exclude)

--- QUESTIONS:
--- If " X  Hr Infus" is on 2nd, 1st Fl ?? I.e, do we do something about location?
--- 1 Hr Obs (1 Hr Obs Apt)  ??

--NOTES: THis does not look at the STATUS of the appointment. We 
-- are not concern about cancel/rescheduled -- resources had to be allocated for
-- last-min cancelled appointments, for example.
-- This gives an estimate of the scheduled patients, and data is refined further in TABLEAU.




