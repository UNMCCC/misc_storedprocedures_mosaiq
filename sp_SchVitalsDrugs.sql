USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_SchVitalsDrugs]    Script Date: 11/15/2022 3:49:08 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_SchVitalsDrugs]
AS
BEGIN

SET NOCOUNT ON;
-- Drop temporary tables 

if object_id('tempdb..#Pat_Sch') is not null
	drop table #Pat_Sch;

--	1)  Get sch dates since Sep 1 -- all pats.
select distinct 
	ref.pat_id1, 
	ref.appt_date,
	P.ida as MRN,
	P.pat_id1_name as Pat_Name
into #Pat_Sch  -- meaning data existing in the table as of now 
from MosaiqAdmin.dbo.Ref_SchSets ref
join MosaiqAdmin.dbo.Ref_Patients P on ref.pat_id1 = P.pat_id1 
where ref.appt_date>='2022-09-01'

-- Select * from #Pat_Sch

-- 2)  Get Vitals into pat-vitals  (restrict on vital-bucket and dates)

if object_id('tempdb..#Pat_Vitals') is not null
	drop table #Pat_Vitals;

SELECT distinct 
    vitals.[Pat_ID1]
	,convert(varchar(10),Vitals.measurement_DtTm,121) as Vitals_Date  
into #Pat_Vitals
FROM [MosaiqAdmin].[dbo].[Ref_Observation_Measurements]  Vitals
 
where [Observation_Bucket] = 'Vital Signs'
  and convert(varchar(10),Vitals.measurement_DtTm,121) >= '2022-09-01'

 -- 3)  get drugs

if object_id('tempdb..#Pat_Drugs') is not null
	drop table #Pat_Drugs;

select distinct 
    drugs.[Pat_ID1],
	convert(varchar(10),adm_start_dtTm,121) as Drug_Date
into #Pat_Drugs
FROM MosaiqAdmin.dbo.Ref_Patient_Drugs_Administered drugs
where adm_start_dtTm>='2022-09-01'

-- Select * from #Pat_Drugs
-- 4) Join Sch-dates with Vitals into table B

if object_id('tempdb..#Pat_VisitVitals') is not null
	drop table #Pat_VisitVitals;

	-- Select count(*) from #Pat_Sch

select distinct 
	Visit.pat_id1, 
	Visit.appt_date,
	Visit.MRN,
	Visit.Pat_Name,
--	Vital.pat_id1,
	Vital.Vitals_Date 
into #Pat_VisitVitals
FROM #Pat_Sch Visit
left join #Pat_Vitals Vital on Visit.pat_id1=Vital.Pat_ID1 and Visit.appt_date=Vital.Vitals_Date

-- select * from #Pat_VisitVitals
-- Noew we have visits and vitals, for those who have vitals. Lets add drugs
if object_id('tempdb..#Pat_VisitVitalsDrugs') is not null
	drop table #Pat_VisitVitalsDrugs;

Select distinct 
	#Pat_VisitVitals.pat_id1, 
	#Pat_VisitVitals.appt_date,
	#Pat_VisitVitals.MRN,
	#Pat_VisitVitals.Pat_Name,
    #Pat_VisitVitals.Vitals_Date,
	Drugs.Drug_Date
into #Pat_VisitVitalDrugs
FROM #Pat_VisitVitals 
left join #Pat_Drugs Drugs on #Pat_VisitVitals.pat_id1=Drugs.Pat_ID1 and #Pat_VisitVitals.appt_date=Drugs.Drug_Date

TRUNCATE TABLE MosaiqAdmin.dbo.CuresAct_VisitVitalDrugs
INSERT INTO MosaiqAdmin.dbo.CuresAct_VisitVitalDrugs
select 	*
from #Pat_VisitVitalDrugs

END
GO


