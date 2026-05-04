CLASS lhc_AssetFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR AssetFile RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE AssetFile.

    METHODS create_asset FOR MODIFY
      IMPORTING keys FOR ACTION AssetFile~create_asset RESULT result.

    METHODS uploadExcelData FOR MODIFY
      IMPORTING keys FOR ACTION AssetFile~uploadExcelData RESULT result.

    METHODS FillFileStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR AssetFile~FillFileStatus.

    METHODS FillSelectedStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR AssetFile~FillSelectedStatus.
*METHODS downloadTemplate FOR MODIFY
*  IMPORTING keys FOR ACTION AssetFile~downloadTemplate RESULT result.
ENDCLASS.

CLASS lhc_AssetFile IMPLEMENTATION.
*METHOD downloadTemplate.
*
*  DATA: lt_template TYPE STANDARD TABLE OF zbp_i_asset_file=>ty_asset_itm,
*        lv_file_content TYPE xstring.
*
*  " Create Excel write access
*  DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).
*
*  " Get worksheet (YOUR SYSTEM COMPATIBLE)
*  DATA(lo_worksheet) = lo_write_access->get_workbook(
*        )->worksheet->at_position( 1 ).
*
*  " Full selection pattern
*  DATA(lo_pattern) =
*    xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
*
*  " Header row (IMPORTANT — match upload logic)
*lt_template = VALUE #( (
*  company_code  = 'Company Code'
*  asset_class   = 'Asset Class'
*  asset_desc    = 'Asset Description'
*  asset_desc2   = 'Asset Description 2'
*  base_uom      = 'Base UOM'
*  cost_center   = 'Cost Center'
*  profit_center = 'Profit Center'
*  plant         = 'Plant'
*  ledger        = 'Ledger'
*  real_dep_area = 'Dep Area'
*  scrap_val_pct = 'Scrap %'
*) ).
*
*  " Write to Excel
*  lo_worksheet->select( lo_pattern
*    )->row_stream(
*    )->operation->write_from( REF #( lt_template )
*    )->execute( ).
*
*  " Get file
*  lv_file_content = lo_write_access->get_file_content( ).
*
*  " Return to UI
*  result = VALUE #(
*    (
*      %tky = keys[ 1 ]-%tky
*      %param = VALUE #(
*        attachment = lv_file_content
*        filename   = 'Asset_Template.xlsx'
*        mimetype   = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
*      )
*    )
*  ).
*
*ENDMETHOD.
  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).


    LOOP AT entities ASSIGNING FIELD-SYMBOL(<lfs_entities>).

      APPEND CORRESPONDING #( <lfs_entities> ) TO mapped-assetfile
        ASSIGNING FIELD-SYMBOL(<lfs_xlhead>).

      <lfs_xlhead>-EndUser = lv_user.

      IF <lfs_xlhead>-FileId IS INITIAL.
        TRY.
            <lfs_xlhead>-FileId = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.
            " Do nothing – proceed to next entry
        ENDTRY.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD create_asset .
    DATA lt_update_items TYPE TABLE FOR UPDATE zi_asset_file\\AssetItem.
    DATA: it_item TYPE TABLE OF zi_asset_itm,
          wa_item TYPE zi_asset_itm.

    TYPES: BEGIN OF ty_api_log,
             asset_no     TYPE string,
             asset_subno  TYPE string,
             status_code  TYPE i,
             message_text TYPE string,
             line_id      TYPE string,
           END OF ty_api_log.
    TYPES tt_api_log TYPE TABLE OF ty_api_log WITH EMPTY KEY.

    DATA : it_log TYPE tt_api_log .


    " ─── 1. Read Header ──────────────────────────────────────────────────────
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF lt_file_entity IS INITIAL.
  RETURN.
ENDIF.

*    " ─── 2. Build Proper Keys from Header ───────────────────────────────────
*    DATA lt_assetfile_keys TYPE TABLE FOR READ IMPORT zi_asset_file\\AssetItem.
*    lt_assetfile_keys = VALUE #( FOR ls_hdr IN lt_file_entity
*                                   ( EndUser = ls_hdr-EndUser
*                                     FileId  = ls_hdr-FileId ) ).
*
*    " ─── 3. Read Line Items via Association ─────────────────────────────────
*    READ ENTITIES OF zi_asset_file IN LOCAL MODE
*      ENTITY AssetFile
*      BY \_AssetData
*      ALL FIELDS WITH CORRESPONDING #( lt_assetfile_keys )
*      RESULT DATA(lt_item_entity)
*      FAILED DATA(ls_item_failed)
*      REPORTED DATA(ls_item_reported).
*
**  CHECK lt_item_entity IS NOT INITIAL.
*IF lt_item_entity IS INITIAL.
*  APPEND VALUE #(
*    %tky = lt_file_entity[ 1 ]-%tky
*    %msg = new_message_with_text(
*             severity = if_abap_behv_message=>severity-error
*             text     = 'No asset data found. Please upload a file before creating assets.'
*           )
*  ) TO reported-assetfile.
*
*  result = VALUE #(
*    (
*      %tky      = lt_file_entity[ 1 ]-%tky
*      %is_draft = lt_file_entity[ 1 ]-%is_draft
*      %param    = lt_file_entity[ 1 ]
*    )
*  ).
*
*  RETURN.
*ENDIF.
" ─── 2. Build Proper Keys from Header ───────────────────────────────────
DATA lt_assetfile_keys TYPE TABLE FOR READ IMPORT zi_asset_file\\AssetItem.
lt_assetfile_keys = VALUE #( FOR ls_hdr IN lt_file_entity
                               ( EndUser = ls_hdr-EndUser
                                 FileId  = ls_hdr-FileId ) ).

" ─── 3. Read Line Items via Association ─────────────────────────────────
READ ENTITIES OF zi_asset_file IN LOCAL MODE
  ENTITY AssetFile
  BY \_AssetData
  ALL FIELDS WITH CORRESPONDING #( lt_assetfile_keys )
  RESULT DATA(lt_item_entity)
  FAILED DATA(ls_item_failed)
  REPORTED DATA(ls_item_reported).

" ─── 3b. Filter out items where Assetno already exists ──────────────────
" Assets already created should not be recreated.
DELETE lt_item_entity WHERE Assetno IS NOT INITIAL.

    " ─── 4. Move to Internal Table for Parallel Class ───────────────────────
    LOOP AT lt_item_entity ASSIGNING FIELD-SYMBOL(<fs_item>).
      MOVE-CORRESPONDING <fs_item> TO wa_item.
      APPEND wa_item TO it_item.
      CLEAR wa_item.
    ENDLOOP.

    " ─── 5. Setup & Run Parallel ─────────────────────────────────────────────
    DATA(lo_proc1) = NEW cl_abap_parallel( p_percentage = 30 ).
    DATA lt_poparallel1 TYPE cl_abap_parallel=>t_in_inst_tab.

    INSERT NEW zcl_asset_parallel( it_asset = CORRESPONDING #( it_item ) )
      INTO TABLE lt_poparallel1.

    IF lt_poparallel1 IS NOT INITIAL.
      lo_proc1->run_inst(
        EXPORTING
          p_in_tab  = lt_poparallel1
          p_debug   = abap_false
        IMPORTING
          p_out_tab = DATA(lt_finished)
      ).
    ENDIF.

    " ─── 6. Aggregate Results from ALL Parallel Instances ────────────────────
    DATA lt_item_ret TYPE TABLE OF zi_asset_itm.

    LOOP AT lt_finished INTO DATA(ls_finished).
      DATA(lo_result) = CAST zcl_asset_parallel( ls_finished-inst ).

      lo_result->get_hdr_data(
        IMPORTING
          et_item = DATA(lt_item_chunk)
      ).

      APPEND LINES OF lt_item_chunk TO lt_item_ret.

      lo_result->get_log(
      IMPORTING
        et_log1 = DATA(lt_log1)
    ).

*      APPEND LINES OF lt_log1 TO it_log.
    ENDLOOP.

    IF lt_log1[] IS NOT INITIAL.
      DELETE lt_log1 WHERE asset_no IS NOT INITIAL.

      LOOP AT lt_log1 INTO DATA(ls_log) WHERE asset_no IS INITIAL.
        APPEND VALUE #(
          %tky = lt_file_entity[ 1 ]-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = ls_log-message_text
                 )
        ) TO reported-assetfile.
      ENDLOOP.
    ENDIF.

*  IF lt_item_ret IS INITIAL.
*  APPEND VALUE #(
*    %tky = lt_file_entity[ 1 ]-%tky
*    %msg = new_message_with_text(
*             severity = if_abap_behv_message=>severity-error
*             text     = 'Asset creation failed for all records. Please check the data and try again.'
*           )
*  ) TO reported-assetfile.
*
*  result = VALUE #(
*    (
*      %tky      = lt_file_entity[ 1 ]-%tky
*      %is_draft = lt_file_entity[ 1 ]-%is_draft
*      %param    = lt_file_entity[ 1 ]
*    )
*  ).
*
*  RETURN.
*ENDIF.
" ─── 6c. If all parallel calls failed, return with log errors only ────────
IF lt_item_ret IS INITIAL.
  result = VALUE #(
    (
      %tky      = lt_file_entity[ 1 ]-%tky
      %is_draft = lt_file_entity[ 1 ]-%is_draft
      %param    = lt_file_entity[ 1 ]
    )
  ).
  RETURN.
ENDIF.

    " ─── 7. Build Update Table ───────────────────────────────────────────────
DATA flg TYPE abap_bool.

LOOP AT lt_item_ret INTO DATA(ls_item_ret) WHERE Assetno IS NOT INITIAL.

  READ TABLE lt_item_entity INTO DATA(ls_entity)
    WITH KEY EndUser = ls_item_ret-EndUser
             FileId  = ls_item_ret-FileId
             LineId  = ls_item_ret-LineId
             LineNo1 = ls_item_ret-LineNo1.

  IF sy-subrc = 0.
    flg = abap_true.  " ← SET flag here, no CHECK inside loop

    APPEND VALUE #(
      %tky     = ls_entity-%tky
      Assetno  = ls_item_ret-Assetno
      %control = VALUE #(
        Assetno = if_abap_behv=>mk-on
      )
    ) TO lt_update_items.
  ENDIF.

ENDLOOP.

IF flg = abap_false.
  APPEND VALUE #(
    %tky = lt_file_entity[ 1 ]-%tky
    %msg = new_message_with_text(
             severity = if_abap_behv_message=>severity-error
             text     = 'Asset creation failed for all records. Please check the data and try again.'
           )
  ) TO reported-assetfile.

  result = VALUE #(
    (
      %tky      = lt_file_entity[ 1 ]-%tky
      %is_draft = lt_file_entity[ 1 ]-%is_draft
      %param    = lt_file_entity[ 1 ]
    )
  ).

  RETURN.
ENDIF.

    " ─── 8. MODIFY AssetNo into Line Items ───────────────────────────────────
    IF lt_update_items IS NOT INITIAL.
      MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
        ENTITY AssetItem
        UPDATE FIELDS ( Assetno )
        WITH lt_update_items
        FAILED   DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      reported-assetitem = CORRESPONDING #( lt_mod_reported-assetitem ).

      IF lt_mod_failed IS NOT INITIAL.
        failed-assetitem   = CORRESPONDING #( lt_mod_failed-assetitem ).
        reported-assetitem = CORRESPONDING #( lt_mod_reported-assetitem ).
        RETURN.
      ENDIF.
    ENDIF.


    " ─── 9. Success Message ─────────────────────────────────────────────────
    DATA(lv_count)   = lines( lt_update_items ).
    DATA(lv_success) = |{ lv_count } Asset(s) created successfully|.
*    IF lt_log1[] IS INITIAL .
      APPEND VALUE #(
        %tky = lt_file_entity[ 1 ]-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = lv_success
               )
      ) TO reported-assetfile.
*    ELSE.
*      APPEND VALUE #(
*       %tky = lt_file_entity[ 1 ]-%tky
*       %msg = new_message_with_text(
*                severity = if_abap_behv_message=>severity-error
*                text     = lv_success
*              )
*     ) TO reported-assetfile.
*    ENDIF.
    " ─── 10. Read Updated Root Again (same pattern as uploadExcelData) ──────
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_assetfile)
      FAILED DATA(lt_hdr_failed)
      REPORTED DATA(lt_hdr_reported).

    " ─── 11. Read Updated Child Items Again ─────────────────────────────────
    DATA lt_result_keys TYPE TABLE FOR READ IMPORT zi_asset_file\_AssetData.
    lt_result_keys = VALUE #( FOR ls_h IN lt_updated_assetfile
                                ( EndUser = ls_h-EndUser
                                  FileId  = ls_h-FileId ) ).

    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      BY \_AssetData
      ALL FIELDS WITH CORRESPONDING #( lt_result_keys )
      RESULT DATA(lt_updated_items)
      FAILED DATA(lt_item_read_failed)
      REPORTED DATA(lt_item_read_reported).

    " ─── 12. Return Root Exactly Like Working Action ─────────────────────────
    result = VALUE #(
      FOR lwa_upd_head IN lt_updated_assetfile
      (
        %tky      = lwa_upd_head-%tky
        %is_draft = lwa_upd_head-%is_draft
        %param    = lwa_upd_head
      )
    ).

    CLEAR: lt_finished, lt_poparallel1, it_log, lt_log1.
  ENDMETHOD.



*METHOD create_asset.
*  DATA lt_update_items TYPE TABLE FOR UPDATE zi_asset_file\\AssetItem.
*  DATA: it_item TYPE TABLE OF zi_asset_itm,
*        wa_item TYPE zi_asset_itm.
*
*  TYPES: BEGIN OF ty_api_log,
*           asset_no     TYPE string,
*           asset_subno  TYPE string,
*           status_code  TYPE i,
*           message_text TYPE string,
*           line_id      TYPE string,
*         END OF ty_api_log.
*  TYPES tt_api_log TYPE TABLE OF ty_api_log WITH EMPTY KEY.
*
*  DATA: it_log  TYPE tt_api_log,
*        lt_log1 TYPE tt_api_log.
*
*  " ─── 1. Read Header ──────────────────────────────────────────────────────
*  READ ENTITIES OF zi_asset_file IN LOCAL MODE
*    ENTITY AssetFile
*    ALL FIELDS WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_file_entity)
*    FAILED DATA(ls_failed)
*    REPORTED DATA(ls_reported).
*
*  CHECK lt_file_entity IS NOT INITIAL.
*
*  " ─── 2. Build Proper Keys from Header ───────────────────────────────────
*  DATA lt_assetfile_keys TYPE TABLE FOR READ IMPORT zi_asset_file\\AssetItem.
*  lt_assetfile_keys = VALUE #( FOR ls_hdr IN lt_file_entity
*                                 ( EndUser = ls_hdr-EndUser
*                                   FileId  = ls_hdr-FileId ) ).
*
*  " ─── 3. Read Line Items via Association ─────────────────────────────────
*  READ ENTITIES OF zi_asset_file IN LOCAL MODE
*    ENTITY AssetFile
*    BY \_AssetData
*    ALL FIELDS WITH CORRESPONDING #( lt_assetfile_keys )
*    RESULT DATA(lt_item_entity)
*    FAILED DATA(ls_item_failed)
*    REPORTED DATA(ls_item_reported).
*
*  CHECK lt_item_entity IS NOT INITIAL.
*
*  " ─── 4. Move to Internal Table for Parallel Class ───────────────────────
*  LOOP AT lt_item_entity ASSIGNING FIELD-SYMBOL(<fs_item>).
*    MOVE-CORRESPONDING <fs_item> TO wa_item.
*    APPEND wa_item TO it_item.
*    CLEAR wa_item.
*  ENDLOOP.
*
*  " ─── 5. Setup & Run Parallel ─────────────────────────────────────────────
*  DATA(lo_proc1) = NEW cl_abap_parallel( p_percentage = 30 ).
*  DATA lt_poparallel1 TYPE cl_abap_parallel=>t_in_inst_tab.
*
*  INSERT NEW zcl_asset_parallel( it_asset = CORRESPONDING #( it_item ) )
*    INTO TABLE lt_poparallel1.
*
*  IF lt_poparallel1 IS NOT INITIAL.
*    lo_proc1->run_inst(
*      EXPORTING
*        p_in_tab  = lt_poparallel1
*        p_debug   = abap_false
*      IMPORTING
*        p_out_tab = DATA(lt_finished)
*    ).
*  ENDIF.
*
*  " ─── 6. Aggregate Results from ALL Parallel Instances ────────────────────
*  DATA lt_item_ret TYPE TABLE OF zi_asset_itm.
*
*  LOOP AT lt_finished INTO DATA(ls_finished).
*    DATA(lo_result) = CAST zcl_asset_parallel( ls_finished-inst ).
*
*    lo_result->get_hdr_data(
*      IMPORTING
*        et_item = DATA(lt_item_chunk)
*    ).
*    APPEND LINES OF lt_item_chunk TO lt_item_ret.
*
*    lo_result->get_log(
*      IMPORTING
*        et_log1 = lt_log1
*    ).
*  ENDLOOP.
*
*  " ─── 6b. Error Reporting from Log ────────────────────────────────────────
*  IF lt_log1[] IS NOT INITIAL.
*    DELETE lt_log1 WHERE asset_no IS NOT INITIAL.
*
*    LOOP AT lt_log1 INTO DATA(ls_log) WHERE asset_no IS INITIAL.
*      APPEND VALUE #(
*        %tky = lt_file_entity[ 1 ]-%tky
*        %msg = new_message_with_text(
*                 severity = if_abap_behv_message=>severity-error
*                 text     = ls_log-message_text
*               )
*      ) TO reported-assetfile.
*    ENDLOOP.
*  ENDIF.
*
*  CHECK lt_item_ret IS NOT INITIAL.
*
*  " ─── 7. Build Update Table ───────────────────────────────────────────────
*  DATA flg TYPE abap_bool.
*
*  LOOP AT lt_item_ret INTO DATA(ls_item_ret) WHERE Assetno IS NOT INITIAL.
*
*    READ TABLE lt_item_entity INTO DATA(ls_entity)
*      WITH KEY EndUser = ls_item_ret-EndUser
*               FileId  = ls_item_ret-FileId
*               LineId  = ls_item_ret-LineId
*               LineNo1 = ls_item_ret-LineNo1.
*
*    IF sy-subrc = 0.
*      flg = abap_true.
*
*      APPEND VALUE #(
*        %tky     = ls_entity-%tky
*        Assetno  = ls_item_ret-Assetno
*        %control = VALUE #(
*          Assetno = if_abap_behv=>mk-on
*        )
*      ) TO lt_update_items.
*    ENDIF.
*
*  ENDLOOP.
*
*  CHECK flg = abap_true.
*
*  " ─── 8. MODIFY AssetNo into Line Items ───────────────────────────────────
*  IF lt_update_items IS NOT INITIAL.
*    MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
*      ENTITY AssetItem
*      UPDATE FIELDS ( Assetno )
*      WITH lt_update_items
*      FAILED   DATA(lt_mod_failed)
*      REPORTED DATA(lt_mod_reported).
*
*    reported-assetitem = CORRESPONDING #( lt_mod_reported-assetitem ).
*
*    IF lt_mod_failed IS NOT INITIAL.
*      failed-assetitem   = CORRESPONDING #( lt_mod_failed-assetitem ).
*      reported-assetitem = CORRESPONDING #( lt_mod_reported-assetitem ).
*      RETURN.
*    ENDIF.
*  ENDIF.
*
*  " ─── 8b. Touch Header to Mark Root Draft Dirty ───────────────────────────
*  " This mirrors what uploadExcelData does (FileStatus update on root).
*  " Without touching the root entity, the draft buffer stays clean and
*  " the UI side effects do not fire — causing the stale UI issue.
*
*
*  " ─── 9. Success / Error Message ─────────────────────────────────────────
*  DATA(lv_count)   = lines( lt_update_items ).
*  DATA(lv_success) = |{ lv_count } Asset(s) created successfully|.
*
*  IF lt_log1[] IS INITIAL.
*    APPEND VALUE #(
*      %tky = lt_file_entity[ 1 ]-%tky
*      %msg = new_message_with_text(
*               severity = if_abap_behv_message=>severity-success
*               text     = lv_success
*             )
*    ) TO reported-assetfile.
*  ELSE.
*    APPEND VALUE #(
*      %tky = lt_file_entity[ 1 ]-%tky
*      %msg = new_message_with_text(
*               severity = if_abap_behv_message=>severity-error
*               text     = lv_success
*             )
*    ) TO reported-assetfile.
*  ENDIF.
* MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
*    ENTITY AssetFile
*    UPDATE FIELDS ( FileStatus )
*    WITH VALUE #(
*      FOR ls_hdr IN lt_file_entity
*      (
*        %tky       = ls_hdr-%tky
*        FileStatus = 'Assets Created'
*        %control   = VALUE #(
*          FileStatus = if_abap_behv=>mk-on
*        )
*      )
*    )
*    FAILED   DATA(lt_etag_failed)
*    REPORTED DATA(lt_etag_reported).
*  " ─── 10. Read Updated Root ───────────────────────────────────────────────
*  READ ENTITIES OF zi_asset_file IN LOCAL MODE
*    ENTITY AssetFile
*    ALL FIELDS WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_updated_assetfile)
*    FAILED DATA(lt_hdr_failed)
*    REPORTED DATA(lt_hdr_reported).
*
*  " ─── 11. Read Updated Child Items ────────────────────────────────────────
*  DATA lt_result_keys TYPE TABLE FOR READ IMPORT zi_asset_file\_AssetData.
*  lt_result_keys = VALUE #( FOR ls_h IN lt_updated_assetfile
*                              ( EndUser = ls_h-EndUser
*                                FileId  = ls_h-FileId ) ).
*
*  READ ENTITIES OF zi_asset_file IN LOCAL MODE
*    ENTITY AssetFile
*    BY \_AssetData
*    ALL FIELDS WITH CORRESPONDING #( lt_result_keys )
*    RESULT DATA(lt_updated_items)
*    FAILED DATA(lt_item_read_failed)
*    REPORTED DATA(lt_item_read_reported).
*
*  " ─── 12. Return Result to UI ─────────────────────────────────────────────
*  result = VALUE #(
*    FOR lwa_upd_head IN lt_updated_assetfile
*    (
*      %tky      = lwa_upd_head-%tky
*      %is_draft = lwa_upd_head-%is_draft
*      %param    = lwa_upd_head
*    )
*  ).
*
*  CLEAR: lt_finished, lt_poparallel1, it_log, lt_log1.
*
*ENDMETHOD.

  METHOD uploadExcelData.

    DATA:
      lt_rows         TYPE STANDARD TABLE OF string,
      lv_content      TYPE string,
      lo_table_descr  TYPE REF TO cl_abap_tabledescr,
      lo_struct_descr TYPE REF TO cl_abap_structdescr,
      lt_excel        TYPE STANDARD TABLE OF zi_asset_itm,
      wa_excel        TYPE zi_asset_itm,
      lt_assetitm     TYPE STANDARD TABLE OF zi_asset_itm,
      wa_assetitm     TYPE zi_asset_itm,
      lt_excel1       TYPE STANDARD TABLE OF zbp_i_asset_file=>ty_asset_itm,
      lt_data         TYPE TABLE FOR CREATE zi_asset_file\_AssetData,
      lv_index        TYPE sy-index.



    DATA(n2) = 0.

    FIELD-SYMBOLS:
      <lfs_col_header> TYPE string.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity).

 DATA(lv_attachment) = lt_file_entity[ 1 ]-attachment.

IF lv_attachment IS INITIAL.
  APPEND VALUE #(
    %tky = lt_file_entity[ 1 ]-%tky
    %msg = new_message_with_text(
             severity = if_abap_behv_message=>severity-error
             text     = 'Please attach a file before uploading.'
           )
  ) TO reported-assetfile.

  result = VALUE #(
    (
      %tky      = lt_file_entity[ 1 ]-%tky
      %is_draft = lt_file_entity[ 1 ]-%is_draft
      %param    = lt_file_entity[ 1 ]
    )
  ).

  RETURN.
ENDIF.

    " Move Excel Data to Internal Table
    DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                      iv_file_content = lv_attachment
                    )->read_access( ).

    DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_selection_pattern) =
      xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    DATA(lo_execute) = lo_worksheet->select(
                         lo_selection_pattern
                       )->row_stream( )->operation->write_to(
*                         REF #( lt_excel )
                          REF #( lt_excel1 )
                       ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Get number of columns in upload file for validation
    TRY.
        lo_table_descr ?= cl_abap_tabledescr=>describe_by_data(
*                            p_data = lt_excel
                             p_data = lt_excel1
                          ).

        lo_struct_descr ?= lo_table_descr->get_table_line_type( ).

        DATA(lv_no_of_cols) = lines( lo_struct_descr->components ).

      CATCH cx_sy_move_cast_error.
        " Implement error handling
    ENDTRY.

    DELETE lt_excel1 INDEX 1 .

*    CLEAR : wa_pomiro .

    DELETE lt_excel1 WHERE company_code IS INITIAL .

    DATA(lt_excel2) = lt_excel1[].

*    SORT lt_excel2 BY  .

*    DELETE lt_excel2 WHERE ap_invoice IS INITIAL .

*    DELETE ADJACENT DUPLICATES FROM lt_excel2 COMPARING ap_invoice .


    LOOP AT lt_excel1 ASSIGNING FIELD-SYMBOL(<fs_asset>).

      n2 += 1.

      wa_excel-CompanyCode  = <fs_asset>-company_code.
      wa_excel-AssetClass   = <fs_asset>-asset_class.
      wa_excel-AssetDesc    = <fs_asset>-asset_desc.
      wa_excel-AssetDesc2   = <fs_asset>-asset_desc2.
      wa_excel-BaseUom     = <fs_asset>-base_uom.
      wa_excel-CostCenter   = <fs_asset>-cost_center.
      wa_excel-ProfitCenter = <fs_asset>-profit_center.
      wa_excel-Plant         = <fs_asset>-plant.
      wa_excel-ledger        = <fs_asset>-ledger.
      wa_excel-RealDepArea = <fs_asset>-real_dep_area.
      wa_excel-ScrapValPct = <fs_asset>-scrap_val_pct.

      APPEND wa_excel TO lt_excel.
      CLEAR wa_excel.

    ENDLOOP.

    " Fill Line ID / Line Number
    TRY.
        DATA(lv_line_id) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    LOOP AT lt_excel ASSIGNING FIELD-SYMBOL(<lfs_excel>).
      <lfs_excel>-LineId = lv_line_id.
      <lfs_excel>-LineNo1 = sy-tabix.
    ENDLOOP.

    " Prepare Data for Child Entity (AssetData)
    lt_data = VALUE #(
      (
        %cid_ref  = keys[ 1 ]-%cid_ref
        %is_draft = keys[ 1 ]-%is_draft
        EndUser   = keys[ 1 ]-EndUser
        FileId    = keys[ 1 ]-FileId
        %target   = VALUE #(
          FOR lwa_excel IN lt_excel
          (
            %cid      = keys[ 1 ]-%cid_ref
            %is_draft = keys[ 1 ]-%is_draft
            %data     = VALUE #(
              EndUser       = keys[ 1 ]-EndUser
              FileId        = keys[ 1 ]-FileId
              LineId        = lwa_excel-LineId
              LineNo1       = lwa_excel-LineNo1
              CompanyCode   = lwa_excel-CompanyCode
              AssetClass    = lwa_excel-AssetClass
              AssetDesc     = lwa_excel-AssetDesc
              AssetDesc2    = lwa_excel-AssetDesc2
              BaseUom       = lwa_excel-BaseUom
              CostCenter    = lwa_excel-CostCenter
              ProfitCenter  = lwa_excel-ProfitCenter
              Plant         = lwa_excel-plant
              Ledger        = lwa_excel-ledger
              RealDepArea   = lwa_excel-RealDepArea
              ScrapValPct   = lwa_excel-ScrapValPct
            )
            %control  = VALUE #(
              EndUser       = if_abap_behv=>mk-on
              FileId        = if_abap_behv=>mk-on
              LineId        = if_abap_behv=>mk-on
              LineNo1       = if_abap_behv=>mk-on
              CompanyCode   = if_abap_behv=>mk-on
              AssetClass    = if_abap_behv=>mk-on
              AssetDesc     = if_abap_behv=>mk-on
              AssetDesc2    = if_abap_behv=>mk-on
              BaseUom       = if_abap_behv=>mk-on
              CostCenter    = if_abap_behv=>mk-on
              ProfitCenter  = if_abap_behv=>mk-on
              Plant         = if_abap_behv=>mk-on
              Ledger        = if_abap_behv=>mk-on
              RealDepArea   = if_abap_behv=>mk-on
              ScrapValPct   = if_abap_behv=>mk-on
            )
          )
        )
      )
    ).

    " Delete Existing entries for user if any
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile BY \_AssetData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_assetdata).

    IF lt_existing_assetdata IS NOT INITIAL.

      MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
        ENTITY AssetItem
        DELETE FROM VALUE #(
          FOR lwa_data IN lt_existing_assetdata
          (
            %key      = lwa_data-%key
            %is_draft = lwa_data-%is_draft
          )
        )
        MAPPED   DATA(lt_del_mapped)
        REPORTED DATA(lt_del_reported)
        FAILED   DATA(lt_del_failed).

    ENDIF.

    " Add New Entries for AssetData (association)
    MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile CREATE BY \_AssetData
      AUTO FILL CID WITH lt_data.

    " Update File Status
    MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      UPDATE FROM VALUE #(
        (
          %tky                = lt_file_entity[ 1 ]-%tky
          FileStatus          = 'File Uploaded'
          %control-FileStatus = if_abap_behv=>mk-on
        )
      )
      MAPPED   DATA(lt_upd_mapped)
      FAILED   DATA(lt_upd_failed)
      REPORTED DATA(lt_upd_reported).

    " Read Updated Entry
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_assetfile).

    " Send Status back to front end
    result = VALUE #(
      FOR lwa_upd_head IN lt_updated_assetfile
      (
        %tky      = lwa_upd_head-%tky
        %is_draft = lwa_upd_head-%is_draft
        %param    = lwa_upd_head
      )
    ).


  ENDMETHOD.

  METHOD FillFileStatus.
    " Read the data to be modified
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      FIELDS ( EndUser FileStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    " Update File Status
    LOOP AT lt_user INTO DATA(ls_user).

      MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
        ENTITY AssetFile
        UPDATE FIELDS ( FileStatus )
        WITH VALUE #(
          (
            %tky                   = ls_user-%tky
            %data-FileStatus       = 'File Not Selected'
            %control-FileStatus    = if_abap_behv=>mk-on
          )
        ).

    ENDLOOP.
  ENDMETHOD.

  METHOD FillSelectedStatus.
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile BY \_AssetData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_xldata).

    IF lt_existing_xldata IS NOT INITIAL.

      MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
        ENTITY AssetItem
        DELETE FROM VALUE #(
          FOR lwa_data IN lt_existing_xldata
          (
            %key        = lwa_data-%key
            %is_draft   = lwa_data-%is_draft
          )
        ).

    ENDIF.

    " Read XLHead entities and change file status
    READ ENTITIES OF zi_asset_file IN LOCAL MODE
      ENTITY AssetFile
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_xlhead).

    " Update File Status
    LOOP AT lt_xlhead INTO DATA(ls_xlhead).

      MODIFY ENTITIES OF zi_asset_file IN LOCAL MODE
        ENTITY AssetFile
        UPDATE FIELDS ( FileStatus )
        WITH VALUE #(
          (
            %tky = ls_xlhead-%tky
            %data-FileStatus = COND #(
              WHEN ls_xlhead-Attachment IS INITIAL
                THEN 'File Not Selected'
              ELSE
                'File Selected'
            )
            %control-FileStatus = if_abap_behv=>mk-on
          )
        ).

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_AssetItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR AssetItem RESULT result.

    METHODS processData FOR MODIFY
      IMPORTING keys FOR ACTION AssetItem~processData RESULT result.

ENDCLASS.

CLASS lhc_AssetItem IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD processData.
  ENDMETHOD.

ENDCLASS.
