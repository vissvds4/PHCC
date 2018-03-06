CREATE OR REPLACE PACKAGE BODY APPS.xx_per_clinical_privilege_pkg
IS



FUNCTION xx_get_manager_healthCentre(p_person_id IN VARCHAR2)
 RETURN VARCHAR2 IS

 l_health_centre VARCHAR2(1000):= NULL;
BEGIN

  SELECT  substr(org.NAME,INSTR(org.NAME,'.',-1,1)+1) health_centre
        INTO   l_health_centre
        FROM apps.hr_all_organization_units org,
             apps.hr_all_organization_units_tl org_tl,
             apps.hr_organization_information org_info,
             apps.per_all_people_f ppf
   WHERE org.organization_id = org_tl.organization_id
   AND org_tl.LANGUAGE = USERENV ('LANG')
   AND org.organization_id = org_info.organization_id
   AND org.TYPE = 'PHC_DEPT'
   AND org_info.org_information_context ='Organization Name Alias'
   AND org_info.org_information2 = to_char(ppf.person_id)
   AND to_char(ppf.person_id)=p_person_id
   AND TRUNC (SYSDATE)
                      BETWEEN TO_CHAR
                                (TO_DATE (SUBSTR (org_info.org_information3,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                 'DD-Mon-YYYY'
                                )
                          AND NVL
                                (TO_CHAR
                                    (TO_DATE
                                         (SUBSTR (org_info.org_information4,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                     'DD-Mon-YYYY'
                                    ),
                                 '31-Dec-4721'
                                )
               AND SYSDATE BETWEEN ppf.effective_start_date
                               AND ppf.effective_end_date
               AND EXISTS (
                      SELECT NULL
                        FROM apps.hr_org_info_types_by_class oitbc,
                             apps.hr_organization_information org_info1
                       WHERE org_info1.organization_id = org.organization_id
                         AND org_info1.org_information_context = 'CLASS'
                         AND org_info1.org_information2 = 'Y'
                         AND oitbc.org_classification =
                                                     org_info1.org_information1
                         AND oitbc.org_information_type =
                                                     'Organization Name Alias')
               AND (       DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                 ('HR_ALL_ORGANIZATION_UNITS',
                                                  org.organization_id
                                                 )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', org.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = org.business_group_id
                    OR     DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                         ('PER_ALL_PEOPLE_F',
                                                          ppf.person_id,
                                                          ppf.person_type_id,
                                                          ppf.employee_number,
                                                          ppf.applicant_number
                                                         )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', ppf.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = ppf.business_group_id
                   );

   return l_health_centre;

EXCEPTION
  WHEN OTHERS THEN
    return  '';
END;




FUNCTION xx_get_previous_status(p_privilege_area IN VARCHAR2,
                                p_person_id IN NUMBER )
return VARCHAR2
IS
 l_previous_status VARCHAR2(100):= NULL;

BEGIN
  select status
into l_previous_status
from (select area.status,area.request_dtl_id from  XXPHCC_CLINICAL_PRIV_AREA_STG area,XXPHCC_CLINICAL_PREVILEGE_STG priv,
APPS.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr
where  hdr.person_id= p_person_id
and hdr.request_hdr_id = priv.p_header_id
and priv.request_line_id= area.request_line_id
and area.p_area= p_privilege_area
and NVL(area.select_flag,'N')='Y'
order by area.request_dtl_id desc) where rownum=1;

return l_previous_status;

EXCEPTION
  WHEN OTHERS THEN
     return NULL;

END;










FUNCTION xx_get_previous_status(p_privilege_area IN VARCHAR2,
                                p_person_id IN NUMBER,
                                p_request_line_id IN NUMBER,
                                p_request_dtl_id IN NUMBER
                                )
 return VARCHAR2
 IS
   l_previous_status VARCHAR2(150):= NULL;
BEGIN

select status
into l_previous_status
from (select area.status,area.request_dtl_id from  XXPHCC_CLINICAL_PRIV_AREA_STG area,XXPHCC_CLINICAL_PREVILEGE_STG priv,
APPS.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr
where  hdr.person_id= p_person_id
and hdr.request_hdr_id <> (select p_header_id from XXPHCC_CLINICAL_PREVILEGE_STG where request_line_id =p_request_line_id)
and hdr.request_hdr_id = priv.p_header_id
and priv.request_line_id= area.request_line_id
and area.request_dtl_id <> p_request_dtl_id
and area.p_area= p_privilege_area
and NVL(area.select_flag,'N')='Y'
order by area.request_dtl_id desc) where rownum=1;

return l_previous_status;

EXCEPTION
 WHEN OTHERS THEN
   return NULL;
END ;





procedure xx_update_spl_privileges
(p_request_hdr_id IN VARCHAR2 ,
p_request_line_id IN VARCHAR2,
p_request_dtl_id IN VARCHAR2,
p_type_of_privilege IN VARCHAR2,
p_employee_number IN VARCHAR2,
p_area IN VARCHAR2,
p_status IN VARCHAR2,
p_start_date IN VARCHAR2,
p_end_date IN VARCHAR2,
p_comments IN VARCHAR2)
IS
  l_status VARCHAR2(20);
  l_start_date VARCHAR2(20);
  l_end_date VARCHAR2(20);
  l_employee_number VARCHAR2(100);
  l_person_id NUMBER;
  l_name VARCHAR2(200);
  l_exception VARCHAr2(1000);

  l_subject VARCHAR2(10000);
  l_html_content VARCHAR2(10000);
  l_role_name VARCHAR2(1000);
  l_user_name VARCHAR2(1000);
  xx NUMBER;
  l_html_body VARCHAR2(10000);

BEGIN


BEGIN
  SELECT fu.user_name
  INTO  l_role_name
  FROM fnd_user fu
  WHERE user_id= fnd_profile.value('USER_ID');
EXCEPTION
   WHEN OTHERS THEN
      l_role_name := 'HRSYSADMIN';
END;






   IF UPPER(p_type_of_privilege) = 'ADDITIONAL PRIVILEGE REQUEST'
   THEN

      BEGIN
       SELECT addPriv.status,to_char(addPriv.start_date,'YYYY-MM-DD'),to_char(addPriv.end_date,'YYYY-MM-DD'),ppf.person_id,ppf.employee_number,ppf.full_name
       INTO   l_status,l_start_date,l_end_date,
              l_person_id ,l_employee_number,
              l_name
       FROM XXPHCC_CLNCL_ADD_PRIV_REQ_TBL addPriv, XXPHCC_CLINICAL_PRIVILEGE_HDR HDR, per_all_people_f ppf
       WHERE addPriv.request_header_id= p_request_hdr_id
       AND addPriv.privilege_area = p_area
       AND addPriv.request_header_id= hdr.request_hdr_id
       AND hdr.person_id= addpriv.person_id
       AND hdr.person_id= ppf.person_id
       and ppf.employee_number= p_employee_number
       and trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(nvl(ppf.effective_end_date,SYSDATE+10)) ;
      EXCEPTION
        WHEN OTHERS THEN
            l_status:= null;
            l_start_date:= null;
            l_end_date:= null;
     END;

     IF NVL( l_status,'XX') != p_status OR  NVL(l_start_date,'0000-00-00')<> p_start_date OR NVL(l_end_date,'0000-00-00') <> p_end_date
     THEN
       Update  XXPHCC_CLNCL_ADD_PRIV_REQ_TBL addPriv
         set status= p_status,
             start_date = to_date(p_start_date,'YYYY-MM-DD'),
             end_date = to_date(p_end_date,'YYYY-MM-DD'),
             specialist_comments= p_comments,--NVL(p_comments,specialist_comments),
             last_updated_by = fnd_profile.value('USER_ID'),
             last_update_date= SYSDATE
       WHERE addPriv.request_header_id= p_request_hdr_id
         AND addPriv.privilege_area = p_area;

       -- Add code to insert into new table


     l_user_name := NULL;
     l_html_body := NULL;
      BEGIN
        SELECT fu.user_name
        into  l_user_name
        from   fnd_user fu
        where  fu.employee_id=  l_person_id
        AND  trunc(sysdate) between trunc(start_date) and trunc(NVL(end_date,sysdate+1));
      EXCEPTION
        WHEN OTHERS THEN
          l_user_name := NULL;
       END ;



     IF l_user_name IS NOT NULL
     THEN

      l_html_body := '<p> Dear ' || l_name ||'</p> <p>The below privilege area is updated by clinical privilege committee  representative</p>';
        l_html_body := l_html_body||'<p>Privilege Area  : <b>'||p_area||'</b></p>';
      l_html_body := l_html_body||'<p>Old Status :'||l_status||'</p><p> New Status :'||p_status||'</p>';
      l_html_body := l_html_body||'<p>Old Start Date :'|| to_char(to_date(l_start_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p><p> New Start Date :'|| to_char(to_date(p_start_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p>';
      l_html_body := l_html_body||'<p>Old End Date :'|| to_char(to_date(l_end_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p><p> New End Date :'|| to_char(to_date(p_end_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p>';

      xx := apps.irc_notification_helper_pkg.send_notification(p_user_name =>   l_user_name,
                                                                     p_subject   => 'Notification: Updation of privilege area by clinical privilege committee representative ',
                                                                     p_html_body => l_html_body,
                                                                     p_text_body => NULL,
                                                                     p_from_role => l_role_name);
     END  IF;



     END IF;

   ELSE
     BEGIN
       SELECT areastg.status,to_char(areastg.start_date,'YYYY-MM-DD'),to_char(areastg.end_date,'YYYY-MM-DD'),ppf.person_id,ppf.employee_number,ppf.full_name
       INTO  l_status,l_start_date,l_end_date,l_person_id ,l_employee_number,
             l_name
       FROM XXPHCC_CLINICAL_PRIV_AREA_STG areastg,
            XXPHCC_CLINICAL_PREVILEGE_STG privstg,
            XXPHCC_CLINICAL_PRIVILEGE_HDR HDR, per_all_people_f ppf
       WHERE hdr.request_hdr_id= p_request_hdr_id
       AND   privstg.p_header_id= hdr.request_hdr_id
       AND  privstg.request_line_id= p_request_line_id
       AND  areastg.request_line_id=privstg.request_line_id
       AND  areastg.p_area = p_area
       AND areastg.request_dtl_id = p_request_dtl_id
       AND hdr.person_id= ppf.person_id
       and ppf.employee_number= p_employee_number
       and trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(nvl(ppf.effective_end_date,SYSDATE+10)) ;
      EXCEPTION
        WHEN OTHERS THEN
            l_status:= null;
            l_start_date:= null;
            l_end_date:= null;
     END;

     IF NVL( l_status,'XX') != p_status OR  NVL(l_start_date,'0000-00-00')<> p_start_date OR NVL(l_end_date,'0000-00-00') <> p_end_date
     THEN
      Update  XXPHCC.XXPHCC_CLINICAL_PRIV_AREA_STG  areastg
         set status= p_status,
             start_date = to_date(p_start_date,'YYYY-MM-DD'),
             end_date = to_date(p_end_date,'YYYY-MM-DD'),
             specialist_comments =p_comments, -- NVL(p_comments,specialist_comments),
             last_updated_by = fnd_profile.value('USER_ID'),
             last_update_date= SYSDATE
       WHERE areastg.p_area = p_area
       AND   areastg.REQUEST_DTL_ID = p_request_dtl_id;

        -- Add code to send the alert
      l_user_name := NULL;
     l_html_body := NULL;
      BEGIN
        SELECT fu.user_name
        into  l_user_name
        from   fnd_user fu
        where  fu.employee_id=  l_person_id
        AND  trunc(sysdate) between trunc(start_date) and trunc(NVL(end_date,sysdate+1));
      EXCEPTION
        WHEN OTHERS THEN
          l_user_name := NULL;
       END ;


     IF l_user_name IS NOT NULL
     THEN

      l_html_body := '<p> Dear ' || l_name ||'</p> <p>The below privilege area is updated by clinical privilege committee representative </p>';
      l_html_body := l_html_body||'<p>Privilege Area  : <b>'||p_area||'</b></p>';
      l_html_body := l_html_body||'<p>Old Status :'||l_status||'</p><p> New Status :'||p_status||'</p>';
      l_html_body := l_html_body||'<p>Old Start Date :'|| to_char(to_date(l_start_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p><p> New Start Date :'|| to_char(to_date(p_start_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p>';
      l_html_body := l_html_body||'<p>Old End Date :'|| to_char(to_date(l_end_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p><p> New End Date :'|| to_char(to_date(p_end_date,'YYYY-MM-DD'),'DD-Mon-YYYY')||'</p>';


        xx := apps.irc_notification_helper_pkg.send_notification(p_user_name =>  l_user_name,
                                                                     p_subject   => 'Notification: Updation of privilege area by clinical privilege committee representative',
                                                                     p_html_body => l_html_body,
                                                                     p_text_body => NULL,
                                                                     p_from_role => l_role_name);


     END  IF;



   END IF;
END IF;
   COMMIT;

EXCEPTION
  WHEN OTHERS THEN
  l_exception := SUBSTR(SQLERRM,1,200);
   xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_spl_privileges : while setting the notification content: ' ||
                                                                         p_request_hdr_id|| ','||p_request_dtl_id,
                                                    p_log_type        => NULL);
END;





FUNCTION get_health_centre(p_person_id in VARCHAR2)
RETURN VARCHAR2
IS
  l_health_centre VARCHAR2(100);
BEGIN
  SELECT substr(org.NAME,INSTR(org.NAME,'.',-1,1)+1)
   INTO l_health_centre
  FROM apps.hr_all_organization_units org,
       apps.hr_all_organization_units_tl org_tl
WHERE org.organization_id = org_tl.organization_id
   AND org_tl.LANGUAGE = USERENV ('LANG')
   AND org.TYPE = 'PHC_DEPT'
   AND EXISTS (
          SELECT NULL
            FROM apps.hr_org_info_types_by_class oitbc,
                 apps.hr_organization_information org_info
           WHERE org_info.organization_id = org.organization_id
             AND org_info.org_information_context = 'CLASS'
             AND org_info.org_information2 = 'Y'
             AND oitbc.org_classification = org_info.org_information1
             AND oitbc.org_information_type = 'Organization Name Alias')
   AND (    DECODE (apps.hr_security.view_all,
                    'Y', 'TRUE',
                    apps.hr_security.show_record ('HR_ALL_ORGANIZATION_UNITS',
                                                  org.organization_id
                                                 )
                   ) = 'TRUE'
        AND DECODE (apps.hr_general.get_xbg_profile,
                    'Y', org.business_group_id,
                    apps.hr_general.get_business_group_id
                   ) = org.business_group_id
       )
   AND org.organization_id IN (
          SELECT     parent_organization_id
                FROM apps.hrfv_organization_hierarchies
               WHERE organization_hierarchy_name =
                                              'PHCC HR Organization Hierarchy'
                 AND primary_hierarchy_flag = 'Yes'
                 AND TRUNC (SYSDATE) BETWEEN hierarchy_version_start_date
                                         AND NVL (hierarchy_version_end_date,
                                                  TO_DATE ('31-12-4712',
                                                           'DD-MM-RRRR'
                                                          )
                                                 )
          CONNECT BY child_organization_id = PRIOR parent_organization_id
          START WITH child_organization_id =
                        (SELECT paaf.organization_id
                           FROM apps.per_all_assignments_f paaf
                          WHERE TRUNC (SYSDATE)
                                   BETWEEN paaf.effective_start_date
                                       AND paaf.effective_end_date
                            AND paaf.primary_flag = 'Y'
                            AND to_char(paaf.person_id) = p_person_id)
          UNION
          SELECT paaf.organization_id
            FROM apps.per_all_assignments_f paaf
           WHERE TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                     AND paaf.effective_end_date
             AND paaf.primary_flag = 'Y'
             AND to_char(paaf.person_id) = p_person_id)
             AND rownum=1;

             return l_health_centre;

EXCEPTION
  WHEN OTHERS THEN
    return '';
END ;


PROCEDURE xx_get_role (
     p_person_id IN VARCHAR2,
     p_role OUT VARCHAR2
   )
IS
l_count NUMBER:= null;

BEGIN

 BEGIN
  SELECT count(rls.role_name)
         INTO l_count
           FROM apps.pqh_roles_v rls, apps.per_people_extra_info pei,per_all_people_f ppf
          WHERE rls.role_id = TO_NUMBER (pei.pei_information3)
            AND NVL(rls.enable_flag,'N') ='Y'
            AND pei.information_type = 'PQH_ROLE_USERS'
            AND pei.person_id = ppf.person_id
            AND NVL(pei.pei_information5,'N') ='Y'
            AND rls.role_name='Clinical Privilege Committee'
            AND to_char(ppf.person_id)= p_person_id
            AND trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(NVL(ppf.effective_end_date,SYSDATE+1));
 EXCEPTION
    WHEN OTHERS THEN
     l_count:= 0;
 END ;

 IF l_count=0
 THEN
     p_role := '' ;
 ELSE
      p_role := 'Clinical Privilege Specialist' ;
 END IF;
EXCEPTION
   WHEN OTHERS THEN
       p_role:= '';

END;



 PROCEDURE xx_check_clinical_priv_dor (
     p_person_id IN VARCHAR2,
     p_result OUT VARCHAR2
   )
   IS
     l_count NUMBER:=0;
     l_QC_count NUMBER := 0;
     l_Cer_count  NUMBER := 0;
   BEGIN
/*     BEGIN
       SELECT count(*)
       INTO l_count
            FROM hr_document_extra_info docsofrecordeo,
                 hr_lookups hrl,
                 hr_document_types_v hdt,
                 per_people_f ppf
           WHERE  hrl.lookup_type = 'DOCUMENT_CATEGORY'
             AND hrl.lookup_code = hdt.category_code
             AND hdt.document_type='Clinical Privilege'
             AND hdt.document_type_id = docsofrecordeo.document_type_id
             AND ppf.person_id = docsofrecordeo.person_id
             AND to_char(ppf.person_id)= p_person_id
             AND trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(NVL(ppf.effective_end_date,SYSDATE+1))
             and (trunc(docsofrecordeo.date_from) > trunc(sysdate) or (trunc(sysdate) between trunc(date_from) and trunc(NVL(date_to,SYSDATE+360))));

     EXCEPTION
        WHEN OTHERS THEN
         l_count :=0;
     END ;
    IF l_count=0
    THEN
       p_result := 'Missing Document';
       return;
    Else  commented on 21 nov*/

        BEGIN
       SELECT count(*)
       INTO l_QC_count
            FROM hr_document_extra_info docsofrecordeo,
                 hr_lookups hrl,
                 hr_document_types_v hdt,
                 per_people_f ppf
           WHERE  hrl.lookup_type = 'DOCUMENT_CATEGORY'
             AND hrl.lookup_code = hdt.category_code
             AND hdt.document_type='Qualification Certificate'
             AND hdt.document_type_id = docsofrecordeo.document_type_id
             AND ppf.person_id = docsofrecordeo.person_id
             AND to_char(ppf.person_id)= p_person_id
             AND trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(NVL(ppf.effective_end_date,SYSDATE+1))
             and (trunc(docsofrecordeo.date_from) > trunc(sysdate) or (trunc(sysdate) between trunc(docsofrecordeo.date_from) and trunc(NVL(docsofrecordeo.date_to,SYSDATE+360))));

     EXCEPTION
        WHEN OTHERS THEN
         l_QC_count :=0;
     END ;

    IF l_QC_count=0
    THEN
       p_result := 'Missing Document';
       return;
    ELSE
       /* BEGIN
       SELECT count(*)
       INTO l_Cer_count
            FROM hr_document_extra_info docsofrecordeo,
                 hr_lookups hrl,
                 hr_document_types_v hdt,
                 per_people_f ppf
           WHERE  hrl.lookup_type = 'DOCUMENT_CATEGORY'
             AND hrl.lookup_code = hdt.category_code
             AND hdt.document_type='Certificates'
             AND hdt.document_type_id = docsofrecordeo.document_type_id
             AND ppf.person_id = docsofrecordeo.person_id
             AND to_char(ppf.person_id)= p_person_id
             AND trunc(sysdate) between trunc(ppf.effective_start_date) and trunc(NVL(ppf.effective_end_date,SYSDATE+1))
             and (trunc(docsofrecordeo.date_from) > trunc(sysdate) or (trunc(sysdate) between trunc(docsofrecordeo.date_from) and trunc(NVL(docsofrecordeo.date_to,SYSDATE+360))));

     EXCEPTION
        WHEN OTHERS THEN
         l_Cer_count :=0;
     END ;

    IF l_Cer_count=0
    THEN
       p_result := 'Missing Document';
       return;
    ELSE
       p_result := 'true';
    END IF;*/
      p_result := 'true';
    END IF;
    --END IF; ommented on 21 novc

   EXCEPTION
     WHEN OTHERS THEN
     p_result := 'true';
   END;





   PROCEDURE xx_check_license_number (
     p_person_id IN VARCHAR2,
     p_result OUT VARCHAR2
   )
  IS
     l_license_number VARCHAR2(20) :=NULL;
  BEGIN
  begin
    SELECT   pac.segment1
            INTO l_license_number
            FROM per_all_people_f papf,
                 per_person_analyses ppa,
                 fnd_id_flex_structures fifs,
                  per_analysis_criteria pac
           WHERE papf.person_id= p_person_id
             AND pac.id_flex_num = fifs.id_flex_num
             AND fifs.id_flex_structure_code = 'PHCC_LICENSE_FORM'
            AND ppa.person_id  = papf.person_id
             AND pac.analysis_criteria_id  = ppa.analysis_criteria_id
            AND pac.enabled_flag='Y'
        --    AND trunc(DECODE(pac.segment2,null,SYSDATE+1,to_date(pac.segment2,'YYYY/MM/DD HH24:MI:SS'))) > trunc(SYSDATE)-- As per BRKFIX02 TBD
            AND TRUNC(SYSDATE) BETWEEN TRUNC(papf.effective_start_date) AND TRUNC(NVL(papf.effective_end_date,SYSDATE+10))
            AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(pac.start_date_active,SYSDATE-1)) AND TRUNC(NVL(pac.end_date_active,SYSDATE+10));

  exception
    when others then
      l_license_number := NULL;
  end;

  IF l_license_number is NULL
  THEN
      p_result := 'true';
  ELSE
     p_result := 'false';
  END IF;


 EXCEPTION
   WHEN OTHERS THEN
     p_result := 'true';
 END;





  PROCEDURE xx_check_existence  (
   p_request_hdr_id IN VARCHAr2,
     p_person_id IN VARCHAR2,
     p_category_of_privilege IN VARCHAR2,
     p_area_of_privilege IN VARCHAr2,
     p_result OUT VARCHAR2
   )
  IS
   l_count1 NUMBER :=0;
   l_count2 NUMBER :=0;
   l_count NUMBER :=0;

  BEGIN



  begin
   Select count(1) INTO
    l_count1
    from xxphcc.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr,
         xxphcc.XXPHCC_CLINICAL_PRIV_AREA_STG  astg,
         xxphcc.xxphcc_clinical_previlege_stg pstg
    WHERE to_char(hdr.person_id) =  p_person_id
      AND to_char(hdr.request_hdr_id) <>  p_request_hdr_id
      AND hdr.request_hdr_id=  pstg.p_header_id
      AND pstg.request_line_id = astg.REQUEST_LINE_ID
      AND NVL(astg.select_flag,'N')='Y'
      --AND pstg.p_category= p_category_of_privilege
      AND astg.p_area =  p_area_of_privilege
      AND  UPPER(NVL(astg.status,'Active')) NOT IN ('CANCELLED','REJECTED','SUSPENDED','EXPIRED')
      AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(astg.start_date,SYSDATE-10)) AND TRUNC(NVL(astg.end_date,SYSDATE+10));


   Select count(1) INTO
    l_count2
    from xxphcc.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr,
          apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL  astg
    WHERE to_char(hdr.person_id) =  p_person_id
      AND to_char(hdr.request_hdr_id) <>  p_request_hdr_id
      AND hdr.request_hdr_id = astg.request_header_id
      AND astg.privilege_area =  p_area_of_privilege
      AND  UPPER(NVL(astg.status,'Active')) NOT IN ('CANCELLED','REJECTED','SUSPENDED','EXPIRED')
      AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(astg.start_date,SYSDATE-10)) AND TRUNC(NVL(astg.end_date,SYSDATE+10));


     l_count := l_count1+l_count2;

  exception
    when others then
      l_count:=0;
  end;

  if l_count <> 0
  then
     p_result :='true';
  else
      p_result :='false';
  end if;


  EXCEPTION
    When others then
        p_result :='true';
  END;

 PROCEDURE xx_check_save_existence  (
   p_request_hdr_id IN VARCHAr2,
     p_person_id IN VARCHAR2,
     p_result out varchar2
   )
  IS
   l_count1 NUMBER :=0;
   l_count2 NUMBER :=0;
   l_count NUMBER :=0;
    l_exception VARCHAR2(2000);

  BEGIN


  begin


   Select count(1) INTO
    l_count1
    from xxphcc.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr,
         xxphcc.XXPHCC_CLINICAL_PRIV_AREA_STG  astg,
         xxphcc.xxphcc_clinical_previlege_stg pstg
    WHERE to_char(hdr.person_id) =  p_person_id
      AND to_char(hdr.request_hdr_id) <>  p_request_hdr_id
      AND hdr.request_hdr_id=  pstg.p_header_id
      AND pstg.request_line_id = astg.REQUEST_LINE_ID
      AND NVL(astg.select_flag,'N')='Y'
      AND  UPPER(NVL(astg.status,'Active')) ='SAVED FOR LATER'
      AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(astg.start_date,SYSDATE-10)) AND TRUNC(NVL(astg.end_date,SYSDATE+10));


   Select count(1) INTO
    l_count2
    from xxphcc.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr,
          apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL  astg
    WHERE to_char(hdr.person_id) =  p_person_id
      AND to_char(hdr.request_hdr_id) <>  p_request_hdr_id
      AND hdr.request_hdr_id = astg.request_header_id
      AND  UPPER(NVL(astg.status,'Active'))='SAVED FOR LATER'
      AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(astg.start_date,SYSDATE-10)) AND TRUNC(NVL(astg.end_date,SYSDATE+10));


     l_count := l_count1+l_count2;

  exception
    when others then
      l_count:=0;
  end;

  if l_count <> 0
  then
     p_result :='true';
  else
      p_result :='false';
  end if;


  EXCEPTION
    When others then
        p_result :='true';
  END;

   PROCEDURE xx_start_wf (p_request_header_id IN VARCHAR2,
                          xx_process_name   IN VARCHAR2)
   IS
      l_location               VARCHAR2 (50)   := NULL;
      l_supervisor_id          VARCHAR2 (100)  := NULL;
      l_supervisor_user_name   VARCHAR2 (100)  := NULL;
      l_supervisor_name        VARCHAR2 (100)  := NULL;
      l_hc_manager_id          VARCHAR2 (50)   := NULL;
      l_hc_manager_user_name   VARCHAR2 (150)  := NULL;
      l_hc_manager_name        VARCHAR2 (100)  := NULL;
      l_prv_spl_id             VARCHAR2 (10)   := NULL;
      l_prv_spl_user_name      VARCHAR2 (150)  := NULL;
      l_prv_spl_name           VARCHAR2 (100)  := NULL;
      l_initiator_id           VARCHAR2 (100)  := NULL;
      l_initiator_name         VARCHAR2 (100)  := NULL;
      l_initiator_user_name    VARCHAR2 (100)  := NULL;
      l_item_key               VARCHAR2 (100)  := NULL;
      l_user_key               VARCHAR2 (100)  := NULL;
      l_item_type              VARCHAR2 (100)  := NULL;
      l_rn_value               VARCHAR2 (2000) := NULL;
      l_rn_action_history      VARCHAR2 (2000) := NULL;
      l_sub_dept_exist         BOOLEAN;
      l_exception              VARCHAR2 (100)  := NULL;
      l_document_id            CLOB;

      l_head_cov_user_name      VARCHAR2(100) := NULL;
      l_licprivcor_user_name    VARCHAR2(100):= NULL;

      l_concatenated_user_name   VARCHAR2(100):= NULL;
      l_role_name                VARCHAR2(100):= 'PRIVILEGING_SUPER_USER';
      l_role_display             VARCHAR2(100) := 'Privileging Super User';
      l_role_count NUMBER          :=0;

      l_regional_manager_id NUMBER := null;
      l_regional_manager_user_name VARCHAR2(50):= null;
      l_regional_manager_name VARCHAR2(1000):= null;



   BEGIN
      l_item_type := 'XXPERCPR';

      inv_log(l_item_type);
       
    IF   xx_process_name <> 'Renewal'
    THEN
      l_item_key := 'CPR-' || p_request_header_id;
      l_user_key := 'CPR-' || p_request_header_id;
   ELSE
      l_item_key := 'CPR-RE-' || p_request_header_id;
      l_user_key := 'CPR-RE-' || p_request_header_id;
   END IF;

    IF   xx_process_name ='Renewal'
    THEN
       BEGIN
         SELECT person_id
           INTO l_initiator_id
           FROM XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE TO_CHAR (renewal_request_id) = p_request_header_id
           AND rownum=1;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
      END;

ELSE
           BEGIN
         SELECT person_id
           INTO l_initiator_id
           FROM xxphcc_clinical_privilege_hdr
          WHERE TO_CHAR (request_hdr_id) = p_request_header_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
END;


END IF;


      BEGIN
         SELECT fu.user_name, pf.full_name
           INTO l_initiator_user_name, l_initiator_name
           FROM fnd_user fu, per_all_people_f pf
          WHERE pf.person_id = l_initiator_id
            AND fu.employee_id = pf.person_id
            AND TRUNC (SYSDATE) BETWEEN TRUNC (pf.effective_start_date)
                                    AND TRUNC (NVL (pf.effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              )
            AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                    AND TRUNC (NVL (fu.end_date, SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
      END;

      BEGIN
         SELECT supervisor_id
           INTO l_supervisor_id
           FROM per_all_assignments_f
          WHERE person_id = l_initiator_id
                 AND  TRUNC (SYSDATE) BETWEEN TRUNC (effective_start_date)
                                    AND TRUNC (NVL (effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              );

      EXCEPTION
         WHEN OTHERS
         THEN
            l_supervisor_id := NULL;
            DBMS_OUTPUT.put_line (SQLERRM);
      END;

      BEGIN
         SELECT fu.user_name, pf.full_name
           INTO l_supervisor_user_name, l_supervisor_name
           FROM fnd_user fu, per_all_people_f pf
          WHERE pf.person_id = l_supervisor_id
            AND fu.employee_id = pf.person_id
            AND TRUNC (SYSDATE) BETWEEN TRUNC (pf.effective_start_date)
                                    AND TRUNC (NVL (pf.effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              )
            AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                    AND TRUNC (NVL (fu.end_date, SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
            l_supervisor_user_name:='HRSYSADMIN';
            l_supervisor_name:= 'HR System Administrator';

            DBMS_OUTPUT.put_line (SQLERRM);
      END;

--change for HC manager
      BEGIN
         SELECT ppf.person_id
           INTO l_hc_manager_id
           FROM apps.hr_all_organization_units org,
                apps.hr_all_organization_units_tl org_tl,
                apps.hr_organization_information org_info2,
                apps.per_all_people_f ppf
          WHERE org_info2.organization_id = org.organization_id
            AND org_info2.org_information_context = 'Organization Name Alias'
            AND org_info2.org_information2 = TO_CHAR (ppf.person_id(+))
            AND org.organization_id = org_tl.organization_id
            AND org_tl.LANGUAGE = USERENV ('LANG')
            AND org.TYPE = 'PHC_SUBDEPT'
            AND TRUNC (SYSDATE)
                   BETWEEN TO_CHAR
                               (TO_DATE (SUBSTR (org_info2.org_information3,
                                                 1,
                                                 10
                                                ),
                                         'yyyy/mm/dd'
                                        ),
                                'DD-Mon-YYYY'
                               )
                       AND NVL
                             (TO_CHAR
                                 (TO_DATE
                                         (SUBSTR (org_info2.org_information4,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                  'DD-Mon-YYYY'
                                 ),
                              '31-Dec-4721'
                             )
            AND SYSDATE BETWEEN ppf.effective_start_date
                            AND ppf.effective_end_date
            AND EXISTS (
                   SELECT NULL
                     FROM apps.hr_org_info_types_by_class oitbc,
                          apps.hr_organization_information org_info
                    WHERE org_info.organization_id = org.organization_id
                      AND org_info.org_information_context = 'CLASS'
                      AND org_info.org_information2 = 'Y'
                      AND oitbc.org_classification = org_info.org_information1
                      AND oitbc.org_information_type =
                                                     'Organization Name Alias')
            AND (       DECODE
                           (apps.hr_security.view_all,
                            'Y', 'TRUE',
                            apps.hr_security.show_record
                                                 ('HR_ALL_ORGANIZATION_UNITS',
                                                  org.organization_id
                                                 )
                           ) = 'TRUE'
                    AND DECODE (apps.hr_general.get_xbg_profile,
                                'Y', org.business_group_id,
                                apps.hr_general.get_business_group_id
                               ) = org.business_group_id
                 OR     DECODE
                           (apps.hr_security.view_all,
                            'Y', 'TRUE',
                            apps.hr_security.show_record ('PER_ALL_PEOPLE_F',
                                                          ppf.person_id,
                                                          ppf.person_type_id,
                                                          ppf.employee_number,
                                                          ppf.applicant_number
                                                         )
                           ) = 'TRUE'
                    AND DECODE (apps.hr_general.get_xbg_profile,
                                'Y', ppf.business_group_id,
                                apps.hr_general.get_business_group_id
                               ) = ppf.business_group_id
                )
            AND org.organization_id IN (
                   SELECT     parent_organization_id
                         FROM apps.hrfv_organization_hierarchies
                        WHERE organization_hierarchy_name =
                                              'PHCC HR Organization Hierarchy'
                          AND primary_hierarchy_flag = 'Yes'
                          AND TRUNC (SYSDATE)
                                 BETWEEN hierarchy_version_start_date
                                     AND NVL (hierarchy_version_end_date,
                                              TO_DATE ('31-12-4712',
                                                       'DD-MM-RRRR'
                                                      )
                                             )
                   CONNECT BY child_organization_id =
                                                   PRIOR parent_organization_id
                   START WITH child_organization_id =
                                 (SELECT paaf.organization_id
                                    FROM apps.per_all_assignments_f paaf
                                   WHERE TRUNC (SYSDATE)
                                            BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                                     AND paaf.primary_flag = 'Y'
                                     AND paaf.person_id = l_initiator_id)
                   UNION
                   SELECT paaf.organization_id
                     FROM apps.per_all_assignments_f paaf
                    WHERE TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                              AND paaf.effective_end_date
                      AND paaf.primary_flag = 'Y'
                      AND paaf.person_id = l_initiator_id);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_sub_dept_exist := FALSE;
      END;

      ---------------------------Adding logic to include Sub_Department----------------------
      IF (l_sub_dept_exist = FALSE)
      THEN
         BEGIN
            SELECT ppf.person_id
              INTO l_hc_manager_id
              FROM apps.hr_all_organization_units org,
                   apps.hr_all_organization_units_tl org_tl,
                   apps.hr_organization_information org_info2,
                   apps.per_all_people_f ppf
             WHERE org_info2.organization_id = org.organization_id
               AND org_info2.org_information_context =
                                                     'Organization Name Alias'
               AND org_info2.org_information2 = TO_CHAR (ppf.person_id(+))
               AND org.organization_id = org_tl.organization_id
               AND org_tl.LANGUAGE = USERENV ('LANG')
               AND org.TYPE = 'PHC_DEPT'
               AND TRUNC (SYSDATE)
                      BETWEEN TO_CHAR
                                (TO_DATE (SUBSTR (org_info2.org_information3,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                 'DD-Mon-YYYY'
                                )
                          AND NVL
                                (TO_CHAR
                                    (TO_DATE
                                         (SUBSTR (org_info2.org_information4,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                     'DD-Mon-YYYY'
                                    ),
                                 '31-Dec-4721'
                                )
               AND SYSDATE BETWEEN ppf.effective_start_date
                               AND ppf.effective_end_date
               AND EXISTS (
                      SELECT NULL
                        FROM apps.hr_org_info_types_by_class oitbc,
                             apps.hr_organization_information org_info
                       WHERE org_info.organization_id = org.organization_id
                         AND org_info.org_information_context = 'CLASS'
                         AND org_info.org_information2 = 'Y'
                         AND oitbc.org_classification =
                                                     org_info.org_information1
                         AND oitbc.org_information_type =
                                                     'Organization Name Alias')
               AND (       DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                 ('HR_ALL_ORGANIZATION_UNITS',
                                                  org.organization_id
                                                 )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', org.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = org.business_group_id
                    OR     DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                         ('PER_ALL_PEOPLE_F',
                                                          ppf.person_id,
                                                          ppf.person_type_id,
                                                          ppf.employee_number,
                                                          ppf.applicant_number
                                                         )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', ppf.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = ppf.business_group_id
                   )
               AND org.organization_id IN (
                      SELECT     parent_organization_id
                            FROM apps.hrfv_organization_hierarchies
                           WHERE organization_hierarchy_name =
                                              'PHCC HR Organization Hierarchy'
                             AND primary_hierarchy_flag = 'Yes'
                             AND TRUNC (SYSDATE)
                                    BETWEEN hierarchy_version_start_date
                                        AND NVL (hierarchy_version_end_date,
                                                 TO_DATE ('31-12-4712',
                                                          'DD-MM-RRRR'
                                                         )
                                                )
                      CONNECT BY child_organization_id =
                                                   PRIOR parent_organization_id
                      START WITH child_organization_id =
                                    (SELECT paaf.organization_id
                                       FROM apps.per_all_assignments_f paaf
                                      WHERE TRUNC (SYSDATE)
                                               BETWEEN paaf.effective_start_date
                                                   AND paaf.effective_end_date
                                        AND paaf.primary_flag = 'Y'
                                        AND paaf.person_id = l_initiator_id)
                      UNION
                      SELECT paaf.organization_id
                        FROM apps.per_all_assignments_f paaf
                       WHERE TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                                 AND paaf.effective_end_date
                         AND paaf.primary_flag = 'Y'
                         AND paaf.person_id = l_initiator_id);
         EXCEPTION
            WHEN OTHERS
            THEN
               l_hc_manager_id := NULL;
         END;
      END IF;

      BEGIN
         SELECT fu.user_name, pf.full_name
           INTO l_hc_manager_user_name, l_hc_manager_name
           FROM fnd_user fu, per_all_people_f pf
          WHERE pf.person_id = l_hc_manager_id
            AND fu.employee_id = pf.person_id
            AND TRUNC (SYSDATE) BETWEEN TRUNC (pf.effective_start_date)
                                    AND TRUNC (NVL (pf.effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              )
            AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                    AND TRUNC (NVL (fu.end_date, SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
            l_hc_manager_user_name:='HRSYSADMIN';
            l_hc_manager_name:= 'HR System Administrator';

            DBMS_OUTPUT.put_line (SQLERRM);
      END;

----------regional Manager details

  BEGIN
   SELECT ppf.person_id
              INTO l_regional_manager_id
              FROM apps.hr_all_organization_units org,
                   apps.hr_all_organization_units_tl org_tl,
                   apps.hr_organization_information org_info2,
                   apps.per_all_people_f ppf
             WHERE org_info2.organization_id = org.organization_id
               AND org_info2.org_information_context =
                                                     'Organization Name Alias'
               AND org_info2.org_information2 = TO_CHAR (ppf.person_id(+))
               AND org.organization_id = org_tl.organization_id
               AND org_tl.LANGUAGE = USERENV ('LANG')
               AND org.TYPE = 'PHC_RDIRECT'
               AND TRUNC (SYSDATE)
                      BETWEEN TO_CHAR
                                (TO_DATE (SUBSTR (org_info2.org_information3,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                 'DD-Mon-YYYY'
                                )
                          AND NVL
                                (TO_CHAR
                                    (TO_DATE
                                         (SUBSTR (org_info2.org_information4,
                                                  1,
                                                  10
                                                 ),
                                          'yyyy/mm/dd'
                                         ),
                                     'DD-Mon-YYYY'
                                    ),
                                 '31-Dec-4721'
                                )
               AND SYSDATE BETWEEN ppf.effective_start_date
                               AND ppf.effective_end_date
               AND EXISTS (
                      SELECT NULL
                        FROM apps.hr_org_info_types_by_class oitbc,
                             apps.hr_organization_information org_info
                       WHERE org_info.organization_id = org.organization_id
                         AND org_info.org_information_context = 'CLASS'
                         AND org_info.org_information2 = 'Y'
                         AND oitbc.org_classification =
                                                     org_info.org_information1
                         AND oitbc.org_information_type =
                                                     'Organization Name Alias')
               AND (       DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                 ('HR_ALL_ORGANIZATION_UNITS',
                                                  org.organization_id
                                                 )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', org.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = org.business_group_id
                    OR     DECODE
                              (apps.hr_security.view_all,
                               'Y', 'TRUE',
                               apps.hr_security.show_record
                                                         ('PER_ALL_PEOPLE_F',
                                                          ppf.person_id,
                                                          ppf.person_type_id,
                                                          ppf.employee_number,
                                                          ppf.applicant_number
                                                         )
                              ) = 'TRUE'
                       AND DECODE (apps.hr_general.get_xbg_profile,
                                   'Y', ppf.business_group_id,
                                   apps.hr_general.get_business_group_id
                                  ) = ppf.business_group_id
                   )
               AND org.organization_id IN (
                      SELECT     parent_organization_id
                            FROM apps.hrfv_organization_hierarchies
                           WHERE organization_hierarchy_name =
                                              'PHCC HR Organization Hierarchy'
                             AND primary_hierarchy_flag = 'Yes'
                             AND TRUNC (SYSDATE)
                                    BETWEEN hierarchy_version_start_date
                                        AND NVL (hierarchy_version_end_date,
                                                 TO_DATE ('31-12-4712',
                                                          'DD-MM-RRRR'
                                                         )
                                                )
                      CONNECT BY child_organization_id =
                                                   PRIOR parent_organization_id
                      START WITH child_organization_id =
                                    (SELECT paaf.organization_id
                                       FROM apps.per_all_assignments_f paaf
                                      WHERE TRUNC (SYSDATE)
                                               BETWEEN paaf.effective_start_date
                                                   AND paaf.effective_end_date
                                        AND paaf.primary_flag = 'Y'
                                        AND paaf.person_id = l_initiator_id)
                      UNION
                      SELECT paaf.organization_id
                        FROM apps.per_all_assignments_f paaf
                       WHERE TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                                 AND paaf.effective_end_date
                         AND paaf.primary_flag = 'Y'
                         AND paaf.person_id = l_initiator_id);
         EXCEPTION
            WHEN OTHERS
            THEN
               l_regional_manager_id := NULL;
         END;


      BEGIN
         SELECT fu.user_name, pf.full_name
           INTO l_regional_manager_user_name, l_regional_manager_name
           FROM fnd_user fu, per_all_people_f pf
          WHERE pf.person_id = l_regional_manager_id
            AND fu.employee_id = pf.person_id
            AND TRUNC (SYSDATE) BETWEEN TRUNC (pf.effective_start_date)
                                    AND TRUNC (NVL (pf.effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              )
            AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                    AND TRUNC (NVL (fu.end_date, SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
            l_regional_manager_user_name:='HRSYSADMIN';
            l_regional_manager_name:= 'HR System Administrator';


            DBMS_OUTPUT.put_line (SQLERRM);
      END;













------------------privilege specialist role


      BEGIN
         SELECT pei.person_id
           INTO l_prv_spl_id
           FROM apps.pqh_roles_v rls, apps.per_people_extra_info pei
          WHERE rls.role_id = TO_NUMBER (pei.pei_information3)
            AND pei.information_type = 'PQH_ROLE_USERS'
            AND rls.role_name = 'Clinical Privilege Committee'
            AND NVL(rls.enable_flag,'N')='Y'
            AND NVL(pei.pei_information5,'N')='Y';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
      END;

      BEGIN
         SELECT fu.user_name, pf.full_name
           INTO l_prv_spl_user_name, l_prv_spl_name
           FROM fnd_user fu, per_all_people_f pf
          WHERE pf.person_id = l_prv_spl_id
            AND fu.employee_id = pf.person_id
            AND TRUNC (SYSDATE) BETWEEN TRUNC (pf.effective_start_date)
                                    AND TRUNC (NVL (pf.effective_end_date,
                                                    SYSDATE + 1
                                                   )
                                              )
            AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                    AND TRUNC (NVL (fu.end_date, SYSDATE + 1));
      EXCEPTION
         WHEN OTHERS
         THEN
           l_prv_spl_user_name:='HRSYSADMIN';
           l_prv_spl_name:= 'HR System Administrator';

            DBMS_OUTPUT.put_line (SQLERRM);
      END;


      -- second  level changes

    BEGIN
      select LISTAGG(  fu.user_name, '  ') WITHIN GROUP (ORDER BY user_name )
          INTO l_concatenated_user_name
           FROM apps.pqh_roles_v rls, apps.per_people_extra_info pei,per_all_people_f ppf,fnd_user fu
          WHERE rls.role_id = TO_NUMBER (pei.pei_information3)
            AND pei.information_type = 'PQH_ROLE_USERS'
            AND rls.role_name = 'Privileging Super User'
            AND NVL(rls.enable_flag,'N')='Y'
            AND pei.person_id= ppf.person_id
            AND ppf.person_id= fu.employee_id
            AND NVL(pei.pei_information5,'N')='Y'
            AND TRUNC(SYSDATE) between TRUNC(ppf.effective_start_date) AND TRUNC(NVL(ppf.effective_end_date,SYSDATE+1))
            AND TRUNC(SYSDATE) between TRUNC(fu.start_date) AND TRUNC(NVL(fu.end_date,SYSDATE+1));
      EXCEPTION
         WHEN OTHERS
         THEN
            l_concatenated_user_name := 'HRSYSADMIN';
            DBMS_OUTPUT.put_line (SQLERRM);
      END;


--


     /* BEGIN
         SELECT  fu.user_name--pei.person_id
           INTO l_head_cov_user_name
           FROM apps.pqh_roles_v rls, apps.per_people_extra_info pei,per_all_people_f ppf,fnd_user fu
          WHERE rls.role_id = TO_NUMBER (pei.pei_information3)
            AND pei.information_type = 'PQH_ROLE_USERS'
            AND rls.role_name = 'Head Of Clinical Verification'
            AND NVL(rls.enable_flag,'N')='Y'
            AND pei.person_id= ppf.person_id
            AND ppf.person_id= fu.employee_id
            AND TRUNC(SYSDATE) between TRUNC(ppf.effective_start_date) AND TRUNC(NVL(ppf.effective_end_date,SYSDATE+1))
            AND TRUNC(SYSDATE) between TRUNC(fu.start_date) AND TRUNC(NVL(fu.end_date,SYSDATE+1));
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
      END;

        BEGIN
         SELECT  fu.user_name--pei.person_id
           INTO l_licprivcor_user_name
           FROM apps.pqh_roles_v rls, apps.per_people_extra_info pei,per_all_people_f ppf,fnd_user fu
          WHERE rls.role_id = TO_NUMBER (pei.pei_information3)
            AND pei.information_type = 'PQH_ROLE_USERS'
            AND rls.role_name = 'Lic And Priv Coordinator'
            AND NVL(rls.enable_flag,'N')='Y'
            AND pei.person_id= ppf.person_id
            AND ppf.person_id= fu.employee_id
            AND TRUNC(SYSDATE) between TRUNC(ppf.effective_start_date) AND TRUNC(NVL(ppf.effective_end_date,SYSDATE+1))
            AND TRUNC(SYSDATE) between TRUNC(fu.start_date) AND TRUNC(NVL(fu.end_date,SYSDATE+1));
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (SQLERRM);
      END;*/


      --l_concatenated_user_name := l_head_cov_user_name || ' '|| l_licprivcor_user_name;


      wf_engine.createprocess (itemtype        => l_item_type,
                               itemkey         => l_item_key,
                               owner_role      => l_initiator_user_name,
                               user_key        => l_user_key,
                               process         => 'XX_MAIN'
                              );


IF xx_process_name = 'Renewal'
THEN

     wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'RENEWAL_REQUEST_ID',
                                 avalue        => p_request_header_id
                                );
ELSE
     wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'REQUEST_HEADER_ID',
                                 avalue        => p_request_header_id
                                );


END IF;

        l_role_name := 'PRIVILEGING_SUPER_USER';
         l_role_display := 'Privileging Super User';

    Begin
       select count(name)
         INTO l_role_count
       from wf_local_roles
       where name='PRIVILEGING_SUPER_USER' ;
    Exception
       When others then
          l_role_count :=null;
    end;

    IF l_role_count=0 THEN
         wf_directory.CreateAdHocRole(l_role_name ,
                                      l_role_display,
                                       NULL,
                                       NULL,
                                      'Privileging Super User',
                                       'MAILHTML',
                                       UPPER(l_concatenated_user_name),
                                       NULL,
                                       NULL,
                                      'ACTIVE',
                                       NULL);

ELSE

  apps.wf_directory.removeusersfromadhocrole
                (role_name      => l_role_name);

      WF_DIRECTORY.AddUsersToAdHocRole(l_role_name ,UPPER(l_concatenated_user_name));

END IF;

       wf_engine.setitemattrtext (itemtype      => l_item_type,
                                   itemkey       => l_item_key,
                                   aname         => 'XX_ADHOC_ROLE',
                                   avalue        =>  l_role_name

                                  );




       wf_engine.setitemattrnumber (itemtype      => l_item_type,
                                   itemkey       => l_item_key,
                                   aname         => 'LOOP_COUNTER',
                                   avalue        => 1
                                  );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => '#FROM_ROLE',
                                 avalue        => l_initiator_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'WF_NOTE',
                                 avalue        => NULL
                                );


       wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_PROCESS',
                                 avalue        => xx_process_name
                                );

        -- As per BRKFIX02 
        wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_ITEM_KEY',
                                 avalue        => l_item_key
                                );

         begin
               wf_engine.setitemattrdocument (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_RET_FOR_CORR_DATA',
                                 documentid        => 'PLSQL:XX_PER_CLINICAL_PRIVILEGE_PKG.XX_SET_RFC_NOTIF_BODY/'||l_item_key 
                                 --documentid        => 'JSP:/OA_HTML/OA.jsp?OAFunc=XX_NEW_REGION_FN'
                                 );
        exception when others then
            xx_debug_script_p('Clinical Privilage. Error:'||SQLERRM);
        end;

IF xx_process_name <> 'Renewal' THEN
      wf_engine.setitemattrdocument
         (itemtype        => l_item_type,
          itemkey         => l_item_key,
          aname           => 'XX_NOTIF_BODY',
          documentid      =>    'JSP:/OA_HTML/OA.jsp?OAFunc=XXPHCCCLINICALPRIVNOTIFRN&requestHdrId='
                             || p_request_header_id
                             || '&wfItemType='
                             || l_item_type
                             || '&wfItemKey='
                             || l_item_key
         );
END IF;

IF xx_process_name = 'Renewal'
THEN
    wf_engine.setitemattrdocument
         (itemtype        => l_item_type,
          itemkey         => l_item_key,
          aname           => 'XX_RENEWAL_NOTIF_BODY',
            documentid      =>    'JSP:/OA_HTML/OA.jsp?OAFunc=XXPHCCCLINICALPRIVRENEWNOTIFRN&RenewalRequestId='
                             || p_request_header_id
                             || '&wfItemType='
                             || l_item_type
                             || '&wfItemKey='
                             || l_item_key
         );
END IF;





       IF xx_process_name ='Creation'  THEN
        wf_engine.setitemattrdocument
         (itemtype        => l_item_type,
          itemkey         => l_item_key,
          aname           => 'XX_EMP_NOTIF_BODY',
          documentid      => 'PLSQL:XX_PER_CLINICAL_PRIVILEGE_PKG.XX_SET_NOTIF_BODY/' || l_item_key
         );
     ELSE

         wf_engine.setitemattrdocument
         (itemtype        => l_item_type,
          itemkey         => l_item_key,
          aname           => 'XX_EMP_RENEWAL_NOTIF_BODY',
          documentid      => 'PLSQL:XX_PER_CLINICAL_PRIVILEGE_PKG.XX_SET_RENEWAL_NOTIF_BODY/' || l_item_key
         );
     END IF;



--       wf_engine.setitemattrdocument
--         (itemtype        => l_item_type,
--          itemkey         => l_item_key,
--          aname           => '#HISTORY',
--          documentid      =>    'JSP:/OA_HTML/OA.jsp?OAFunc=XXPHCCCLINICALPRIVACTIONHISTRN'
--                             || '&wfItemType='
--                             || l_item_type
--                             || '&wfItemKey='
--                             || l_item_key
--         );


      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_INITIATOR',
                                 avalue        => l_initiator_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_INITIATOR_NAME',
                                 avalue        => l_initiator_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_SUPERVISOR',
                                 avalue        => l_supervisor_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_SUPERVISOR_NAME',
                                 avalue        => l_supervisor_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_HC_MANAGER',
                                 avalue        => l_hc_manager_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_HC_MANAGER_NAME',
                                 avalue        => l_hc_manager_name
                                );

       wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_REGIONAL_MANAGER',
                                 avalue        => l_regional_manager_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_REGIONAL_MANAGER_NAME',
                                 avalue        => l_regional_manager_name
                                );


      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_PRIVILEGE_SPECIALIST',
                                 avalue        => l_prv_spl_user_name
                                );
      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => l_item_key,
                                 aname         => 'XX_PRIVILEGE_SPECIALIST_NAME',
                                 avalue        => l_prv_spl_name
                                );
      wf_engine.startprocess (itemtype => l_item_type, itemkey => l_item_key);






IF xx_process_name <> 'Renewal'
THEN
     UPDATE xxphcc.xxphcc_clinical_privilege_hdr
         SET wf_item_type = l_item_type,
             wf_item_key = l_item_key
       WHERE TO_CHAR (request_hdr_id) = p_request_header_id;

    UPDATE  xxphcc.XXPHCC_CLINICAL_PRIV_AREA_STG
      set status= 'Pending For Approval'
      WHERE request_line_id  IN (select request_line_id from XXPHCC.XXPHCC_CLINICAL_PREVILEGE_STG
                                  where to_char(p_header_id) = p_request_header_id)
      AND  NVL(Select_flag,'N')='Y';

    UPDATE  xxphcc.XXPHCC_CLINICAL_PRIV_AREA_STG
      set status= NULL
      WHERE request_line_id  IN (select request_line_id from XXPHCC.XXPHCC_CLINICAL_PREVILEGE_STG
                                  where to_char(p_header_id) = p_request_header_id)
      AND  NVL(Select_flag,'N')='N';



  UPDATE  apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
      set status= 'Pending For Approval'
      Where to_char(request_header_id)=  p_request_header_id;



ELSE
     UPDATE XXPHCC_CLIN_PRIV_RENEW_TBL
         SET Status='Pending Renewal Approval',
             wf_item_type = l_item_type,
             wf_item_key = l_item_key
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id AND NVL(SELECT_FLAG,'N')='Y';

     UPDATE   xxphcc.XXPHCC_CLINICAL_PRIV_AREA_STG ASTG
      set ASTG.Status='Pending Renewal Approval',
           ASTG.comments= NVL((Select comments from XXPHCC_CLIN_PRIV_RENEW_TBL
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id
       AND NVL(SELECT_FLAG,'N')='Y' AND request_dtl_id=ASTG.request_dtl_id ),ASTG.comments)
      Where request_dtl_id in (Select request_dtl_id from XXPHCC_CLIN_PRIV_RENEW_TBL
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id AND NVL(SELECT_FLAG,'N')='Y' );

       UPDATE  apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL x
      set status= 'Pending Renewal Approval',
          comments = (Select comments from XXPHCC_CLIN_PRIV_RENEW_TBL
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id AND NVL(SELECT_FLAG,'N')='Y' AND type_of_privilege='Additional Privilege Request'
                  and x.privilege_area= p_area)
      Where to_char(request_header_id) IN  (Select request_hdr_id from XXPHCC_CLIN_PRIV_RENEW_TBL
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id AND NVL(SELECT_FLAG,'N')='Y' AND type_of_privilege='Additional Privilege Request')
      AND privilege_area  IN (Select P_AREA from XXPHCC_CLIN_PRIV_RENEW_TBL
       WHERE TO_CHAR (renewal_request_id) = p_request_header_id AND NVL(SELECT_FLAG,'N')='Y' AND type_of_privilege='Additional Privilege Request') ;


END IF;
      COMMIT;


   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => l_item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_start_wf : while launching the workflow: ' ||l_item_key ,
                                                    p_log_type        => NULL);
   END xx_start_wf;

   PROCEDURE xx_set_current_approver (
      itemtype   IN       VARCHAR2,
      itemkey    IN       VARCHAR2,
      actid      IN       NUMBER,
      funcmode   IN       VARCHAR2,
      RESULT     IN OUT   VARCHAR2
   )
   IS
      l_loop_count              NUMBER         := NULL;
      l_current_approver_name   VARCHAR2 (200) := NULL;
      l_current_approver        VARCHAR2 (200) := NULL;
      l_previous_approver       VARCHAR2 (200) := NULL;
      l_exception               VARCHAR2 (200) := NULL;
      l_hc_manager              VARCHAR2(200)  := NULL;
      l_regional_manager        VARCHAR2(200) := NULL;
      l_initiator              VARCHAR2(200)  := NULL;
      l_previous_approver_name   VARCHAR2(1000):= NULL;
   BEGIN
      IF funcmode = 'RUN'
      THEN
         l_loop_count :=
            wf_engine.getitemattrnumber (itemtype      => itemtype,
                                         itemkey       => itemkey,
                                         aname         => 'LOOP_COUNTER'
                                        );
         wf_engine.setitemattrtext (itemtype      => itemtype,
                                    itemkey       => itemkey,
                                    aname         => 'WF_NOTE',
                                    avalue        => NULL
                                   );
         wf_engine.setitemattrtext (itemtype      => itemtype,
                                    itemkey       => itemkey,
                                    aname         => 'ACTION_TAKEN',
                                    avalue        => NULL
                                   );


         l_initiator :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_INITIATOR'
                                         );


                     l_hc_manager :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_HC_MANAGER'
                                         );

                  l_regional_manager :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_REGIONAL_MANAGER'
                                         );



         IF l_loop_count = 1
         THEN
            l_current_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_SUPERVISOR'
                                         );
            l_current_approver_name :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_SUPERVISOR_NAME'
                                         );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER',
                                       avalue        => l_current_approver
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER_NAME',
                                       avalue        => l_current_approver_name
                                      );
         ELSIF l_loop_count = 2
         THEN
            l_previous_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_SUPERVISOR'
                                         );

             l_previous_approver_name := wf_engine.getitemattrtext (itemtype      => itemtype,
                                                 itemkey       => itemkey,
                                                 aname         => 'XX_SUPERVISOR_NAME'
                                                );




            /* Added for second level changes*/
             IF l_initiator= l_hc_manager
             THEN
                 IF  l_hc_manager=l_regional_manager
                 THEN
                   l_current_approver :=
                        wf_engine.getitemattrtext (itemtype      => itemtype,
                                                    itemkey       => itemkey,
                                                      aname         => 'XX_ADHOC_ROLE'
                                         );


                    l_current_approver_name := 'Privileging Super User';


                      wf_engine.setitemattrNumber (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'LOOP_COUNTER',
                                       avalue        =>3
                                      );


                 ELSE

                    l_current_approver :=
                        wf_engine.getitemattrtext (itemtype      => itemtype,
                                                    itemkey       => itemkey,
                                                      aname         => 'XX_REGIONAL_MANAGER'
                                         );


                    l_current_approver_name := wf_engine.getitemattrtext (itemtype      => itemtype,
                                                    itemkey       => itemkey,
                                                      aname         => 'XX_REGIONAL_MANAGER_NAME'
                                         );


                 END IF;
             ELSE
              l_current_approver_name :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_HC_MANAGER_NAME'
                                         );
                 l_current_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_HC_MANAGER'
                                         );
            END IF;


            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER',
                                       avalue        => l_current_approver
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER_NAME',
                                       avalue        => l_current_approver_name
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => '#FROM_ROLE',
                                       avalue        => l_previous_approver
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_PREVIOUS_APPROVER_NAME',
                                       avalue        => l_previous_approver_name
                                      );

         ELSIF l_loop_count = 3
         THEN
           IF l_initiator= l_hc_manager
           THEN
             IF  l_regional_manager= l_hc_manager
             THEN
                 l_previous_approver :=wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_SUPERVISOR'
                                         );


                  l_previous_approver_name := wf_engine.getitemattrtext (itemtype      => itemtype,
                                                 itemkey       => itemkey,
                                                 aname         => 'XX_SUPERVISOR_NAME'
                                                );
             ELSE
             l_previous_approver :=wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_REGIONAL_MANAGER'
                                         );


             l_previous_approver_name := wf_engine.getitemattrtext (itemtype      => itemtype,
                                                 itemkey       => itemkey,
                                                 aname         => 'XX_REGIONAL_MANAGER_NAME'
                                                );
              END IF;

           ELSE
            l_previous_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_HC_MANAGER'
                                         );


           l_previous_approver_name := wf_engine.getitemattrtext (itemtype      => itemtype,
                                                 itemkey       => itemkey,
                                                 aname         => 'XX_HC_MANAGER_NAME'
                                                );

          END IF;

           l_current_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_ADHOC_ROLE'
                                         );

          /*begin
            select full_name
            INTO l_current_approver_name
            from per_all_people_f
            where  person_id= (select employee_id from fnd_user where user_id= fnd_profile.VALUE ('USER_ID'))
            and trunc(sysdate) between trunc(effective_start_date) and trunc(nvl(effective_end_date,sysdate+1));

          exception
             when others
             then
               l_current_approver_name := 'Line Manager';
           end;*/

               l_current_approver_name := 'Privileging Super User';

               /*wf_engine.getitemattrtext
                                      (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'Line Manager'
                                      );*/
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER',
                                       avalue        => l_current_approver
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER_NAME',
                                       avalue        => l_current_approver_name
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => '#FROM_ROLE',
                                       avalue        => l_previous_approver
                                      );

             wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_PREVIOUS_APPROVER_NAME',
                                       avalue        => l_previous_approver_name
                                      );

         ELSIF l_loop_count = 4
         THEN
            l_previous_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_ADHOC_ROLE'
                                         );
            l_current_approver :=
               wf_engine.getitemattrtext (itemtype      => itemtype,
                                          itemkey       => itemkey,
                                          aname         => 'XX_PRIVILEGE_SPECIALIST'
                                         );
            l_current_approver_name :=
               wf_engine.getitemattrtext
                                      (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_PRIVILEGE_SPECIALIST_NAME'
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER',
                                       avalue        => l_current_approver
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => 'XX_CURRENT_APPROVER_NAME',
                                       avalue        => l_current_approver_name
                                      );
            wf_engine.setitemattrtext (itemtype      => itemtype,
                                       itemkey       => itemkey,
                                       aname         => '#FROM_ROLE',
                                       avalue        => l_previous_approver
                                      );
         END IF;


      END IF;

      RESULT := 'COMPLETE:' || 'Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         RESULT := 'COMPLETE:' || 'N';
   END xx_set_current_approver;

   PROCEDURE xx_is_last_approver (
      itemtype   IN       VARCHAR2,
      itemkey    IN       VARCHAR2,
      actid      IN       NUMBER,
      funcmode   IN       VARCHAR2,
      RESULT     IN OUT   VARCHAR2
   )
   IS
      l_loop_count   NUMBER         := NULL;
      l_exception    VARCHAR2 (100) := NULL;
   BEGIN
      IF funcmode = 'RUN'
      THEN
         l_loop_count :=
            wf_engine.getitemattrnumber (itemtype      => itemtype,
                                         itemkey       => itemkey,
                                         aname         => 'LOOP_COUNTER'
                                        );

         IF l_loop_count < 4
         THEN
            l_loop_count := l_loop_count + 1;
            wf_engine.setitemattrnumber (itemtype      => itemtype,
                                         itemkey       => itemkey,
                                         aname         => 'LOOP_COUNTER',
                                         avalue        => l_loop_count
                                        );
            RESULT := 'COMPLETE:' || 'N';
         ELSE
            RESULT := 'COMPLETE:' || 'Y';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
         RESULT := 'COMPLETE:' || 'N';
   END xx_is_last_approver;



PROCEDURE get_loop_count  (item_type  IN VARCHAR2,
                                  item_key   IN VARCHAR2,
                                  actid      IN NUMBER,
                                  funcmode   IN VARCHAR2,
                                  result_out IN OUT VARCHAR2
    )
   IS
      l_loop_count   NUMBER         := NULL;
      l_exception    VARCHAR2 (100) := NULL;
   BEGIN
      IF funcmode = 'RUN'
      THEN
         l_loop_count :=
            wf_engine.getitemattrnumber (itemtype      => item_type,
                                         itemkey       => item_key,
                                         aname         => 'LOOP_COUNTER'
                                        );


             result_out := 'COMPLETE:' || l_loop_count ;

      ELSE
             result_out := 'COMPLETE:' || '0' ;
      END IF;


   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
        result_out := 'COMPLETE:' || '0' ;
   END get_loop_count;


  PROCEDURE xx_are_all_privileges_rejected (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      l_request_hdr_id   VARCHAR2 (10)  := NULL;
      l_count            NUMBER         := NULL;
      l_exception        VARCHAR2 (100) := NULL;
      l_ad_count      NUMBER := NULL;
      l_total_count NUMBER :=NULL;
   BEGIN
      l_request_hdr_id :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'REQUEST_HEADER_ID'
                                   );

      BEGIN
         SELECT COUNT (DISTINCT xcps.p_area)
           INTO l_count
           FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE TO_CHAR (xcph.request_hdr_id) = l_request_hdr_id
            AND xcph.request_hdr_id = xcpg.p_header_id
            AND xcps.request_line_id = xcpg.request_line_id
            AND xcps.select_flag = 'Y'
            AND NVL (xcps.wfstatus, 'APPROVED') <> 'REJECTED';
      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);
            l_count := 1;
      END;

      BEGIN
         SELECT COUNT (SEQUENCE_NUMBER)
           INTO l_ad_count
           FROM apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
          WHERE TO_CHAR(request_header_id)= l_request_hdr_id
          AND UPPER(NVL(status,'ACTIVE')) <> 'REJECTED';
      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);
            l_ad_count := 1;
      END;

      l_total_count := NVL(l_count,0)+ NVL(l_ad_count,0);

      IF l_total_count = 0
      THEN
         result_out := 'COMPLETE:Y';
      ELSE
         result_out := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
     xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_are_all_privileges_rejected : while checking the process type: ' ||item_key,
                                                    p_log_type        => NULL);
   END;


   PROCEDURE xx_is_renewal_process (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      l_process_name   VARCHAR2 (100)  := NULL;
  --    l_count            NUMBER         := NULL;
      l_exception        VARCHAR2 (100) := NULL;
   BEGIN
      l_process_name :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'XX_PROCESS'
                                   );

      IF l_process_name = 'Renewal'
      THEN
         result_out := 'COMPLETE:Y';
      ELSE
         result_out := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
     xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_is_renewal_process : while checking the process type: ' ||item_key ,
                                                    p_log_type        => NULL);

   END;

     PROCEDURE xx_are_all_renew_priv_rejected (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      L_RENEWAL_REQUEST_ID   VARCHAR2 (10)  := NULL;
      l_count            NUMBER         := NULL;
      l_exception        VARCHAR2 (100) := NULL;
   BEGIN
      L_RENEWAL_REQUEST_ID :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'RENEWAL_REQUEST_ID'
                                   );

      BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE NVL(status,'Active') <>   'Rejected' and to_char(RENEWAL_REQUEST_ID) = L_RENEWAL_REQUEST_ID;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);
           --Lakshmi
            l_count := 1;
      END;

      IF l_count = 0
      THEN
         result_out := 'COMPLETE:Y';
      ELSE
         result_out := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_are_all_renew_priv_rejected : while checking the rejected privileges: ' ||item_key,
                                                    p_log_type        => NULL);

   END;

     PROCEDURE xx_update_renew_request_dates (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      L_RENEWAL_REQUEST_ID   VARCHAR2 (100) := NULL;
      l_priv_spl_name    VARCHAR2 (100) := NULL;
      l_priv_spl_id      NUMBER         := NULL;
      l_exception        VARCHAR2 (100);
   BEGIN
      L_RENEWAL_REQUEST_ID :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'RENEWAL_REQUEST_ID'
                                   );
      l_priv_spl_name :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'XX_PRIVILEGE_SPECIALIST'
                                   );

      BEGIN
         SELECT user_id
           INTO l_priv_spl_id
           FROM fnd_user
          WHERE user_name = l_priv_spl_name;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_priv_spl_id := NULL;
      END;


      Update XXPHCC_CLIN_PRIV_RENEW_TBL
       SET start_date = trunc(SYSDATE),
             end_date = trunc(ADD_MONTHS (SYSDATE, 12 * 2)),
             status = 'Active',
             last_updated_by = l_priv_spl_id,
             last_update_date = SYSDATE
      where to_char(renewal_request_id)= L_RENEWAL_REQUEST_ID
       and  NVL(status,'Active') <> 'Rejected'
        AND NVL(select_flag,'N')='Y';

    For   r_details in (select * from  XXPHCC_CLIN_PRIV_RENEW_TBL
      where to_char(renewal_request_id)= L_RENEWAL_REQUEST_ID
       and  NVL(status,'Active') <> 'Rejected' AND upper(type_of_privilege) <>'ADDITIONAL PRIVILEGE REQUEST'
       AND NVL(select_flag,'N')='Y')
    LOOP

      UPDATE xxphcc_clinical_priv_area_stg
         SET start_date = trunc(SYSDATE),
             end_date = trunc(ADD_MONTHS (SYSDATE, 12 * 2)),
             comments = NVL(r_details.approval_comments,comments),
             status = 'Active',
            -- wfstatus = 'APPROVED',
             last_updated_by = l_priv_spl_id,
             last_update_date = SYSDATE
       WHERE request_dtl_id= r_details.request_dtl_id;

    END LOOP;

     For   r_details in (select * from  XXPHCC_CLIN_PRIV_RENEW_TBL
      where to_char(renewal_request_id)= L_RENEWAL_REQUEST_ID
       and  NVL(status,'Active') <> 'Rejected' AND upper(type_of_privilege) ='ADDITIONAL PRIVILEGE REQUEST'
        AND NVL(select_flag,'N')='Y')
    LOOP

      UPDATE XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
         SET start_date = trunc(SYSDATE),
             end_date = trunc(ADD_MONTHS (SYSDATE, 12 * 2)),
             status = 'Active',
             comments=NVL(r_details.approval_comments,comments),
            -- wfstatus = 'APPROVED',
             last_updated_by = l_priv_spl_id,
             last_update_date = SYSDATE
       WHERE request_header_id= r_details.request_hdr_id
         AND privilege_area = r_details.p_area ;

    END LOOP;

     For   r_details in (select * from  XXPHCC_CLIN_PRIV_RENEW_TBL
      where to_char(renewal_request_id)= L_RENEWAL_REQUEST_ID
       and  NVL(status,'Active') = 'Rejected' AND upper(type_of_privilege) <>'ADDITIONAL PRIVILEGE REQUEST'
       AND   NVL(select_flag,'N')='Y')
    LOOP

      UPDATE xxphcc_clinical_priv_area_stg
         SET comments=NVL(r_details.approval_comments,r_details.privilege_specialist_comments)
       WHERE request_dtl_id= r_details.request_dtl_id;

    END LOOP;

     For   r_details in (select * from  XXPHCC_CLIN_PRIV_RENEW_TBL
      where to_char(renewal_request_id)= L_RENEWAL_REQUEST_ID
       and  NVL(status,'Active') = 'Rejected' AND upper(type_of_privilege) ='ADDITIONAL PRIVILEGE REQUEST' AND  NVL(select_flag,'N')='Y')
    LOOP

      UPDATE XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
         SET comments=NVL(r_details.approval_comments,r_details.privilege_specialist_comments)
       WHERE request_header_id= r_details.request_hdr_id
         AND privilege_area = r_details.p_area ;

    END LOOP;


      result_out := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
        xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_renew_request_dates : while updating the  rejection status and comments: ' ||item_key,
                                                    p_log_type        => NULL);
         result_out := 'COMPLETE:Y';
   END;

      PROCEDURE xx_update_renew_reject_status (
      p_renewal_request_id IN VARCHAR2,
      p_request_dtl_id  IN VARCHAR2,
      p_request_line_id IN VARCHAR2,
      p_supervisor_comments IN VARCHAr2,
      p_hc_manager_comments IN VARCHAR2,
      p_line_manager_comments  IN VARCHAR2,
      p_priv_spl_commets  IN VARCHAR2,
       p_approval_comments  IN VARCHAR2
   )
   IS
      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN



      BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM  XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL(status,'Active') <> 'Rejected'
           AND  renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND request_line_id = p_request_line_id;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);

            l_count := 0;
      END;


    --  IF l_count <> 0
     -- THEN
         BEGIN
            UPDATE XXPHCC_CLIN_PRIV_RENEW_TBL
               SET status = 'Rejected',
                   supervisor_comments= p_supervisor_comments,
                   hc_manager_comments = p_hc_manager_comments,
                   Line_manager_comments =    p_line_manager_comments,
                   PRIVILEGE_SPECIALIST_COMMENTS=  p_priv_spl_commets ,
                   approval_comments = p_approval_comments,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND request_line_id = p_request_line_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);

            --Lakshmi
         END;

        BEGIN
            UPDATE xxphcc_clinical_priv_area_stg
               SET status = 'Rejected',
                  -- supervisor_comments= p_supervisor_comments,
                  -- hc_manager_comments = p_hc_manager_comments,
                  -- PRIVILEGE_SPECIALIST_COMMENTS=  p_priv_spl_commets ,
                  -- line_manager_comments =line_manager_comments,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE --renewal_request_id= p_renewal_request_id
           --AND
            request_dtl_id = p_request_dtl_id;
          -- AND request_line_id = p_request_line_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);
         END;
     -- END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_renew_reject_status : while updating the  rejection status and comments: ' ||
                                                                         p_renewal_request_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
   END;



   PROCEDURE xx_update_renew_comments (
      p_renewal_request_id IN VARCHAR2,
      p_request_dtl_id  IN VARCHAR2,
      p_request_line_id IN VARCHAR2,
      p_supervisor_comments IN VARCHAR2,
      p_hc_manager_comments IN VARCHAR2,
      p_line_manager_comments IN VARCHAR2,
      p_priv_spl_comments IN VARCHAR2,
      p_approval_comments IN VARCHAR2
   )
   IS
      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN

      /*BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM  XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL(status,'Active') <> 'Rejected'
           AND  renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND request_line_id = p_request_line_id;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);

            INSERT INTO xx_test
                 VALUES ('xx_update_renew_comments-Test-1',
                         p_renewal_request_id,
                         p_request_dtl_id,null,null,null);

            COMMIT;
            l_count := 0;
      END;

      INSERT INTO xx_test
           VALUES ( p_renewal_request_id, 'xx_update_renew_comments-Test-1', '1-msg ',
                   TO_CHAR (l_count), NULL, NULL);

      COMMIT;

      IF l_count <> 0
      THEN*/
         BEGIN
            UPDATE XXPHCC_CLIN_PRIV_RENEW_TBL
               SET supervisor_comments = p_supervisor_comments,
                   hc_manager_comments =  p_hc_manager_comments,
                   line_manager_comments= p_line_manager_comments,
                   privilege_specialist_comments= p_priv_spl_comments,
                   approval_comments=p_approval_comments,
                   status='Pending Renewal Approval',
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND request_line_id = p_request_line_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;
          BEGIN
            UPDATE xxphcc_clinical_priv_area_stg
               SET --supervisor_comments = p_supervisor_comments,
                  -- hc_manager_comments =  p_hc_manager_comments,
                  -- privilege_specialist_comments= p_priv_spl_comments,
                   status='Pending Renewal Approval',
                --   comments = NVL(p_comments,comments),
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE /*renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND */
           request_dtl_id = p_request_dtl_id
           and status='Rejected';
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);
                xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_renew_comments : while updating the  rejection status and comments: ' ||
                                                                         p_renewal_request_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
         END;



     -- END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 2,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_renew_comments : while updating the  rejection status and comments: ' ||
                                                                         p_renewal_request_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
   END;


    PROCEDURE xx_addpriv_reject_status (
     p_renewal_request_id IN VARCHAR2,
     p_request_hdr_id IN VARCHAR2,
     p_privilege_area IN VARCHAR2,
     p_supervisor_comments IN VARCHAR2,
     p_hc_manager_comments IN VARCHAR2,
     p_line_manager_comments IN VARCHAR2,
     p_priv_spl_comments IN VARCHAR2 ,
     p_approval_comments IN VARCHAR2
   ) IS

      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN



      BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM  XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL(status,'Active') <> 'Rejected'
           AND  renewal_request_id= p_renewal_request_id
           AND UPPER(TYPE_OF_PRIVILEGE)='ADDITIONAL PRIVILEGE REQUEST'
           AND to_char(request_hdr_id) = p_request_hdr_id
           AND p_area = p_privilege_area;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);


            l_count := 0;
      END;



     -- IF l_count <> 0
      --THEN
         BEGIN
            UPDATE XXPHCC_CLIN_PRIV_RENEW_TBL
               SET status = 'Rejected',
                   supervisor_comments= p_supervisor_comments,
                   hc_manager_comments = p_hc_manager_comments,
                   Line_manager_comments =    p_line_manager_comments,
                   PRIVILEGE_SPECIALIST_COMMENTS=  p_priv_spl_comments ,
                   approval_comments=p_approval_comments,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE renewal_request_id= p_renewal_request_id
           AND UPPER(TYPE_OF_PRIVILEGE)='ADDITIONAL PRIVILEGE REQUEST'
           AND to_char(request_hdr_id) = p_request_hdr_id
           AND p_area = p_privilege_area;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);
         END;

        BEGIN
            UPDATE XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
               SET status = 'Rejected',
                  -- supervisor_comments= p_supervisor_comments,
                  -- hc_manager_comments = p_hc_manager_comments,
                  -- PRIVILEGE_SPECIALIST_COMMENTS=  p_priv_spl_commets ,
                  -- line_manager_comments =line_manager_comments,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE --renewal_request_id= p_renewal_request_id
           --AND
           to_char(request_header_id) = p_request_hdr_id
           AND privilege_area = p_privilege_area;
          -- AND request_line_id = p_request_line_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);

         END;
     -- END IF;

      COMMIT;

   EXCEPTION
    WHEN OTHERS THEN
       xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_addpriv_reject_status : while updating the  rejection status and comments: ' ||
                                                                         p_renewal_request_id||','|| p_request_hdr_id,
                                                    p_log_type        => NULL);
    END;


   PROCEDURE xx_update_addpriv_comments (
      p_renewal_request_id IN VARCHAR2,
     p_request_hdr_id IN VARCHAR2,
     p_privilege_area IN VARCHAR2,
     p_supervisor_comments IN VARCHAR2,
     p_hc_manager_comments IN VARCHAR2,
     p_line_manager_comments IN VARCHAR2,
     p_priv_spl_comments IN VARCHAR2,
     p_approval_comments IN VARCHAr2
   )
   IS
      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN

      /*BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM  XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL(status,'Active') <> 'Rejected'
           AND  renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND request_line_id = p_request_line_id;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);

            INSERT INTO xx_test
                 VALUES ('xx_update_renew_comments-Test-1',
                         p_renewal_request_id,
                         p_request_dtl_id,null,null,null);

            COMMIT;
            l_count := 0;
      END;

      INSERT INTO xx_test
           VALUES ( p_renewal_request_id, 'xx_update_renew_comments-Test-1', '1-msg ',
                   TO_CHAR (l_count), NULL, NULL);

      COMMIT;

      IF l_count <> 0
      THEN*/
         BEGIN
            UPDATE XXPHCC_CLIN_PRIV_RENEW_TBL
               SET supervisor_comments = p_supervisor_comments,
                   hc_manager_comments =  p_hc_manager_comments,
                   line_manager_comments= p_line_manager_comments,
                   privilege_specialist_comments= p_priv_spl_comments,
                   approval_comments=p_approval_comments,
                   status='Pending Renewal Approval',
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE renewal_request_id= p_renewal_request_id
           AND UPPER(TYPE_OF_PRIVILEGE)='ADDITIONAL PRIVILEGE REQUEST'
           AND to_char(request_hdr_id) = p_request_hdr_id
           AND p_area = p_privilege_area;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);


         END;
          BEGIN
            UPDATE XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
               SET --supervisor_comments = p_supervisor_comments,
                  -- hc_manager_comments =  p_hc_manager_comments,
                  -- privilege_specialist_comments= p_priv_spl_comments,
                   status='Pending Renewal Approval',
                --   comments = NVL(p_comments,comments),
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
         WHERE /*renewal_request_id= p_renewal_request_id
           AND request_dtl_id = p_request_dtl_id
           AND */
           to_char(request_header_id) = p_request_hdr_id
           AND privilege_area = p_privilege_area
           and status='Rejected';

         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);
         END;



     -- END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
         xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_addpriv_comments : while updating the  status and comments: ' ||
                                                                         p_renewal_request_id||','|| p_request_hdr_id,
                                                    p_log_type        => NULL);
   END;



    PROCEDURE xx_update_comments (
      p_request_hdr_id      IN   VARCHAR2,
      p_request_line_id     IN   VARCHAR2,
      p_request_dtl_id     IN   VARCHAR2,
     -- p_req_category        IN   VARCHAR2,
      p_req_area            IN   VARCHAR2,
     -- p_scope_of_practice   IN   VARCHAR2,
     -- p_type_of_privilege   IN   VARCHAR2,
      p_supervisor_comments IN VARCHAR2,
      p_hc_manager_comments IN VARCHAR2,
      p_line_manager_comments IN VARCHAR2,
      p_priv_spl_comments IN VARCHAR2,
      p_approval_comments IN VARCHAR2
   )
   IS
      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN

     /* BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE TO_CHAR (xcph.request_hdr_id) = p_request_hdr_id
            AND TO_CHAR (xcps.request_line_id) =
                                                TO_CHAR (xcpg.request_line_id)
            AND TO_CHAR (xcph.request_hdr_id) = TO_CHAR (xcpg.p_header_id)
            AND xcps.select_flag = 'Y'
            AND TO_CHAR (xcps.request_line_id) = p_request_line_id
            AND TO_CHAR(xcps.request_dtl_id) = p_request_dtl_id
--            AND xcpg.type_of_privilege = p_type_of_privilege
--            AND xcpg.p_category = p_req_category
--            AND xcph.scope_of_practice = p_scope_of_practice
            AND NVL (xcps.wfstatus, 'APPROVED') <> 'REJECTED'
            AND xcps.p_area = p_req_area;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);

            INSERT INTO xx_test
                 VALUES ('xx_update_comments-Test-2',
                         p_request_hdr_id || '-' || p_request_line_id,
                         NULL, NULL, p_req_area,
                         l_exception);

            COMMIT;
            l_count := 0;
      END;

      INSERT INTO xx_test
           VALUES (p_request_hdr_id, 'xx_update_comments', '1-msg ',
                   TO_CHAR (l_count), NULL, NULL);

      COMMIT;

      IF l_count <> 0
      THEN*/
         BEGIN
            UPDATE xxphcc_clinical_priv_area_stg
               SET supervisor_comments = p_supervisor_comments,
                   hc_manager_comments=p_hc_manager_comments,
                   line_manager_comments=p_line_manager_comments,
                   PRIVILEGE_SPECIALIST_COMMENTS = p_priv_spl_comments,
                   APPROVAL_COMMENTS = p_approval_comments,
                   wfstatus=null,
                   status='Pending For Approval',
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE TO_CHAR (request_line_id) = p_request_line_id
               AND TO_CHAR (request_dtl_id) = p_request_dtl_id
               AND select_flag = 'Y'
               AND p_area = p_req_area;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);

               xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_comments : while updating the  status and comments: ' ||
                                                                         p_request_hdr_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
         END;
     -- END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
           xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 2,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_comments : while updating the  status and comments: ' ||
                                                                         p_request_hdr_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
   END;




   PROCEDURE xx_update_rejection_status (
      p_request_hdr_id      IN   VARCHAR2,
      p_request_line_id     IN   VARCHAR2,
        p_request_dtl_id     IN   VARCHAR2,
     -- p_req_category        IN   VARCHAR2,
      p_req_area            IN   VARCHAR2,
    --  p_scope_of_practice   IN   VARCHAR2,
    --  p_type_of_privilege   IN   VARCHAR2,
      p_supervisor_comments IN VARCHAR2,
      p_hc_manager_comments IN VARCHAR2,
      p_line_manager_comments IN VARCHAR2,
      p_priv_spl_comments IN VARCHAR2,
      p_approval_comments IN VARCHAR2
   )
   IS
      l_count       NUMBER         := NULL;
      l_exception   VARCHAR2 (100) := NULL;
   BEGIN


      BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE TO_CHAR (xcph.request_hdr_id) = p_request_hdr_id
            AND TO_CHAR (xcps.request_line_id) =
                                                TO_CHAR (xcpg.request_line_id)
            AND TO_CHAR (xcph.request_hdr_id) = TO_CHAR (xcpg.p_header_id)
            AND xcps.select_flag = 'Y'
            AND TO_CHAR (xcps.request_line_id) = p_request_line_id
            AND TO_CHAR (xcps.request_dtl_id) = p_request_dtl_id
            --AND xcpg.type_of_privilege = p_type_of_privilege
           -- AND xcpg.p_category = p_req_category
           -- AND xcph.scope_of_practice = p_scope_of_practice
            AND NVL (xcps.wfstatus, 'APPROVED') <> 'REJECTED'
            AND xcps.p_area = p_req_area;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);
            l_count := 0;
      END;



     -- IF l_count <> 0
     -- THEN
         BEGIN
            UPDATE xxphcc_clinical_priv_area_stg
               SET wfstatus = 'REJECTED',
                   status = 'Rejected',
                   rejected_by = fnd_profile.VALUE ('USER_ID'),
                   supervisor_comments = p_supervisor_comments,
                   hc_manager_comments=p_hc_manager_comments,
                   line_manager_comments = p_line_manager_comments,
                   PRIVILEGE_SPECIALIST_COMMENTS = p_priv_spl_comments,
                   approval_comments = p_approval_comments,
                   last_update_date = SYSDATE,
                   last_updated_by = fnd_profile.VALUE ('USER_ID')
             WHERE TO_CHAR (request_dtl_id) = p_request_dtl_id
               AND select_flag = 'Y'
               AND p_area = p_req_area;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := SUBSTR (SQLERRM, 1, 90);
         END;
     -- END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
             xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => NULL,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_rejection_status : while updating the rejection status: ' ||
                                                                         p_request_hdr_id||','|| p_request_dtl_id,
                                                    p_log_type        => NULL);
   END;

   /*PROCEDURE xx_are_all_privileges_rejected (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      l_request_hdr_id   VARCHAR2 (10)  := NULL;
      l_count            NUMBER         := NULL;
      l_exception        VARCHAR2 (100) := NULL;
   BEGIN
      l_request_hdr_id :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'REQUEST_HEADER_ID'
                                   );

      BEGIN
         SELECT COUNT (DISTINCT xcps.p_area)
           INTO l_count
           FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE TO_CHAR (xcph.request_hdr_id) = l_request_hdr_id
            AND xcph.request_hdr_id = xcpg.p_header_id
            AND xcps.request_line_id = xcpg.request_line_id
            AND xcps.select_flag = 'Y'
            AND NVL (xcps.wfstatus, 'APPROVED') <> 'REJECTED';
      EXCEPTION
         WHEN OTHERS
         THEN
            l_exception := SUBSTR (SQLERRM, 1, 90);

            INSERT INTO xx_test
                 VALUES ('xx_are_all_privileges_rejected-Test-1',
                         l_request_hdr_id, l_exception, NULL, NULL, NULL);

            COMMIT;
            l_count := 1;
      END;

      IF l_count = 0
      THEN
         result_out := 'COMPLETE:Y';
      ELSE
         result_out := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);

         INSERT INTO xx_test
              VALUES ('xx_are_all_privileges_rejected-Test-2',
                      l_request_hdr_id, l_exception, NULL, NULL, NULL);

         COMMIT;
   END;*/

   PROCEDURE xx_update_request_dates (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   )
   IS
      l_request_hdr_id   VARCHAR2 (100) := NULL;
      l_priv_spl_name    VARCHAR2 (100) := NULL;
      l_priv_spl_id      NUMBER         := NULL;
      l_exception        VARCHAR2 (100);
   BEGIN
      l_request_hdr_id :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'REQUEST_HEADER_ID'
                                   );
      l_priv_spl_name :=
         wf_engine.getitemattrtext (itemtype      => item_type,
                                    itemkey       => item_key,
                                    aname         => 'XX_PRIVILEGE_SPECIALIST'
                                   );

      BEGIN
         SELECT user_id
           INTO l_priv_spl_id
           FROM fnd_user
          WHERE user_name = l_priv_spl_name;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_priv_spl_id := NULL;
      END;

      UPDATE xxphcc_clinical_priv_area_stg
         SET start_date =trunc( SYSDATE),
             end_date = trunc(ADD_MONTHS (SYSDATE, 12 * 2)),
             status = 'Active',
             wfstatus = 'APPROVED',
             comments = NVL(approval_comments,comments),
             last_updated_by = l_priv_spl_id,
             last_update_date = SYSDATE
       WHERE request_line_id IN (
                SELECT DISTINCT request_line_id
                           FROM xxphcc_clinical_previlege_stg xcps,
                                xxphcc_clinical_privilege_hdr xcph
                          WHERE xcps.p_header_id = xcph.request_hdr_id
                            AND TO_CHAR (xcph.request_hdr_id) =
                                                              l_request_hdr_id)
         AND NVL (wfstatus, 'APPROVED') <> 'REJECTED'
         AND select_flag = 'Y';



     UPDATE xxphcc_clinical_priv_area_stg
         SET comments= NVL(approval_comments,privilege_specialist_comments)
       WHERE request_line_id IN (
                SELECT DISTINCT request_line_id
                           FROM xxphcc_clinical_previlege_stg xcps,
                                xxphcc_clinical_privilege_hdr xcph
                          WHERE xcps.p_header_id = xcph.request_hdr_id
                            AND TO_CHAR (xcph.request_hdr_id) =
                                                              l_request_hdr_id)
         AND UPPER(NVL(status,'Active'))= 'REJECTED'
         AND select_flag = 'Y';







     UPDATE   apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
     set start_date =trunc( SYSDATE),
             end_date = trunc(ADD_MONTHS (SYSDATE, 12 * 2)),
             status = 'Active',
             last_updated_by = l_priv_spl_id,
             last_update_date = SYSDATE
     Where to_char(request_header_id)   =  l_request_hdr_id
     AND UPPER(NVL (status, 'Active')) <> 'REJECTED';

        UPDATE   apps.XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
     set comments = NVL(approval_comments,privilege_specialist_comments)
     Where to_char(request_header_id)   =  l_request_hdr_id
     AND UPPER(NVL (status, 'Active'))= 'REJECTED';


      result_out := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
               xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_request_dates : while setting the dates and statuses: ' ||
                                                                         item_key,
                                                    p_log_type        => NULL);



         result_out := 'COMPLETE:Y';
   END;

   PROCEDURE xx_update_action_taken (item_key IN VARCHAR2)
   IS
      l_item_type   VARCHAR2 (100) := 'XXPERCPR';
      l_exception   VARCHAR2 (100);
   BEGIN

      wf_engine.setitemattrtext (itemtype      => l_item_type,
                                 itemkey       => item_key,
                                 aname         => 'ACTION_TAKEN',
                                 avalue        => 'Yes'
                                );
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_update_action_taken : while setting the action taken: ' ||
                                                                         item_key,
                                                    p_log_type        => NULL);

   END;

    PROCEDURE xx_get_loop_count (item_key IN VARCHAR2,loop_count OUT NUMBER)
   IS
      l_item_type   VARCHAR2 (100) := 'XXPERCPR';
      l_loop_count NUMBER;
      l_exception   VARCHAR2 (100);
   BEGIN

      loop_count := wf_engine.getitemAttrNumber (itemtype      => l_item_type,
                                 itemkey       => item_key,
                                 aname         => 'LOOP_COUNTER'
                                );
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);

         loop_count := 0;
         xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'OAF',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_get_loop_count : while getting the loop count: ' ||
                                                                         item_key,
                                                    p_log_type        => NULL);
   END;

   PROCEDURE xx_set_notif_body (
      document_id     IN              VARCHAR2,
      display_type    IN              VARCHAR2,
      document        IN OUT NOCOPY   VARCHAR2,
      document_type   IN OUT NOCOPY   VARCHAR2
   )
   IS
      l_html_body        CLOB           := EMPTY_CLOB ();
      l_item_key         VARCHAR2 (60)  := NULL;
      l_request_hdr_id   VARCHAR2 (100);
      l_count1 NUMBER:= 0;
      l_count2 NUMBER:=0;

      l_approved_count   NUMBER         := NULL;
      l_rejected_count   NUMBER         := NULL;
      l_initiator_name   VARCHAR2(100) := NULL;
      l_current_approver_name VARCHAr2(100) := NULL;
      l_exception  VARCHAR2 (100);

      CURSOR c_approved_items (pp_header_id VARCHAR2)
      IS
        Select * from  (
        SELECT DISTINCT xcph.position_name, xcph.scope_of_practice,
                         xcpg.type_of_privilege, xcpg.p_category,
                         xcps.status p_status, xcps.start_date p_start_date,
                         xcps.end_date p_end_date, xcps.comments p_comments,
                         xcps.supervisor_comments, xcps.hc_manager_comments,xcps.line_manager_comments,xcps.PRIVILEGE_SPECIALIST_COMMENTS,
                         xcps.approval_COMMENTS,
                         xcph.request_hdr_id, xcps.p_area,
                         xcps.last_updated_by, ppf.full_name rejected_by,
                         (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xcpg.P_CATEGORY AND
                         PREVILEGE_AREA=xcps.P_AREA  AND ROWNUM=1) SEQ_NUM
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         xxphcc_clinical_priv_area_stg xcps,
                         xxphcc_clinical_previlege_stg xcpg,
                         fnd_user fu,
                         per_all_people_f ppf
                   WHERE xcph.request_hdr_id = xcpg.p_header_id
                     AND xcps.request_line_id = xcpg.request_line_id
                     AND xcps.select_flag = 'Y'
                     AND NVL (xcps.status, 'Active') = 'Active'
                     AND TO_CHAR (xcph.request_hdr_id) = pp_header_id
                     AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xcps.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   )

           UNION
                  SELECT DISTINCT xcph.position_name, xcph.scope_of_practice,
                         'Additional Privilege Request' type_of_privilege, NULL p_category,
                         xcps.status p_status, xcps.start_date p_start_date,
                         xcps.end_date p_end_date, xcps.comments p_comments,
                         xcps.supervisor_comments, xcps.hc_manager_comments,xcps.line_manager_comments,xcps.PRIVILEGE_SPECIALIST_COMMENTS,
                         xcps.approval_COMMENTS,
                         xcph.request_hdr_id, xcps.privilege_area,
                         xcps.last_updated_by, ppf.full_name rejected_by,
                         100 SEQ_NUM
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         XXPHCC_CLNCL_ADD_PRIV_REQ_TBL    xcps,
                         fnd_user fu,
                         per_all_people_f ppf
             WHERE     xcph.request_hdr_id= pp_header_id
                     AND xcps.status <> 'Rejected'
                     AND xcps.request_header_id= xcph.request_hdr_id
                     AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xcps.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   ))     order by DECODE(type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4')
                                                   ,SEQ_NUM;



      CURSOR c_rejected_items (pp_header_id VARCHAR2)
      IS
      select * from  (
        SELECT DISTINCT xcph.position_name, xcph.scope_of_practice,
                         xcpg.type_of_privilege, xcpg.p_category,
                         xcps.status p_status, xcps.start_date p_start_date,
                         xcps.end_date p_end_date, xcps.comments p_comments,
                          xcps.supervisor_comments, xcps.hc_manager_comments,xcps.LINE_MANAGER_COMMENTS,xcps.PRIVILEGE_SPECIALIST_COMMENTS,
                         xcps.approval_COMMENTS,
                         xcph.request_hdr_id, xcps.p_area,
                         xcps.last_updated_by, ppf.full_name rejected_by,
                          (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xcpg.P_CATEGORY AND
                         PREVILEGE_AREA=xcps.P_AREA  AND ROWNUM=1) SEQ_NUM
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         xxphcc_clinical_priv_area_stg xcps,
                         xxphcc_clinical_previlege_stg xcpg,
                         fnd_user fu,
                         per_all_people_f ppf
                   WHERE xcph.request_hdr_id = xcpg.p_header_id
                     AND xcps.request_line_id = xcpg.request_line_id
                     AND xcps.select_flag = 'Y'
                     AND wfstatus = 'REJECTED'
                     AND xcps.status = 'Rejected'
                     AND TO_CHAR (xcph.request_hdr_id) = pp_header_id
                     AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xcps.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   )
                 UNION
                  SELECT DISTINCT xcph.position_name, xcph.scope_of_practice,
                         'Additional Privilege Request' type_of_privilege, NULL p_category,
                         xcps.status p_status, xcps.start_date p_start_date,
                         xcps.end_date p_end_date, xcps.comments p_comments,
                         xcps.supervisor_comments, xcps.hc_manager_comments,xcps.line_manager_comments,xcps.PRIVILEGE_SPECIALIST_COMMENTS,
                         xcps.approval_COMMENTS,
                         xcph.request_hdr_id, xcps.privilege_area,
                         xcps.last_updated_by, ppf.full_name rejected_by,
                         100 SEQ_NUM
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         XXPHCC_CLNCL_ADD_PRIV_REQ_TBL    xcps,
                         fnd_user fu,
                         per_all_people_f ppf
             WHERE     xcph.request_hdr_id= pp_header_id
                      AND xcps.status = 'Rejected'
                     AND xcps.request_header_id= xcph.request_hdr_id
                     AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xcps.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   ))
               order by DECODE(type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4'),SEQ_NUM;



   BEGIN
      document_type := 'text/html';
      l_item_key := document_id;


      l_request_hdr_id :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'REQUEST_HEADER_ID'
                                   );

        l_initiator_name :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'XX_INITIATOR_NAME'
                                   );

       l_current_approver_name :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'XX_CURRENT_APPROVER_NAME'
                                   );






      BEGIN
          SELECT COUNT (xcps.p_area)
                   into l_count1
                   FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE xcph.request_hdr_id = xcpg.p_header_id
            AND xcps.request_line_id = xcpg.request_line_id
            AND xcps.select_flag = 'Y'
            AND NVL (xcps.status, 'Active') = 'Active'
            AND TO_CHAR (xcph.request_hdr_id) = l_request_hdr_id  ;

      Select count(privilege_area)
      into l_count2
      from XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
      where to_char(request_header_id) = l_request_hdr_id
      and NVL(status,'Active')='Active';


      l_approved_count := l_count1 + l_count2;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_approved_count := 0;
      END;

    l_count1:=0;
    l_count2:=0;


      BEGIN
         SELECT COUNT (xcps.p_area)
           INTO l_count1
           FROM xxphcc_clinical_privilege_hdr xcph,
                xxphcc_clinical_priv_area_stg xcps,
                xxphcc_clinical_previlege_stg xcpg
          WHERE xcph.request_hdr_id = xcpg.p_header_id
            AND xcps.request_line_id = xcpg.request_line_id
            AND xcps.select_flag = 'Y'
            AND NVL (xcps.status, 'Active') = 'Rejected'
            AND TO_CHAR (xcph.request_hdr_id) = l_request_hdr_id;



       Select count(privilege_area)
      into l_count2
      from XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
      where to_char(request_header_id) = l_request_hdr_id
      and NVL(status,'Active')='Rejected';

      l_rejected_count := l_count1 + l_count2;

      EXCEPTION
         WHEN OTHERS
         THEN
            l_rejected_count := 0;
      END;

      l_html_body := '<html><body>';


         l_html_body :=  l_html_body|| 'Dear '||l_initiator_name||'  '||'<br/><br/>';

   --  IF l_approved_count=0 THEN
         --l_html_body :=   l_html_body || 'Your clinical privilege request  ' || l_request_hdr_id || ' is  rejected by ' || l_current_approver_name;
          l_html_body :=   l_html_body || 'Your clinical privileging application has been reviewed by '|| l_current_approver_name ||' on behalf of the Clinical Privileging Committee';
          l_html_body :=   l_html_body ||'<br/><br/>' ||'Please see details below for confirmation of privileging approval/ non-approval.';

   --  ELSE
        --  l_html_body :=   l_html_body || 'Your clinical privilege request  ' || l_request_hdr_id || ' is  approved by ' || l_current_approver_name;
    -- END IF;


      IF l_approved_count <> 0
      THEN
         --l_html_body :=
                    --   l_html_body ||'<br/>'|| 'The following privileges are approved'||'<br/>';
         l_html_body :=
               l_html_body
            || '<table cellpadding="0" cellspacing="0" border="1" width="100%"><tr>';
         l_html_body :=
               l_html_body
            || '<th  scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Request Hdr Id</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Type Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Category Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Area Of Privilege</font></b></th>';

         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Approval Comments</font></b></th></tr>';


        FOR r_approved_items IN c_approved_items (l_request_hdr_id)
         LOOP
            l_html_body := l_html_body || '<tr>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.request_hdr_id
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.type_of_privilege
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.p_category
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.p_area
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               ||  r_approved_items.approval_comments--NVL(r_approved_items.privilege_specialist_comments,NVL(r_approved_items.line_manager_comments,NVL(r_approved_items.hc_manager_comments,r_approved_items.supervisor_comments)))
               || '</font></td>';



            l_html_body := l_html_body || '</tr>';
         END LOOP;

         l_html_body := l_html_body || '</table>';
      END IF;

      l_html_body := l_html_body || '<br/>';

      IF l_rejected_count <> 0
      THEN
        /* l_html_body :=
               l_html_body
            || '<br/><br/>'
            || 'The following privileges are rejected'|| '<br/>';*/
         l_html_body :=
               l_html_body
            || '<table cellpadding="0" cellspacing="0" border="1" width="100%"><tr>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Request Hdr Id</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Type Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Category Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Area Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Rejection Reason </font></b></th></tr>';

         FOR r_rejected_items IN c_rejected_items (l_request_hdr_id)
         LOOP
            l_html_body := l_html_body || '<tr>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.request_hdr_id
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'

               || r_rejected_items.type_of_privilege
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.p_category
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.p_area
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || NVL(r_rejected_items.approval_comments,NVL(r_rejected_items.privilege_specialist_comments,
                                                       NVL(r_rejected_items.line_manager_comments,NVL(r_rejected_items.hc_manager_comments,r_rejected_items.supervisor_comments))))
               || '</font></td>';
            l_html_body := l_html_body || '</tr>';
         END LOOP;
         l_html_body := l_html_body || '</table>';
      END IF;

      l_html_body := l_html_body ||'</body></html>';
      document := l_html_body;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR(SQLERRM,1,99);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => l_item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_set_notif_body : while setting the notification content: ' ||
                                                                         l_item_key,
                                                    p_log_type        => NULL);
        document := NULL;
   END;

      PROCEDURE xx_set_renewal_notif_body (
      document_id     IN              VARCHAR2,
      display_type    IN              VARCHAR2,
      document        IN OUT NOCOPY   VARCHAR2,
      document_type   IN OUT NOCOPY   VARCHAR2
   )
   IS
      l_html_body        CLOB           := EMPTY_CLOB ();
      l_item_key         VARCHAR2 (60)  := NULL;
      l_renewal_request_id   VARCHAR2 (100);
      l_approved_count   NUMBER         := NULL;
      l_rejected_count   NUMBER         := NULL;
      l_initiator_name   VARCHAR2(100) := NULL;
      l_current_approver_name VARCHAr2(100) := NULL;
      l_exception  VARCHAR2 (100);

      CURSOR c_approved_items (pp_header_id VARCHAR2)
      IS
         SELECT DISTINCT xx.*
                         ,DECODE(xx.type_of_privilege,'Additional Privilege Request',
                            (select sequence_number from  XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
                              where request_header_id= xx.request_hdr_id and privilege_area = xx.p_area
                              and status='Active' and rownum=1),
                           (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xx.P_CATEGORY AND
                         PREVILEGE_AREA=xx.P_AREA  AND ROWNUM=1
                              )) SEQ_NUM,
                         ppf.full_name rejected_by
                    FROM XXPHCC_CLIN_PRIV_RENEW_TBL xx,
                         fnd_user fu,
                         per_all_people_f ppf
                   WHERE to_char(xx.renewal_request_id) = pp_header_id
                    AND NVL(xx.status,'Active') ='Active'

                    AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xx.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   ) order by DECODE(xx.type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4'),seq_num;

      CURSOR c_rejected_items (pp_header_id VARCHAR2)
      IS
            SELECT DISTINCT xx.*,DECODE(xx.type_of_privilege,'Additional Privilege Request',
                            (select sequence_number from  XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
                              where request_header_id= xx.request_hdr_id and privilege_area = xx.p_area
                              and status='Rejected' and rownum=1),
                           (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xx.P_CATEGORY AND
                         PREVILEGE_AREA=xx.P_AREA  AND ROWNUM=1
                              )) SEQ_NUM,
                        ppf.full_name rejected_by
                    FROM XXPHCC_CLIN_PRIV_RENEW_TBL xx,
                         fnd_user fu,
                         per_all_people_f ppf
                   WHERE to_char(xx.renewal_request_id) = pp_header_id
                    AND NVL(xx.status,'Active') ='Rejected'
                    AND fu.employee_id = ppf.person_id
                     AND fu.user_id = xx.last_updated_by
                     AND TRUNC (SYSDATE) BETWEEN TRUNC (fu.start_date)
                                             AND TRUNC (NVL (fu.end_date,
                                                             SYSDATE + 1
                                                            )
                                                       )
                     AND TRUNC (SYSDATE) BETWEEN TRUNC
                                                     (ppf.effective_start_date)
                                             AND TRUNC
                                                   (NVL
                                                       (ppf.effective_end_date,
                                                        SYSDATE + 1
                                                       )
                                                   ) order by DECODE(xx.type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4'),seq_num;
   BEGIN
      document_type := 'text/html';
      l_item_key := document_id;


      l_renewal_request_id :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'RENEWAL_REQUEST_ID'
                                   );

        l_initiator_name :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'XX_INITIATOR_NAME'
                                   );

       l_current_approver_name :=
         wf_engine.getitemattrtext (itemtype      => 'XXPERCPR',
                                    itemkey       => l_item_key,
                                    aname         => 'XX_CURRENT_APPROVER_NAME'
                                   );




      BEGIN
         SELECT COUNT (*)
           INTO l_approved_count
           FROM XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL (status, 'Active') = 'Active'
            AND TO_CHAR (renewal_request_id) = l_renewal_request_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_approved_count := 0;
      END;

      BEGIN
           SELECT COUNT (*)
           INTO l_rejected_count
           FROM XXPHCC_CLIN_PRIV_RENEW_TBL
          WHERE  NVL (status, 'Active') = 'Rejected'
            AND TO_CHAR (renewal_request_id) = l_renewal_request_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_rejected_count := 0;
      END;

      l_html_body := '<html><body>';


         l_html_body :=  l_html_body|| 'Dear '||l_initiator_name||'  '||'<br/><br/>';

     /*IF l_approved_count=0 THEN
         l_html_body :=   l_html_body || 'Your clinical privilege renewal request  ' || l_renewal_request_id || ' is  rejected by  ' || l_current_approver_name;
     ELSE
          l_html_body :=   l_html_body || 'Your clinical privilege renewal request  ' || l_renewal_request_id || ' is  approved by ' || l_current_approver_name;
     END IF;*/

       l_html_body :=   l_html_body || 'Your clinical renewal privileging application has been reviewed by '|| l_current_approver_name ||' on behalf of the Clinical Privileging Committee';
       l_html_body :=   l_html_body ||'<br/><br/>' ||'Please see details below for confirmation of privileging approval/ non-approval.';



      IF l_approved_count <> 0
      THEN
        /*l_html_body :=
                       l_html_body ||'<br/>'|| 'The following renewal privileges are approved'|| '<br/>';*/
         l_html_body :=
               l_html_body
            || '<table cellpadding="0" cellspacing="0" border="1" width="100%"><tr>';
         l_html_body :=
               l_html_body
            || '<th  scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Renewal Request Id</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Type Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Category Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Area Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Approver Comments</font></b></th></tr>';

         FOR r_approved_items IN c_approved_items (l_renewal_request_id)
         LOOP
            l_html_body := l_html_body || '<tr>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.renewal_request_id
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.type_of_privilege
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.p_category
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_approved_items.p_area
               || '</font></td>';
              l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               ||  r_approved_items.approval_comments--NULL--NVL(r_approved_items.privilege_specialist_comments,NVL(r_approved_items.hc_manager_comments,r_approved_items.supervisor_comments))
               || '</font></td>';
            l_html_body := l_html_body || '</tr>';
         END LOOP;

         l_html_body := l_html_body || '</table>';
      END IF;

      l_html_body := l_html_body || '<br/>';

      IF l_rejected_count <> 0
      THEN
         /*l_html_body :=
               l_html_body
            || '<br/><br/>'
            || 'The following renewal privileges are rejected'|| '<br/>';*/
         l_html_body :=
               l_html_body
            || '<table cellpadding="0" cellspacing="0" border="1" width="100%"><tr>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Renewal Request Id</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Type Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Category Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Area Of Privilege</font></b></th>';
         l_html_body :=
               l_html_body
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Rejection Reason</font></b></th></tr>';

         FOR r_rejected_items IN c_rejected_items (l_renewal_request_id)
         LOOP
            l_html_body := l_html_body || '<tr>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.renewal_request_id
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.type_of_privilege
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.p_category
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || r_rejected_items.p_area
               || '</font></td>';
            l_html_body :=
                  l_html_body
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || NVL(r_rejected_items.approval_comments,NVL(r_rejected_items.privilege_specialist_comments,NVL(r_rejected_items.hc_manager_comments,r_rejected_items.supervisor_comments)))
               || '</font></td>';
            l_html_body := l_html_body || '</tr>';
         END LOOP;

         l_html_body := l_html_body || '</table>';
      END IF;

      l_html_body := l_html_body ||'</body></html>';
      document := l_html_body;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR(SQLERRM,1,99);
            xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => l_item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_set_renewal_notif_body : while setting the notification content: ' ||
                                                                         l_item_key,
                                                    p_log_type        => NULL);

        document := NULL;
   END;


   PROCEDURE xx_check_action_taken (
      itemtype    IN       VARCHAR2,
      itemkey     IN       VARCHAR2,
      actid       IN       VARCHAR2,
      funcmode    IN       VARCHAR2,
      resultout   IN OUT   VARCHAR2
   )
   IS
      l_action_taken         VARCHAR2 (100);
      l_result               VARCHAR2 (100);
      l_exception            VARCHAR2 (100);
      l_notfication_result   VARCHAR2 (100);
   BEGIN
       l_notfication_result :=
                wf_notification.getattrtext (wf_engine.context_nid, 'RESULT');
         l_action_taken :=
            apps.wf_engine.getitemattrtext (itemtype      => itemtype,
                                            itemkey       => itemkey,
                                            aname         => 'ACTION_TAKEN'
                                           );


      IF (funcmode = 'RESPOND')
      THEN


         IF l_notfication_result = 'OK'
         THEN
            IF NVL (l_action_taken, 'No') <> 'Yes'
            THEN
               resultout :=
                  'ERROR:Kindly take the necessary action before clicking on the OK button ';
               RETURN;
            END IF;
         END IF;
      END IF;

       IF (funcmode IN ('FORWARD','TRANSFER'))
      THEN

            IF NVL (l_action_taken, 'No') = 'Yes'
            THEN
               resultout :=
                  'ERROR:You cannot reassign/transfer/request more information as the action is already taken ';
               RETURN;
            END IF;

      END IF;

   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR (SQLERRM, 1, 90);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => itemtype,
                                                    p_itemkey         => itemkey,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_check_action_taken : when checking the action mode: ' ||
                                                                         itemkey,
                                                    p_log_type        => NULL);
   END;



PROCEDURE xx_update_expiry_status( errbuf  OUT VARCHAR2,
                                  errcode OUT VARCHAR2)
IS
 cursor cur_privilege_details IS
  select * from (SELECT  xcph.request_hdr_id,
                         xcps.request_dtl_id,
                         xcpg.type_of_privilege,
                          xcps.p_area area,
                         xcps.status,
                         xcps.start_date ,
                         xcps.end_date,
                         (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xcpg.P_CATEGORY AND
                         PREVILEGE_AREA=xcps.P_AREA  AND ROWNUM=1) SEQ_NUM,
                         ppf.person_id,
                         ppf.employee_number
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         xxphcc_clinical_priv_area_stg xcps,
                         xxphcc_clinical_previlege_stg xcpg,
                         per_all_people_f ppf
                   WHERE xcph.request_hdr_id = xcpg.p_header_id
                     AND xcps.request_line_id = xcpg.request_line_id
                     AND NVL(xcps.select_flag,'N') = 'Y'
                     AND NVL (xcps.status, 'xx') = 'Active'
                     AND TRUNC(xcps.end_date)< TRUNC(SYSDATE)
                     AND xcph.person_id = ppf.person_id
                     AND TRUNC(SYSDATE) BETWEEN TRUNC(PPF.EFFECTIVE_START_DATE) AND TRUNC(nvl(PPF.EFFECTIVE_end_DATE,sysdate+1))
                     AND xcps.end_date IS  NOT NULL
               UNION
             select adt.request_header_id request_hdr_id,
                    NULL request_dtl_id,
                    'Additional Privilege Request' type_of_privilege,
                    adt.privilege_area area,
                    adt.status,
                    adt.start_date,
                    adt.end_date ,
                    adt.sequence_number seq_num,
                    ppf.person_id,
                    ppf.employee_number
             from XXPHCC_CLNCL_ADD_PRIV_REQ_TBL  adt, xxphcc.XXPHCC_CLINICAL_PRIVILEGE_HDR hdr,per_all_people_f ppf
             where adt.request_header_id = hdr.request_hdr_id
             and adt.status='Active' and trunc(adt.end_date )< trunc(sysdate) and adt.end_date is  not null
             and hdr.person_id= adt.person_id
             and hdr.person_id = ppf.person_id
             AND TRUNC(SYSDATE) BETWEEN TRUNC(PPF.EFFECTIVE_START_DATE) AND TRUNC(nvl(PPF.EFFECTIVE_end_DATE,sysdate+1)))
             order by employee_number,DECODE(type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4')
             ,SEQ_NUM;

    l_exception VARCHAR2(1001):= NULL;

  begin
   FOR rec_privilege_details IN cur_privilege_details
   LOOP
    BEGIN
    IF rec_privilege_details.type_of_privilege='Additional Privilege Request'
    THEN
       UPDATE XXPHCC_CLNCL_ADD_PRIV_REQ_TBL
          SET status='Expired',
              last_updated_by = fnd_profile.value('USER_ID'),
              last_update_date = SYSDATE
        WHERE request_header_id=rec_privilege_details.request_hdr_id
          AND sequence_number= rec_privilege_details.seq_num
          AND privilege_area= rec_privilege_details.area;
    ELSE
       UPDATE xxphcc.xxphcc_clinical_priv_area_stg
          SET status='Expired',
           last_updated_by = fnd_profile.value('USER_ID'),
           last_update_date = SYSDATE
        WHERE request_dtl_id= rec_privilege_details.request_dtl_id
          AND p_area= rec_privilege_details.area;
    END IF;
   EXCEPTION
     WHEN OTHERS THEN
     l_exception := SUBSTR(SQLERRM,1,1000);
     fnd_file.put_line(fnd_file.log,'Error while updating the privilege area :'|| rec_privilege_details.area || ' for employee ' ||
     rec_privilege_details.employee_number ||' Msg : '|| l_exception);
   END;

  END LOOP;
  COMMIT;
exception
  WHEN OTHERS THEN
    l_exception := SUBSTR(SQLERRM,1,1000);
     fnd_file.put_line(fnd_file.log,'Error in main : '||l_exception);
end;



PROCEDURE xx_notify_expiry_status(errbuf OUT VARCHAR2,
                                  errcode OUT VARCHAR2)
IS

CURSOR cur_emp_details
IS
  Select distinct fu.user_name,ppf.full_name,ppf.employee_number,ppf.person_id
   from per_all_people_f ppf,fnd_user fu,xxphcc.xxphcc_clinical_privilege_hdr hdr
  where ppf.person_id= hdr.person_id
   and ppf.person_id= fu.employee_id
   and trunc(sysdate) between trunc(ppf.effective_start_date) AND trunc(NVL(ppf.effective_end_date,SYSDATE+1))
   and trunc(sysdate) between trunc(fu.start_date) AND trunc(NVL(fu.end_date,SYSDATE+1))
   and exists (
            select status  from APPS.XXPHCC_CLINICAL_PRIV_AREA_STG where request_line_id in (select request_line_id from APPS.XXPHCC_CLINICAL_PREVILEGE_STG
            where p_header_id in (select request_hdr_id from APPS.XXPHCC_CLINICAL_PRIVILEGE_HDR
             where person_id= hdr.person_id)) and NVL(select_flag,'N')='Y' and status='Active'
              and trunc(end_date-60)< trunc(sysdate)
              and end_date is  not null
          UNION
             select status  from XXPHCC_CLNCL_ADD_PRIV_REQ_TBL   where request_header_id in (select request_hdr_id from APPS.XXPHCC_CLINICAL_PRIVILEGE_HDR
             where person_id= hdr.person_id) and status='Active'
             and trunc(end_date-60 )< trunc(sysdate)
             and end_date is  not null
   );

CURSOR cur_privilege_details(p_person_id  NUMBER)
IS
    select * from (SELECT DISTINCT  xcpg.type_of_privilege,
                          xcps.p_area area,
                         xcps.status,
                         xcps.start_date ,
                         xcps.end_date,
                         (select sequence_num from XXPHCC_PRIEVILEGE_ARE_TBLE
                          where CATEGORY_OF_PREVILEGE=xcpg.P_CATEGORY AND
                         PREVILEGE_AREA=xcps.P_AREA  AND ROWNUM=1) SEQ_NUM
                    FROM xxphcc_clinical_privilege_hdr xcph,
                         xxphcc_clinical_priv_area_stg xcps,
                         xxphcc_clinical_previlege_stg xcpg
                   WHERE xcph.request_hdr_id = xcpg.p_header_id
                     AND xcps.request_line_id = xcpg.request_line_id
                     AND NVL(xcps.select_flag,'N') = 'Y'
                     AND NVL (xcps.status, 'xx') = 'Active'
                     AND TRUNC(xcps.end_date-60 )< TRUNC(SYSDATE)
                     AND xcps.end_date IS  NOT NULL
                     AND TO_CHAR (xcph.person_id) = p_person_id
        UNION
             select 'Additional Privilege Request' type_of_privilege,
                    privilege_area area,
                    status,
                    start_date,
                    end_date ,
                    sequence_number
             from XXPHCC_CLNCL_ADD_PRIV_REQ_TBL   where request_header_id in (select request_hdr_id from APPS.XXPHCC_CLINICAL_PRIVILEGE_HDR
             where person_id= p_person_id) and status='Active'
             and trunc(end_date-60 )< trunc(sysdate)
             and end_date is  not null)
             order by DECODE(type_of_privilege,'CORE Activities','1','CORE Procedures','2','NON-CORE Procedures','3','4'),SEQ_NUM;

        l_user_name VARCHAR2(100);
         l_html_content VARCHAR2(32000);
        l_return NUMBER;
        lsSQLerr VARCHAR2(10000):= null;
BEGIN
    FOR rec_emp_details in cur_emp_details
    LOOP

      l_user_name := rec_emp_details.user_name;


      l_html_content := '<p> Dear '||rec_emp_details.full_name   || '</p>Kindly renew your clinical privileges</p>';
       l_html_content :=
               l_html_content
            || '<table cellpadding="0" cellspacing="0" border="1" width="70%"><tr>';


            l_html_content :=   l_html_content
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">Area Of Privilege</font></b></th>';


                 l_html_content :=
               l_html_content
            || '<th scope="col" width="5%" align="LEFT" valign="baseline" ><b><font size="2" face="Arial" ?helvetica?="" ,="">End Date</font></b></th></tr>';



    FOR rec_privilege_details IN cur_privilege_details(rec_emp_details.person_id)
    LOOP
        l_html_content := l_html_content || '<tr>';

         l_html_content :=
                  l_html_content
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || rec_privilege_details.area || '</font></td>';


            l_html_content :=
                  l_html_content
               || '<td align="LEFT" valign="baseline" width="5%"><font size="2" face="Arial" ?helvetica?="" ,="">'
               || to_char(rec_privilege_details.end_date,'DD-Mon-YYYY')
               || '</font></td>';

            l_html_content := l_html_content || '</tr>';

    END LOOP;
         l_html_content := l_html_content || '</table>';


    BEGIN
        l_return := apps.irc_notification_helper_pkg.send_notification      (p_user_name =>  l_user_name,
                                                                     p_subject   => 'Notification. Your clinical privileges are going to be expired. Kindly renew them',
                                                                     p_html_body => l_html_content,
                                                                     p_text_body => NULL,
                                                                     p_from_role => 'HRSYSADMIN');





           commit;
            apps.fnd_file.put_line(apps.fnd_file.log,
                                   'Notified the user '|| rec_emp_details.full_name );

                                    dbms_output.put_line('Notified the user '|| rec_emp_details.full_name );



     EXCEPTION
      WHEN OTHERS THEN
           lsSQLerr :=substr(SQLERRM,1,1000);
           apps.fnd_file.put_line (apps.fnd_file.log,
                                          'Error while notifying the user '|| rec_emp_details.full_name|| ' : '||
                                        lsSQLerr
                                      );


                                      dbms_output.put_line(  'Error while notifying the user '|| rec_emp_details.full_name|| ' : '||
                                        lsSQLerr);
    END;


   END LOOP;
EXCEPTION
WHEN OTHERS THEN
    lsSQLerr :=substr(SQLERRM,1,1000);
           apps.fnd_file.put_line (apps.fnd_file.log,
                                          'Error in main '||
                                        lsSQLerr
                                      );

                                       dbms_output.put_line(  'Error in main '||' : '||
                                        lsSQLerr);
END ;


                                      
    PROCEDURE XX_SET_RET_FOR_CORR_DATA_LINK (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
        )
        is 
     BEGIN
--      
--      begin
--               wf_engine.setitemattrdocument (itemtype      => item_type,
--                                 itemkey       => item_key,
--                                 aname         => 'XX_RET_FOR_CORR_DATA',
--                                 documentid        => 'PLSQL:XX_PER_CLINICAL_PRIVILEGE_PKG.XX_SET_RFC_NOTIF_BODY/'||item_key );
--        exception when others then
--            xx_debug_script_p('Clinical Privilage. Error:'||SQLERRM);
--        end;
                                        
                wf_engine.setitemattrnumber (itemtype      => item_type,
                                 itemkey       => item_key,
                                 aname         => 'LOOP_COUNTER',
                                 avalue        => 0
                                );                                
                                
            result_out:='Ok';                                
       
        EXCEPTION WHEN OTHERS THEN
        result_out:=NULL;
                          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => item_type,
                                                    p_itemkey         => item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'XX_SET_RET_FOR_CORR_DATA_LINK :' ||item_key,
                                                    p_log_type        => NULL);
     END XX_SET_RET_FOR_CORR_DATA_LINK;
     
  PROCEDURE XX_SET_RFC_NOTIF_BODY (
      document_id     IN              VARCHAR2,
      display_type    IN              VARCHAR2,
      document        IN OUT NOCOPY   VARCHAR2,
      document_type   IN OUT NOCOPY   VARCHAR2
   )
   IS
      
      l_html_body        CLOB           := EMPTY_CLOB ();
      l_item_key         VARCHAR2 (60)  := NULL;
      l_request_hdr_id   VARCHAR2 (100);
      l_count1 NUMBER:= 0;
      l_count2 NUMBER:=0;

      l_approved_count   NUMBER         := NULL;
      l_rejected_count   NUMBER         := NULL;
      l_initiator_name   VARCHAR2(100) := NULL;
      l_current_approver_name VARCHAr2(100) := NULL;
      l_exception  VARCHAR2 (100);



   BEGIN
      document_type := 'text/html';
      l_item_key := document_id;

      l_html_body := '<html><body>';


         l_html_body :=  l_html_body|| 'Dear '||l_initiator_name||document_id||'  '||'<br/><br/>';

      l_html_body := l_html_body ||'</body></html>';
      document := l_html_body;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_exception := SUBSTR(SQLERRM,1,99);
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry(p_request_id      => 1,
                                                    p_component_type  => 'Workflow',
                                                    p_package_name    => 'xx_per_clinical_privilege_pkg',
                                                    p_component_param => NULL,
                                                    p_itemtype        => 'XXPERCPR',
                                                    p_itemkey         => l_item_key,
                                                    p_error           => SQLERRM,
                                                    p_comments        => 'xx_set_notif_body : while setting the notification content: ' ||
                                                                         l_item_key,
                                                    p_log_type        => NULL);
        document := NULL;        

        
   END;
   
   procedure xx_close_notif(p_notif_id IN VARCHAR2)
 IS
   l_status VARCHAr2(100);
 BEGIN
 
  Select status into l_status
  from wf_notifications where notification_id= to_number(p_notif_id);
  
   
   fnd_log.STRING
               (log_level      => fnd_log.level_statement,
                module         => 'XX_PER_CLINICAL_PRIVILEGE_PKG',
                MESSAGE        =>    'p_notif_id'||p_notif_id
               );
               
               inv_log('p_notif_id'||p_notif_id);
  
  
  IF l_status ='OPEN'
  THEN
     
       wf_notification.setattrtext (nid    => to_number(p_notif_id), 
                                                     aname       => 'RESULT', 
                                                     avalue      => 'OK'
                               );
 
       wf_notification.respond (nid   =>  to_number(p_notif_id), 
        respond_comment =>  'Approved From program - PHCC Auto Validate Invoice And Invoice Approval', 
      responder       =>  fnd_profile.value('USERNAME')
                           );
                           
                             fnd_log.STRING
               (log_level      => fnd_log.level_statement,
                module         => 'XX_PER_CLINICAL_PRIVILEGE_PKG',
                MESSAGE        =>    'l_status'||l_status
               );
     inv_log('l_status'||l_status);
                           
  
  END IF;
 
  commit;
 EXCEPTION
    WHEN OTHERS THEN
          xx_phcc_common_utl_pkg.xx_phcc_common_log_entry
            (p_request_id           => 1,
             p_component_type       => 'Workflow',
             p_package_name         => 'xx_per_clinical_privilege_pkg',
             p_component_param      => NULL,
             p_itemtype             => 'XXPERCPR',
             p_itemkey              => NULL,
             p_error                => substr(SQLERRM,1,40),
             p_comments             =>    'xx_close_notif: while closing the FYI return for correction notification: '
                                       || p_notif_id,
             p_log_type             => NULL
            );  
  
 END;   

END xx_per_clinical_privilege_pkg;
/
