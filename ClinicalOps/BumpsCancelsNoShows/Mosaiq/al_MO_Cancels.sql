/* pull from mosaiqAdmin no-shows table that is popupalted by corresponding stor. proc.*/
use MosaiqAdmin;
SET NoCOUnt On;

SELECT Pat_Id1, App_DtTm
FROM appts_cancels_MO_keys 
WHERE   
   App_DtTm is <=GETDATE()
   and CONVERT(CHAR(10), app_DtTm,120) is >= '2020-10-01'
ORDER BY app_DtTm desc

