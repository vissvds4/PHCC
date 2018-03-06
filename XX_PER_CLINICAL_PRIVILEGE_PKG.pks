CREATE OR REPLACE PACKAGE APPS.XX_PER_CLINICAL_PRIVILEGE_PKG IS



FUNCTION xx_get_manager_healthCentre(p_person_id IN VARCHAR2
                                ) RETURN VARCHAR2;




FUNCTION xx_get_previous_status(p_privilege_area IN VARCHAR2,
                                p_person_id IN NUMBER )
 return VARCHAR2 ;




function xx_get_previous_status(p_privilege_area IN VARCHAR2,
                                p_person_id IN NUMBER,
                                p_request_line_id IN NUMBER,
                                p_request_dtl_id IN NUMBER
                                )
return VARCHAR2;



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
p_comments IN VARCHAR2);

  FUNCTION get_health_centre(p_person_id in VARCHAR2)
  RETURN VARCHAR2;


  PROCEDURE xx_addpriv_reject_status (
     p_renewal_request_id IN VARCHAR2,
     p_request_hdr_id IN VARCHAR2,
     p_privilege_area IN VARCHAR2,
     p_supervisor_comments IN VARCHAR2,
     p_hc_manager_comments IN VARCHAR2,
     p_line_manager_comments IN VARCHAR2,
     p_priv_spl_comments IN VARCHAR2,
     p_approval_comments in VARCHAR2
   );


    PROCEDURE xx_update_addpriv_comments (
      p_renewal_request_id IN VARCHAR2,
       p_request_hdr_id IN VARCHAR2,
     p_privilege_area IN VARCHAR2,
     p_supervisor_comments IN VARCHAR2,
     p_hc_manager_comments IN VARCHAR2,
     p_line_manager_comments IN VARCHAR2,
     p_priv_spl_comments IN VARCHAR2,
      p_approval_comments in VARCHAR2
   );







 PROCEDURE xx_get_role (
     p_person_id IN VARCHAR2,
     p_role OUT VARCHAR2
   );


   PROCEDURE xx_start_wf(p_request_header_id IN VARCHAR2,xx_process_name
               IN VARCHAR2);
    PROCEDURE xx_set_current_approver (
      itemtype   IN       VARCHAR2,
      itemkey    IN       VARCHAR2,
      actid      IN       NUMBER,
      funcmode   IN       VARCHAR2,
      RESULT     IN OUT   VARCHAR2
   );

 PROCEDURE xx_is_last_approver (
      itemtype   IN       VARCHAR2,
      itemkey    IN       VARCHAR2,
      actid      IN       NUMBER,
      funcmode   IN       VARCHAR2,
      RESULT     IN OUT   VARCHAR2
   );

PROCEDURE xx_update_rejection_status( p_request_hdr_id IN VARCHAR2,
                                         p_request_line_id IN VARCHAR2,
                                          p_request_dtl_id IN VARCHAR2,
                                        -- p_req_category IN VARCHAR2,
                                         p_req_area IN VARCHAR2,
                                       --  p_scope_of_practice IN VARCHAR2,
                                       --  p_type_of_privilege IN VARCHAR2,
                                         p_supervisor_comments IN VARCHAR2,
                                         p_hc_manager_comments IN VARCHAR2,
                                          p_line_manager_comments IN VARCHAR2,
                                         p_priv_spl_comments IN VARCHAR2,
                                         p_approval_comments IN VARCHAR2);



PROCEDURE xx_update_comments( p_request_hdr_id IN VARCHAR2,
                                         p_request_line_id IN VARCHAR2,
                                          p_request_dtl_id IN VARCHAR2,
                                       --  p_req_category IN VARCHAR2,
                                         p_req_area IN VARCHAR2,
                                      --   p_scope_of_practice IN VARCHAR2,
                                       --  p_type_of_privilege IN VARCHAR2,
                                         p_supervisor_comments IN VARCHAR2,
                                         p_hc_manager_comments IN VARCHAR2,
                                         p_line_manager_comments IN VARCHAR2,
                                         p_priv_spl_comments IN VARCHAR2,
                                         p_approval_comments IN VARCHAR2);



  PROCEDURE xx_update_renew_comments(    p_renewal_request_id IN VARCHAR2,
                                           p_request_dtl_id  IN VARCHAR2,
                                           p_request_line_id IN VARCHAR2,
                                         p_supervisor_comments IN VARCHAR2,
                                         p_hc_manager_comments IN VARCHAR2,
                                         p_line_manager_comments IN VARCHAR2,
                                         p_priv_spl_comments IN VARCHAR2,
                                          p_approval_comments in VARCHAR2);





PROCEDURE xx_are_all_privileges_rejected(item_type  IN VARCHAR2,
                                  item_key   IN VARCHAR2,
                                  actid      IN NUMBER,
                                  funcmode   IN VARCHAR2,
                                  result_out IN OUT VARCHAR2
    );


PROCEDURE get_loop_count  (item_type  IN VARCHAR2,
                                  item_key   IN VARCHAR2,
                                  actid      IN NUMBER,
                                  funcmode   IN VARCHAR2,
                                  result_out IN OUT VARCHAR2
    );













 PROCEDURE xx_update_request_dates(item_type  IN VARCHAR2,
                                  item_key   IN VARCHAR2,
                                  actid      IN NUMBER,
                                  funcmode   IN VARCHAR2,
                                  result_out IN OUT VARCHAR2
    );

PROCEDURE xx_update_action_taken(item_key   IN VARCHAR2);




PROCEDURE xx_get_loop_count(item_key   IN VARCHAR2,
                            loop_count OUT NUMBER);


PROCEDURE xx_check_action_taken(itemtype  in varchar2,
                                 itemkey   in varchar2,
                                 actid     in varchar2,
                                 funcmode  in varchar2,
                                 resultout in out varchar2
);


PROCEDURE XX_SET_NOTIF_BODY(
    document_id   IN VARCHAR2,
    display_type  IN VARCHAR2,
    document      IN OUT nocopy VARCHAR2,
    document_type IN OUT nocopy VARCHAR2);

PROCEDURE xx_is_renewal_process (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   );


    PROCEDURE xx_are_all_renew_priv_rejected (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   );



    PROCEDURE xx_update_renew_request_dates (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   );



     PROCEDURE xx_update_renew_reject_status (
      p_renewal_request_id IN VARCHAR2,
      p_request_dtl_id  IN VARCHAR2,
      p_request_line_id IN VARCHAR2,
      p_supervisor_comments IN VARCHAR2,
      p_hc_manager_comments IN VARCHAR2,
       p_line_manager_comments IN VARCHAR2 ,
      p_priv_spl_commets IN VARCHAR2 ,
       p_approval_comments in VARCHAR2

   );

 PROCEDURE xx_set_renewal_notif_body (
      document_id     IN              VARCHAR2,
      display_type    IN              VARCHAR2,
      document        IN OUT NOCOPY   VARCHAR2,
      document_type   IN OUT NOCOPY   VARCHAR2
   );

 PROCEDURE xx_check_existence (
     p_request_hdr_id IN VARCHAr2,
     p_person_id IN VARCHAR2,
     p_category_of_privilege IN VARCHAR2,
     p_area_of_privilege IN VARCHAr2,
     p_result OUT VARCHAR2
   );


 PROCEDURE xx_check_save_existence (
     p_request_hdr_id IN VARCHAr2,
     p_person_id IN VARCHAR2,
     p_result OUT VARCHAR2
   );


  PROCEDURE xx_check_clinical_priv_dor (
     p_person_id IN VARCHAR2,
     p_result OUT VARCHAR2
   );

   PROCEDURE xx_check_license_number (
     p_person_id IN VARCHAR2,
     p_result OUT VARCHAR2
   );

   PROCEDURE xx_update_expiry_status( errbuf  OUT VARCHAR2,
                                      errcode OUT VARCHAR2) ;


    PROCEDURE xx_notify_expiry_status( errbuf  OUT VARCHAR2,
                                      errcode OUT VARCHAR2) ;
                                      
                                          
   procedure xx_close_notif(p_notif_id IN VARCHAr2);                                      
                                      
    PROCEDURE XX_SET_RET_FOR_CORR_DATA_LINK (
      item_type    IN       VARCHAR2,
      item_key     IN       VARCHAR2,
      actid        IN       NUMBER,
      funcmode     IN       VARCHAR2,
      result_out   IN OUT   VARCHAR2
   );
   
  PROCEDURE XX_SET_RFC_NOTIF_BODY (
      document_id     IN              VARCHAR2,
      display_type    IN              VARCHAR2,
      document        IN OUT NOCOPY   VARCHAR2,
      document_type   IN OUT NOCOPY   VARCHAR2
   );

END XX_PER_CLINICAL_PRIVILEGE_PKG;
/
