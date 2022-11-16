                                                         
/****
Inigo, using the visit system for Dr. Emily Wu/Clinical Grpup Unit.
	
	******/
SELECT distinct
      [pat_mrn] as MRN
	  ,convert(varchar(12),pat.BIRTH_DTTM,112) as DOB
	,Quotename(patient_name,'"') as patient_name
      ,vis.appt_dt
	  ,is_TeleMed 
      ,concat([prov_name_last_MQ], '; ',[prov_name_first_MQ]) as Provider
--        ,[loc_bucket]
--	   ,[sch_loc]
--      ,[actv_code]
      ,[actv_code_desc]
 --     ,[actv_desc]	       
      ,[sch_Status_Prim]
      ,[FY]
	 ,adm.pat_postal
     ,isnull(Mosaiq.dbo.fn_GetPatientRaces(adm.Pat_ID1,1,0),' ') as Race  -- use function to get Races -- not from Admin.Race
	 ,isnull(PRO.Description, ' ') as Ethnicity	
  FROM [MosaiqAdmin].[dbo].[visits_in_buckets] vis
  join mosaiq.dbo.Admin adm on adm.pat_id1 = vis.pat_id1
  join mosaiq.dbo.vw_patient pat on pat.PAT_ID1 = vis.pat_id1
  LEFT JOIN  Mosaiq.dbo.Prompt PRO ON adm.Ethnicity_PRO_ID = PRO.Pro_ID  -- Left Join becaus here may not be an Ethnicity entry
  where FY>=2021
   and prov_specialty_type_mq='Gyn-onc'


	

