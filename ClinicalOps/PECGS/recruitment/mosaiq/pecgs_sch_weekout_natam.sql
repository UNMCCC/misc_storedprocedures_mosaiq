 /*
 *  Adapted (heavily) from schedule-by-staff/location
 *  Rid of many fields included in the template query from canned CR.
 *  Adds demographic field constraints where Race either Native Americans, Unavailable
 *		OR Enthnicity Hispanic/Latino
 *  Adds date filter, week out (7 days)
 *	Add exclusion for canceled (X) appointments
 *  Add additional fields from Schedule_tip
 *	Add additional join/fields for activity (class, bucket)
 */
 SET NOCOUNT ON;
 Use Mosaiq;
 SELECT DISTINCT
 	Schedule.App_DtTm,
	IDENT.IDA as MRN,
	QUOTENAME(ISNULL(dbo.fn_getpatientname(Schedule.Pat_ID1,'NAMELFM'),''),'"')  as Name, 
	QUOTENAME(Staff2.Last_Name,'"') as Location,
	QUOTENAME(Cpt.Description,'"') as Activity_Description,
	QUOTENAME(ISNULL(dbo.fn_GetPatMdName (Schedule.Pat_ID1, 1, 1, Schedule.Inst_ID),''),'"') as Provider,
	ISNULL(dbo.fn_getpatdiaginfo(Schedule.pat_ID1,1,1),'') as DxCode,
    QUOTENAME(ISNULL(dbo.fn_getpatdiaginfo(Schedule.pat_ID1,1,6),''),'"') as DxDesc,
	Admin.gender,
	QUOTENAME(dbo.fn_GetPatientRaces(Admin.Pat_ID1,1,0),'"') as Races,
    PR2.Description as  Ethnicity,
	dbo.fn_getPatientAgeYears(Admin.Pat_ID1,Schedule.App_DtTm) as Age,
	Admin.Pat_Work_Phone, 
	Admin.Pat_Work_Phone_Ex, 
	Admin.Pat_Home_Phone, 
	Admin.Pat_CellPhone as Mobile, 
	QUOTENAME(Admin.Pat_Adr1,'"') as Address,
	QUOTENAME(Admin.Pat_City,'"') as City,
	Admin.Pat_State as State,
	Admin.Pat_Postal,
	QUOTENAME(ISNULL(Schedule.Notes,''),'"') as Notes,
	Cpt.CPT_Code,
	Cpt.Hsp_Code,
	Cpt.Hsp_Code3,
	Schedule_Tip.Sch_Set_Id, -- Add fields here down
	Schedule_Tip.SchStatus_Hist_SD,
	Schedule_Tip.Create_DtTm,
	DATEDIFF(Day,CONVERT(VARCHAR(10), Schedule_Tip.Create_DtTm, 111),GETDATE()) Create_DtDiff,
	Schedule_Tip.Edit_DtTm,
	DATEDIFF(Day,CONVERT(VARCHAR(10), Schedule_Tip.Edit_DtTm, 111),GETDATE())  Edit_DtDiff,
	ActRef.actv_class,
	ActRef.actv_bucket
 FROM   Schedule Schedule_Tip 
	LEFT OUTER JOIN Schedule Schedule	ON Schedule_Tip.Sch_Set_Id=Schedule.Sch_Set_Id
	LEFT OUTER JOIN Staff Staff2		ON Schedule.Location=Staff2.Staff_ID
    LEFT OUTER JOIN CPT Cpt				ON Schedule.Activity=Cpt.Hsp_Code
	LEFT OUTER JOIN Admin Admin			ON Schedule.Pat_ID1=Admin.Pat_ID1
	LEFT OUTER JOIN Patient Patient		ON Schedule.Pat_ID1=Patient.Pat_ID1
	LEFT OUTER JOIN Config Config		ON Schedule.Inst_ID=Config.Inst_ID
	LEFT OUTER JOIN Notes Notes			ON Schedule.Note_ID=Notes.Note_ID
	LEFT OUTER JOIN Ident IDENT			ON Patient.Pat_ID1=IDENT.Pat_Id1
	LEFT OUTER JOIN prompt PR2			ON Admin.Ethnicity_Pro_ID = PR2.pro_id
	LEFT OUTER JOIN MosaiqAdmin.dbo.visit_activity_bucket_ref ActRef ON CPT.CPT_Code = ActRef.actv_code -- from Mosaiq Admin
 WHERE 
  Schedule_Tip.Version=0
  AND Schedule.Version=0
  AND CONVERT(VARCHAR(10), Schedule.App_DtTm, 111) >= CONVERT(VARCHAR(10), Getdate(), 111)
  AND CONVERT(VARCHAR(10), Schedule.App_DtTm, 111) <= DATEADD(day,7,GETDATE())
  AND (IDENT.IDENT_ID IS  NULL  OR IDENT.Version=0)
  AND (dbo.fn_GetPatientRaces(Admin.Pat_ID1,1,0) IN ('American Indian', 'Unavailable')
		OR PR2.Description IN ('Hispanic/Latino'))
  AND NOT Schedule.SchStatus_Hist_SD = 'X'
  Order by Schedule.App_DtTm
;