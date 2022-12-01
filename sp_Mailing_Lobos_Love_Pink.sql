USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_Mailing_Lobos_Love_Pink]    Script Date: 12/1/2022 1:55:17 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[sp_Mailing_Lobos_Love_Pink]

AS
BEGIN

-- Add to prevent extra result sets from interfering with SELECT statements
SET NOCOUNT ON; -- ON will not show the number of affected rows in the T-SQL query

/******************************************************************************\
*	PROJECT NAME		> Lobos Love Pink
*	LOCATION / DB		> MosaiqAdmin
*	PURPOSE ********************************************************************
*		Per user request, extract patient list for specified date range to be 
*		used to prepare mailing list before upcoming "Lobos Love Pink" games    
*	DESCRIPTION ****************************************************************
*		Limit breast cancer patient selection from Ref_Patient_Diagnoses by the
*       dates supplied to us by the requestor. Select new patients using visit
*       bucket activity code np combined with patients that aren't new but are 
*       newly diagnosed with breast cancer from this population. Bring in mail-
*		ing address, other metadata and exlude inmates, deceased and homeless.
*	CLIENT *********************************************************************
*		Amy Liota, Harmony Bowles (Pharmacy - AIC CdS)
*	AUTOMATED INPUT			> None
*	MANUAL INPUT			> Date range provided by requestor
*	OUTPUT / DELIVERABLE	> Excel file
*	SERVER NAME				> UNMMG-SQL-CCC\UNMMGSQLUNMCCC
*	COMMENTS *******************************************************************
*		Only NM Tumor Reg identifies "newly diagnosed" during case abstraction. 
*		This pulls patients who have been seen between a specified date range 
*		and have breast cancer diagnosis codes. This is limited to be patients 
*		who are either new to UNMCCC (which doesn't necessarily mean newly 
*		diagnosed) or are existing patients returning to UNMCCC whose provi-
*		der entered an initial diagnosis of breast cancer in their record dur-
*       ing the specified date range.
*		Note: exclude deceased, inmates and homeless
*
*	STORED PROCEDURE / FUNCTION	> sp_Mailing_Lobos_Love_Pink
*	SQL AGENT JOB	> Not a scheduled job
*	SCHEDULE		> Ad-hoc
*	LINKED SERVER	> No linked servers
*	DEPENDENT OBJECTS **********************************************************
*	MOSAIQ: Admin, Patient, Ident, PatLog, Prompt
*	MosaiqAdmin: Ref_Patients_Diagnoses, visits_in_buckets
*	
*	CREATED BY			> Debra Healy 
*	WHEN CREATED		> July 2016
*	LAST REVISED BY		> Lilla T Varnedoe 
*	WHEN LAST REVISED	> August 2022


************************************Begin stored procedure after this line *************************************/

/*******SET DATE RANGE FOR #earliest TABLE AND #gc TABLE*******/


if object_id('tempdb..#earliest') is not null
    drop table #earliest
--gather breast cancer patients first diagnosed between the dates given by the requestor
select distinct pat_id1
	   ,earliest_diag_date
  into #earliest
  from
  (
   select  A.pat_id1
          ,A.earliest_diag_date
     from 
     (
      select pat_id1
            ,min(appt_date) as earliest_diag_date  --first appt date
       from MosaiqAdmin.dbo.Ref_Patient_Diagnoses
      where Diag_code between 'C50.001' and 'C50.929'  --a diagnosis of breast cancer
      group by pat_id1
     )A
   where A.earliest_diag_date >= '2022-01-01'    --determine if that first appt with a breast cancer diagnosis fell within the time frame given by the requestor
     and A.earliest_diag_date <= '2022-11-28' 
  )B


--select * from #earliest order by pat_id1, earliest_diag_date  

--select pat_id1, count(*)  --these should be distinct without repeat patients
--  from #earliest
-- group by pat_id1 
--having count(*) > 1

if object_id('tempdb..#np') is not null
    drop table #np
--determine which patients from #earliest above are new patients
select distinct patient_name
       ,#earliest.pat_id1
	   ,#earliest.earliest_diag_date
	   ,vib.appt_dt
	   ,pat_mrn
	   ,'Y' np_ind
  into #np
  from #earliest
inner join MosaiqAdmin.dbo.visits_in_buckets vib
   on #earliest.pat_id1 = vib.pat_id1
  and #earliest.earliest_diag_date = convert(date,vib.appt_Dt,23)
  and actv_code = 'np' --actv_desc can have new in it when actv_code = 'gc' - these are identified as new patients but should not count as new patients in this selection

if object_id('tempdb..#newlyDiagnosed') is not null
    drop table #newlyDiagnosed
--if the earliest diagnosis date of breast cancer falls in the date range but the patient's visit that correlates to that diagnosis wasn't
--marked as a new patient, then the patient is being counted as a newly diagnosed patient, not a new patient
select distinct patient_name
       ,#earliest.pat_id1
	   ,#earliest.earliest_diag_date
	   ,vib.appt_dt
	   ,pat_mrn
	  ,'N' np_ind 
 into #newlyDiagnosed
 from #earliest
inner join MosaiqAdmin.dbo.visits_in_buckets vib
   on #earliest.pat_id1 = vib.pat_id1
  and #earliest.earliest_diag_date = convert(date,vib.appt_Dt,23)
  and actv_code != 'np'
where #earliest.pat_id1 not in (select pat_id1 from #np)


if object_id('tempdb..#gc') is not null
    drop table #gc
--looks for newly diagnosed patients with only one appointment during the date range; these patients need to be looked at more closely; if their
--one appointment was genetic counseling (gc) or did not result in more than one appointment, Amy does not want them counted for free tickets.
select pat_id1, count(*) as numb_times
into #gc
from
(
select #newlyDiagnosed.patient_name,
       #newlyDiagnosed.pat_id1,
       vib.appt_dt,
	   vib.actv_code
  from #newlyDiagnosed
 inner join MosaiqAdmin.dbo.visits_in_buckets vib
    on #newlyDiagnosed.pat_id1 = vib.pat_id1
   and vib.appt_dt >= '20220101'
   and vib.appt_dt <= '20221128'
)A
group by pat_id1
having count(*) = 1

--select statement to see how many visits the patients selected above actually had with UNMCCC
select * from MosaiqAdmin.dbo.visits_in_buckets vib where pat_id1 in (select pat_id1 from #gc) 
order by patient_name,appt_dt

--drop table #breastCancerPatients
select *
into #breastCancerPatients
from #np
UNION
select * 
from #newlyDiagnosed
where pat_id1 not in(85955,81676,85285,84441,86544,83931,77214,86364,83411) --list the patients in #gc that only had one appointment; run the select statment
                                                                            --below where the #gc table is created to determine which pat_id1's to include in
																			--this list. Not all should always be included.

--select * from #breastCancerPatients order by patient_name

if object_id('tempdb..#dataset') is not null
    drop table #dataset
--get distinct data set from Mosaiq with most recent metadata from list of patients
select distinct 
	patient_name, 
	Addr1, 
	Addr2, 
	City, 
	State, 
	Postal, 
	HomePhone, 
	Pat_EMail,
	Pat_CellPhone,
	LanguageSpoken,
	Gender, 
	Salutation, 
	pat_MRN AS MRN,
	np_ind,
	pat_id1,
	getDate() as Extract_Date
into #dataset
from 
(	
	select 
		Pro.Description as LanguageSpoken,
		pat.salutation,
		#breastCancerPatients.patient_name,
		adm.pat_adr1 as Addr1,
		adm.pat_Adr2 as Addr2,
		adm.Pat_City AS City,
		adm.Pat_State AS State,
		adm.Pat_Postal AS Postal,
		adm.Pat_Home_Phone AS HomePhone,
		adm.Pat_EMail,
		adm.Pat_CellPhone,
		adm.gender,
		pat.last_name,
		#breastCancerPatients.pat_mrn,
		#breastCancerPatients.pat_id1,
		#breastCancerPatients.np_ind,
		case when (ptl.PLC_Id = 48 and ptl.Inactive_DtTm is null)  -- Inmate - If Inactive_dtTm is populated then patient is not an inmate
			then 'YES'
			else 'NO'
		end IsInmate,
		case when (adm.Expired_DtTm is not null and adm.Expired_DtTm <> ' ') or (Ident.IDC is not null and Ident.IDC <> ' ')
			then 'YES' 
			else 'NO'
		end IsDeceased,
		case when Adm.Pat_Adr1 like '%homeless%' or Adm.Pat_Adr2 like '%homeless%'  -- Front Desk says this isn't done, but it is
			then 'YES'
			else 'NO'
		 end IsHomeless
	from #breastCancerPatients
	inner join MOSAIQ.dbo.Admin adm		on #breastCancerPatients.Pat_ID1 = adm.Pat_ID1
	inner join MOSAIQ.dbo.Patient pat	on #breastCancerPatients.Pat_ID1 = pat.Pat_ID1
	inner join MOSAIQ.dbo.Ident			on #breastCancerPatients.Pat_ID1 = Ident.Pat_Id1
	left join  MOSAIQ.dbo.PatLog ptl	on Adm.Pat_ID1 = ptl.Pat_Id1 and ptl.PLC_Id = 48 and ptl.Inactive_DtTm is null --8/2/21 -- use this join to avoid duplicates and confusing results
	left join  MOSAIQ.dbo.Prompt pro	on adm.Language_Spoken_Pro_ID = Pro.Pro_id
) as A
where  A.IsInmate = 'NO' and A.IsDeceased = 'NO' and A.IsHomeless = 'NO'

-- select * from #Dataset

--get final list of patients who are either new to UNMCCC or newly diagnosed
--this is the deliverable
select * 
from #dataset
order by patient_name

END
GO


