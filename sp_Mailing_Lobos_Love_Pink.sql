USE [MosaiqAdmin]
GO

/****** Object:  StoredProcedure [dbo].[sp_Mailing_Lobos_Love_Pink]    Script Date: 11/15/2022 3:57:25 PM ******/
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
*	Complete the following before uploading to KMS in DocuWare (DW)
*	Note: 83 characters will wrap text on preview in DW Desktop Application
*	PROJECT NAME		> Lobos Love Pink
*	PURPOSE ********************************************************************
*		Per user request, extract patient list for specified date range to be 
*		used to prepare for	mailing list before upcoming "Lobos Love Pink" games
*	DESCRIPTION ****************************************************************
*		Combine initial list of patients, new patients from Visits Bucket 
*		activity code, and patients from medical table with breast cancer 
*		diagnosis. Then bring in mailing address, other metadata and exlude 
*		inmates, deceased and homeless.
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
*	MOSAIQ: Charge, Topog, CPT, vw_Medical_Medical_Audit, Admin, Patient, Ident
		PatLog, Prompt
*	MosaiqAdmin: ufn_isValidPatient, Visits_in_buckets
*	
*	first authored by Debra Healy, 2016, Rick C. and Lilla V. contributed after.
*   Begin stored procedure after this line *************************************
\******************************************************************************/

 
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
SET @BeginDate = '20210101';  -- CHANGE THESE to desired dates

DECLARE @EndDate VARCHAR(8);
SET @EndDate = '20211231';

/****************** Get initial list of patients and patient IDs ***********/
select patient_name,pat_id1, 
case when has_np_dx_sum > 0 then 'Y' else 'N' end has_prov_NP_appt -- this field is probably not helpful to client - may be informative for us in understanding/identifying new-to-ccc diagnoses
INTO #DxPatList
from (
	select distinct patient_name, pat_id1,
	sum(has_np_dx) as has_np_dx_sum

	from (
		select MOSAIQ.dbo.fn_getPatientName(chg.Pat_ID1, 'NAMELFM') as Patient_Name,
			chg.Pat_ID1,
			RTRIM (ISNULL(T1.Diag_code, ' ')) as dx1,
			T1.Description as dx1_Desc,
			RTRIM (ISNULL(T2.Diag_code, ' ')) as dx2,
			T2.Description as dx2_Desc,
			RTRIM (ISNULL(T3.Diag_code, ' ')) as dx3,
			T3.Description as dx3_Desc,
			RTRIM (ISNULL(T4.Diag_code, ' ')) as dx4,
			T4.Description as dx4_Desc,
			RTRIM (ISNULL(CPT.CPT_Code, ' ')) as Proc_cd,
			RTRIM(ISNULL(CPT.Description, ' ')) as Proc_Desc,
			Proc_DtTm,
			Cpt.CPT_code,
			Cpt.Description as CPT_Description,
			CASE
				WHEN cpt.Description like '%New Patient%' then 1 else 0
			END has_NP_Dx

		from MOSAIQ.dbo.Charge chg							/* Pull Patients from Charge Table to search for breast cancer diagnosis codes */
				left outer join MOSAIQ.dbo.Topog T1	on chg.TPG_ID1 = T1.TPG_ID		/* Diagnois Table */
				left outer join MOSAIQ.dbo.Topog T2	on chg.TPG_ID2 = T2.TPG_ID
				left outer join MOSAIQ.dbo.Topog T3	on chg.TPG_ID3 = T3.TPG_ID
				left outer join MOSAIQ.dbo.Topog T4	on chg.TPG_ID4 = T4.TPG_ID
				left outer join MOSAIQ.dbo.CPT		on chg.PRS_ID = CPT.PRS_ID
		where 
			MosaiqAdmin.dbo.ufn_isValidPatient(chg.pat_id1) = 'Y'
			and convert(char(8),proc_DtTm, 112) >= @BeginDate --'20200301'		/* DOS */
			and convert(char(8),proc_DtTm, 112) <= @EndDate --'20210701'	
			and	(
					   RTRIM (ISNULL(T1.Diag_code,'')) between 'C50.001'  and 'C50.929' 	/* ICD-10 Codes for Current Breast Cancer */
					or RTRIM (ISNULL(T2.Diag_code,'')) between 'C50.001'  and 'C50.929' 
					or RTRIM (ISNULL(T3.Diag_code,'')) between 'C50.001'  and 'C50.929' 
					or RTRIM (ISNULL(T4.Diag_code,'')) between 'C50.001'  and 'C50.929'  
					)
		) as A
	group by patient_name, pat_id1
) as B -- select * from #DxPatList

/****************** Flag new patients to CCC from Visit in Buckets activity code desc ***********/
select 
	B.patient_name,
	B.pat_id1,
	B.pat_mrn,
	case when has_np_appt_sum > 0 then 'Y' else 'N' end is_New_to_CCC
into #visPatList
from
	(
	select 
		 A.Patient_name,
		 A.pat_id1,
		 A.pat_mrn,
		sum( A.has_np_appt) as has_np_appt_sum
	from (
		select 
			#DxPatList.pat_id1,
			#DxPatList.patient_name,
			vis.pat_mrn,
			case 
				when vis.actv_code_desc = 'New Patient'
				then 1
				else 0
			end has_NP_appt,
			vis.appt_DtTm
		from MosaiqAdmin.dbo.Visits_in_buckets vis
		inner join #DxPatList on vis.pat_id1 = #DxPatList.pat_id1
		Where vis.appt_Dt >= @BeginDate
		 and  vis.appt_Dt <= @EndDate
		) as A
		group by A.Patient_Name, A.pat_id1, A.pat_mrn
) as B -- select * from #visPatList

/* Get the dbo.Medical Table to see whether an initial diagnosis date has been set for the patient for the specified cancer during the specified date range */
/* The logic is that this field MAY indicate a new diagnosis (or may just be the initial dx date set by a particular provider or new dx may have been made  */
/* at a different facility.  This field is NOT consistently populated by providers. */
/* Providing this information may help abstractors narrow down the search for Newly Diagnosed Patients */

-- drop table #Pats_With_Current_DX

/****************** Filter down to patients wih a Breast Cancer Diagnosis "entered" into Mosaiq ***********/
Select DISTINCT
	 #DxPatList.pat_id1,
	tpg.Diag_code,
	med.dx_partial_DtTm as initial_Dx_dt
into #Pats_With_Current_DX
from #DxPatList
LEFT join Mosaiq.dbo.vw_Medical_Medical_Audit med	on #DxPatList.pat_id1	= med.pat_id1  -- view combines Medical and Medical_Audit tables
LEFT join MOSAIQ.dbo.Topog tpg						on med.TPG_ID			= tpg.TPG_ID	
where med.dx_partial_DtTm is not null
and med.dx_partial_DtTm is not null 
and convert(char(8),med.dx_partial_DtTm, 112) >= @BeginDate
and convert(char(8),med.dx_partial_DtTm, 112) <= @EndDate
and RTRIM (ISNULL(tpg.Diag_code,'')) LIKE 'C50%'			-- BREAST CANCER DIAGNOSIS
-- select  * from #Pats_With_Current_DX

-- drop table #PatList
/****************** Combine prior temp tables to get preliminary list of patients***********/
select 
	#visPatList.Patient_Name,
	#visPatList.Pat_id1,
	#visPatList.pat_mrn,
	#visPatList.is_New_to_CCC,
	#Pats_With_Current_DX.initial_Dx_dt -- okay if more than one is returned?
into #PatList
from #visPatList
left join #DxPatList			on #visPatList.pat_id1 = #DxPatList.pat_id1
left join #Pats_With_Current_DX on #visPatList.pat_id1 = #Pats_With_Current_DX.pat_id1
-- select * from #PatList

-- drop table #Dataset
/****************** Get distinct data set from Mosaiq with most recent metadata from list of patients ***********/
select distinct 
	Patient_Name, 
	Addr1, 
	Addr2, 
	City, 
	State, 
	Postal, 
	HomePhone, 
	Pat_EMail,
	Pat_CellPhone,
	Pat_Home_Phone,
	LanguageSpoken,
	Gender, 
	Salutation, 
	pat_MRN AS MRN,
	New_to_CCC_OR_New_DX_entered_in_MQ,
--	pat_id1, 
--	is_New_to_CCC,
--	initial_Dx_dt
	getDate() as Extract_Date
into #Dataset
from 
(	
	select 
		Pro.Description as LanguageSpoken,
		pat.salutation,
		#PatList.Patient_name,
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_Adr1 else adm.Pat_Alt_Adr1 end as Addr1,  -- 6/23/21 use of mail_pref pre-dates 2016 and this is old code -- probably not used
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_Adr2 ELSE adm.Pat_Alt_Adr2 END AS Addr2,
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_City ELSE adm.Pat_Alt_City end AS City,
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_State ELSE adm.Pat_Alt_State END AS State,
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_Postal ELSE adm.Pat_Alt_Postal END AS Postal,
		CASE WHEN adm.Mail_Pref <> 1 THEN adm.Pat_Home_Phone ELSE adm.Pat_Alt_Home_Phone END AS HomePhone,
		adm.Pat_EMail,
		adm.Pat_CellPhone,
		adm.Pat_Home_Phone,
		adm.gender,
		pat.last_name,
		#PatList.pat_mrn,
		#PatList.pat_id1,
		case 
			when is_New_to_CCC = 'Y' -- has "New Patient" appt
				or initial_Dx_dt is not null -- initial dx date entered in MQ by provider during timeframe in question
			then 'Y'
			else 'N'
		end New_to_CCC_OR_New_DX_entered_in_MQ,  -- this does not indicate 'newly diagnosed' -- but it is the best we have
												 -- combined these fields to simplify explanation to end-user
												 -- means New to CCC (not necessarily newly diagnosed) OR returning patient with new breast cancer Dx entered in system by provider
		is_New_to_CCC,
		initial_Dx_dt,
		case when (ptl.PLC_Id = 48 and ptl.Inactive_DtTm is null)  -- Inmate  If Inactive_dtTm is populated then patient is not an inmate
			then 'YES'
			else 'NO'
		end IsInmate,

		case when (adm.Expired_DtTm is not null and adm.Expired_DtTm <> ' ') or (Ident.IDC is not null and Ident.IDC <> ' ')
			then 'YES' 
			else 'NO'
		end IsDeceased,

		case when Adm.Pat_Adr1 like '%homeless%' or Adm.Pat_Adr2 like '%homeless%' or Adm.Pat_Alt_Adr1 like '%homeless%' or Adm.Pat_Alt_Adr2 like '%homeless%'  -- Front Desk says this isn't done, but it is
			then 'YES'
			else 'NO'
		 end IsHomeless
	from #PatList
	inner join MOSAIQ.dbo.Admin adm		on #PatList.Pat_ID1 = adm.Pat_ID1
	inner join MOSAIQ.dbo.Patient pat	on #PatList.Pat_ID1 = pat.Pat_ID1
	inner join MOSAIQ.dbo.Ident			on #PatList.Pat_ID1 = Ident.Pat_Id1
	left join  MOSAIQ.dbo.PatLog ptl	on Adm.Pat_ID1 = ptl.Pat_Id1 and ptl.PLC_Id = 48 and ptl.Inactive_DtTm is null --8/2/21 -- use this join to avoid duplicates and confusing results
	left join  MOSAIQ.dbo.Prompt pro	on adm.Language_Spoken_Pro_ID = Pro.Pro_id
) as A
where  A.IsInmate = 'NO' and A.IsDeceased = 'NO' and A.IsHomeless = 'NO'

END
GO


