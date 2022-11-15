USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_Mailing_Lobos_Love_Pink_v2]    Script Date: 11/15/2022 4:05:25 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [dbo].[sp_Mailing_Lobos_Love_Pink_v2]

AS
BEGIN

-- Add to prevent extra result sets from interfering with SELECT statements
SET NOCOUNT ON; -- ON will not show the number of affected rows in the T-SQL query

/******************************************************************************\
*	Complete the following before uploading to KMS in DocuWare (DW)   
*	Note: 83 characters will wrap text on preview in DW Desktop Application   
*	PROJECT NAME		> Lobos Love Pink
*	PURPOSE ********************************************************************
*		Per user request, extract patient list for specified date range to be 
*		used to prepare for	mailing list before upcoming "Lobos Love Pink" games    
*	DESCRIPTION ****************************************************************
*		Combine initial list of patients, new patients from Visits Bucket    -
*		activity code, and patients from medical table with breast cancer 
*		diagnosis. Then bring in mailing address, other metadata and exlude 
*		inmates, deceased and homeless.
*	CLIENT *********************************************************************
*		(Pharmacy - AIC CdS)
*	AUTOMATED INPUT			> 
*	MANUAL INPUT			> Date range provided by requestor
*	OUTPUT / DELIVERABLE	> Excel file
*	Optionally, the following fields may also be helpful but are not required   
*	COMMENTS *******************************************************************
*		Only NM Tumor Reg identifies "newly diagnosed" during case abstraction. 
*		This pulled patients who have been seen between a specified date range 
*		and have breast cancer diagnosis codes. This is limited to be patients 
*		who are either: new to UNMCCC (which doesn't necessarily mean newly 
*		diagnosed) or are existing patients returning to the Cancer Center and 
*		which their provider entered an initial diagnosis of breast cancer 
*		in their record during the specified date range.
*		Note: exclude deceased, inmates and homeless and may request a data-   
*		check as followup to support selection processes to RSVP to games
*
*	STORED PROCEDURE / FUNCTION	> sp_Mailing_Lobos_Love_Pink
*	SQL AGENT JOB	> 
*	SCHEDULE		> Ad-hoc
*	LINKED SERVER	> 
*	DEPENDENT OBJECTS **********************************************************
*	MOSAIQ: Charge, Topog, CPT, Admin, Patient, Ident
		PatLog, Prompt   --replaced with Ref_Patients_Diagnoses
*	MosaiqAdmin: ufn_isValidPatient, Visits_in_buckets, Ref_Patients_Diagnoses
*	
*	CREATED Debra Healy, 2016. Contribs by Rick Compton & Lilla Vanerdoe
*   Begin stored procedure after this line *************************************/
 /****************** drop temp tables ***********/
if object_id('tempdb..#DxPatList') is not null
    drop table #DxPatList

if object_id('tempdb..#visPatList') is not null
	drop table #visPatList

if object_id('tempdb..#Pats_With_Current_DX') is not null
	drop table #Pats_With_Current_DX

if object_id('tempdb..#PatList') is not null
	drop table #PatList

if object_id('tempdb..#PatList') is not null
	drop table #Dataset

/****************** declare/set variales ***********/
DECLARE @BeginDate VARCHAR(8);
SET @BeginDate = '20220101';--UPDATE THESE TO YOUR NEEDS

DECLARE @EndDate VARCHAR(8);
SET @EndDate = '20220816';

/****************** Get initial list of patients and patient IDs ***********/


--drop table #earliest
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
       from [MosaiqAdmin].[dbo].[Ref_Patient_Diagnoses]
      where Diag_code between 'C50.001' and 'C50.929'  --a diagnosis of breast cancer
      group by pat_id1
     )A
   where A.earliest_diag_date >= '2022-01-01' --'2022-01-01'    --determine if that first appt with a breast cancer diagnosis fell within the time frame given by the requestor
     and A.earliest_diag_date <= '2022-08-22' --'2022-08-22'
  )B


--drop table #np
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
  and actv_code = 'np' --or actv_desc like '%new%')  --there are some actv_code = 'gc' that are identified as new patients in thhe actv_desc

--drop table #newlyDiagnosed
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
  and actv_code != 'np' --or actv_desc not like '%new%')  --there are some actv_code = 'gc' that are identified as new patients in thhe actv_desc
where #earliest.pat_id1 not in (select pat_id1 from #np)
  order by pat_id1

--drop table #gc
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
and vib.appt_dt <= '20220822'
and vib.pat_id1 in (select pat_id1 from #newlyDiagnosed)
--order by #newlyDiagnosed.patient_name, appt_dt
)A
group by pat_id1
having count(*) = 1

Select * from MosaiqAdmin.dbo.visits_in_buckets vib where pat_id1 in (select pat_id1 from #gc) 
order by patient_name,appt_dt

--drop table #breastCancerPatients
select *
into #breastCancerPatients
from #np
UNION
select * 
from #newlyDiagnosed
where pat_id1 not in(85955,81676,85285,84441,86544,83931,77214,86364,83411)

--select * from #breastCancerPatients order by patient_name

-- drop table #Dataset
/****************** Get distinct data set from Mosaiq with most recent metadata from list of patients ***********/
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
into #Dataset
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

END
GO


