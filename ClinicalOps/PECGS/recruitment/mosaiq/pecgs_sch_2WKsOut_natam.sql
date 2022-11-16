/****************************************************************************\
	PE-CGS extract final as of 3/18/2022
	Batch file will load to gp.tableaudata.pecgs_native_coming2cc
	From Mosaiq view schedule and tables: staff, admin, cpt
	with joins to MosaiqAdmin tables [activity ref bucket] and [ref patient] 
	Criteria to include: 14 days out, valid patients, Physician/APP and Races:
		'Alaskan Native','American Indian', 'Hawaiian Native'
	Criteria to exclude: cancelled appts, virtual activities
	note: exclusion of phone activity by limit to Physician/APP
\***************************************************************************/
SET NOCOUNT ON;
Use Mosaiq;
SELECT DISTINCT
	  sch.IDA as mrn,
      ISNULL(QUOTENAME(sch.PAT_NAME,'"'),'') as pat_name,
	  CASE 
			WHEN sch.[STF_LAST_NAME] LIKE 'Infusion%'
				THEN ISNULL(QUOTENAME(TRIM(stf.Last_Name) + ', ' + TRIM(stf.First_Name),'"'),'') --attending
			WHEN sch.STF_LAST_NAME IS NULL
				THEN ISNULL(QUOTENAME(TRIM(stf.Last_Name) + ', ' + TRIM(stf.First_Name),'"'),'') --attending
			ELSE ISNULL(QUOTENAME(TRIM(sch.STF_LAST_NAME) + ', ' + TRIM(sch.STF_First_NAME),'"'),'') --provider
		END AS provider,
	  sch.App_DtTm as app_dttm,
	  Admin.Pat_Postal as pat_zip,
	  dbo.fn_GetPatientRaces(sch.Pat_ID1,1,0) as pat_race
FROM vw_Schedule sch
	LEFT JOIN Staff stf		ON sch.[Attending_Md_Id] = stf.[Staff_ID] -- add staff table to get provider full name
	LEFT JOIN Admin Admin	ON sch.Pat_ID1=Admin.Pat_ID1
	LEFT JOIN CPT Cpt		ON sch.Activity=Cpt.Hsp_Code
	LEFT JOIN MosaiqAdmin.dbo.visit_activity_bucket_ref		ActRef ON Cpt.CPT_Code = ActRef.actv_code -- from Mosaiq Admin
	INNER JOIN MosaiqAdmin.dbo.Ref_Patients					PatRef ON sch.Pat_ID1 = PatRef.Pat_ID1 -- is this a valid patient?
  WHERE
	CONVERT(VARCHAR(10), sch.App_DtTm, 111) >= CONVERT(VARCHAR(10), Getdate(), 111) -- From Today    
	AND CONVERT(VARCHAR(10), sch.App_DtTm, 111) <= DATEADD(day,14,GETDATE()) -- Up to 14 days
	AND PatRef.is_valid = 'Y' -- only reference valid patients found in MosaiqAdmin table
	AND ActRef.actv_bucket = 'Physician/APP' -- only reference physician/APP found in MosaiqAdmin table
	AND dbo.fn_GetPatientRaces(sch.Pat_ID1,1,0) IN ('Alaskan Native','American Indian', 'Hawaiian Native')
	AND (SysDefStatus NOT IN  ('X') OR SysDefStatus  IS NULL) -- exclude canceled appointments
	AND Cpt.Short_Desc NOT LIKE '%virtual%' -- exclude all virtual visists for now
	ORDER BY sch.App_DtTm