CLASS zcl_asset_parallel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA: lv_plain   TYPE string,
          lv_encoded TYPE string,
          lv_auth    TYPE string.

    TYPES: BEGIN OF ty_api_log,
             asset_class  TYPE string,
             asset_desc   TYPE string,
             status_code  TYPE i,
             message_text TYPE string,
             asset_no     TYPE string,
           END OF ty_api_log.
    TYPES tt_api_log TYPE TABLE OF ty_api_log WITH EMPTY KEY.

    TYPES: tt_result   TYPE STANDARD TABLE OF zi_asset_itm WITH EMPTY KEY,
           tt_assetitm TYPE STANDARD TABLE OF zi_asset_itm WITH EMPTY KEY.

    DATA: gt_asset     TYPE tt_result,
          gt_log       TYPE tt_api_log,
          it_asset_log TYPE tt_api_log,
          wa_asset_log LIKE LINE OF it_asset_log,
          lt_return    TYPE TABLE OF zi_asset_itm,
          wa_return    TYPE zi_asset_itm.

    INTERFACES if_serializable_object.
    INTERFACES if_abap_parallel.

    METHODS constructor
      IMPORTING
        it_asset TYPE tt_result OPTIONAL.

    METHODS create_asset.

    METHODS call_create_asset_api
      IMPORTING
        is_asset TYPE zi_asset_itm
      EXPORTING
        et_log   TYPE tt_api_log.

    METHODS get_hdr_data
      EXPORTING
        et_item TYPE tt_result.

    METHODS get_log
      EXPORTING
        et_log1 TYPE tt_api_log .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ASSET_PARALLEL IMPLEMENTATION.


  METHOD constructor.
    gt_asset[] = it_asset[].

    " Build Basic Auth — same pattern as reference class
    CONCATENATE 'USER_API:' '@o~g#cf{<NGN5G}9$G5V7WgL34endNZYv4XcW&%Q' INTO lv_plain .
*    lv_plain   = |USER_API:@o~g#cf{<NGN5G}9$G5V7WgL34endNZYv4XcW&%Q|.
    lv_encoded = cl_web_http_utility=>encode_base64( lv_plain ).
    lv_auth    = |Basic { lv_encoded }|.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    IF gt_asset[] IS NOT INITIAL.
      create_asset( ).
    ENDIF.
  ENDMETHOD.


  METHOD create_asset.

    DATA: lt_api_log TYPE tt_api_log.

    LOOP AT gt_asset ASSIGNING FIELD-SYMBOL(<fs_item>).

      CLEAR lt_api_log.

      call_create_asset_api(
        EXPORTING
          is_asset = <fs_item>
        IMPORTING
          et_log   = lt_api_log
      ).

      LOOP AT lt_api_log ASSIGNING FIELD-SYMBOL(<fs_log>) WHERE asset_no IS NOT INITIAL .
*        APPEND <fs_log> TO gt_log.
        <fs_item>-Assetno = <fs_log>-asset_no .
      ENDLOOP.

      CLEAR : lt_api_log[] .
    ENDLOOP.

  ENDMETHOD.


  METHOD call_create_asset_api.

    CONSTANTS:
      lc_base_url TYPE string VALUE 'https://my430714-api.s4hana.cloud.sap',
      lc_uri_csrf TYPE string VALUE '/sap/opu/odata4/sap/api_fixedasset/srvd_a2x/sap/fixedasset/0001/FixedAsset',
      lc_uri_post TYPE string VALUE '/sap/opu/odata4/sap/api_fixedasset/srvd_a2x/sap/fixedasset/0001/FixedAsset/SAP__self.CreateMasterFixedAsset'.

    DATA: lv_token        TYPE string,
          lv_payload      TYPE string,
          lv_response_txt TYPE string,
          wa_log          TYPE ty_api_log.

    CLEAR et_log.

    TYPES: BEGIN OF ty_asset_response,
             masterfixedasset TYPE string,
             fixedasset       TYPE string,
             companycode      TYPE string,
             assetclass       TYPE string,
           END OF ty_asset_response.

    DATA ls_response_n TYPE ty_asset_response.

    " ── 1. Create HTTP destination & client ─────────────────────────────────
    TRY.
        DATA(lo_dest) = cl_http_destination_provider=>create_by_url(
          i_url = lc_base_url ).

        DATA(lo_http) = cl_web_http_client_manager=>create_by_http_destination(
          i_destination = lo_dest ).

      CATCH cx_root INTO DATA(lx_dest).
        wa_log-status_code  = 500.
        wa_log-asset_class  = is_asset-AssetClass.
        wa_log-asset_desc   = is_asset-AssetDesc.
        wa_log-message_text = |Destination creation failed: { lx_dest->get_text( ) }|.
        APPEND wa_log TO et_log.
        APPEND wa_log TO gt_log.
        RETURN.
    ENDTRY.

    " ── 2. GET to fetch CSRF token ──────────────────────────────────────────
    TRY.
        DATA(lo_get_req) = lo_http->get_http_request( ).
        lo_get_req->set_uri_path( i_uri_path = lc_uri_csrf ).
        lo_get_req->set_header_field( i_name = 'x-csrf-token'  i_value = 'fetch' ).
        lo_get_req->set_header_field( i_name = 'Authorization' i_value = lv_auth ).
        lo_get_req->set_header_field( i_name = 'Accept'        i_value = 'application/json' ).

        DATA(lo_get_resp)   = lo_http->execute( i_method = if_web_http_client=>get ).
        lv_token            = lo_get_resp->get_header_field( 'x-csrf-token' ).
        DATA(ls_get_status) = lo_get_resp->get_status( ).

        IF ls_get_status-code <> 200.
          wa_log-status_code  = ls_get_status-code.
          wa_log-asset_class  = is_asset-AssetClass.
          wa_log-asset_desc   = is_asset-AssetDesc.
          wa_log-message_text = |CSRF fetch failed – HTTP { ls_get_status-code }: { ls_get_status-reason }|.
          APPEND wa_log TO et_log.
          APPEND wa_log TO gt_log.
          lo_http->close( ).
          RETURN.
        ENDIF.

      CATCH cx_root INTO DATA(lx_get).
        wa_log-status_code  = 500.
        wa_log-asset_class  = is_asset-AssetClass.
        wa_log-asset_desc   = is_asset-AssetDesc.
        wa_log-message_text = |GET (CSRF fetch) exception: { lx_get->get_text( ) }|.
        APPEND wa_log TO et_log.
        APPEND wa_log TO gt_log.
        lo_http->close( ).
        RETURN.
    ENDTRY.

    " ── 3. Format dates ─────────────────────────────────────────────────────
    DATA(lv_date1)      = cl_abap_context_info=>get_system_date( ) ."is_asset-CapitalizationDate.  " e.g. 20260401
    DATA(lv_curr_str) = |{ lv_date1+0(4) }-{ lv_date1+4(2) }-{ lv_date1+6(2) }|.

    " ── 4. Conditional: AcqnProdnCostScrapPercent ───────────────────────────
    " Only include scrap percent block if value exists on the item
    DATA(lv_scrap_01) = COND string(
      WHEN is_asset-ScrapValPct IS NOT INITIAL
      THEN |,"AcqnProdnCostScrapPercent":{ is_asset-ScrapValPct }|
      ELSE ||
    ).

    DATA(lv_scrap_15) = lv_scrap_01.  " same value applied to both areas

    " ── 5. Conditional: Plant in _AccountAssignment ─────────────────────────
    " ── 3. Conditional: Plant in _AccountAssignment ─────────────────────────
    DATA(lv_plant) = COND string(
      WHEN is_asset-Plant IS NOT INITIAL
      THEN |,"Plant":"{ is_asset-Plant }"|
      ELSE ||
    ).

    " ── 4. Build JSON Payload ───────────────────────────────────────────────
***    lv_payload = |\{|                                                          &&
***      |"CompanyCode":"{ is_asset-CompanyCode }",|                              &&
***      |"AssetClass":"{ is_asset-AssetClass }",|                                &&
***      |"AssetIsForPostCapitalization":false,|                                  &&
***
***      |"_AccountAssignment":\{|                                                &&
***        |"CostCenter":"{ is_asset-CostCenter }",|                             &&
***        |"ProfitCenter":"{ is_asset-ProfitCenter }"|                          &&
***        lv_plant &&
***      |\},|                                                                    &&
***
***      |"_General":\{|                                                          &&
***        |"FixedAssetDescription":"{ is_asset-AssetDesc }",|                   &&
***        |"AssetAdditionalDescription":"{ is_asset-AssetDesc2 }",|            &&
***        |"BaseUnitSAPCode":"{ is_asset-BaseUom }",|                           &&
***        |"BaseUnitISOCode":"{ is_asset-BaseUom }"|                            &&
***      |\},|                                                                    &&
***
***      |"_Ledger":[|                                                            &&
***        |\{|                                                                   &&
***          |"Ledger":"{ is_asset-Ledger }",|                                   &&
***          |"_Valuation":[|                                                     &&
***            |\{|                                                               &&
***              |"AssetDepreciationArea":"{ is_asset-RealDepArea }"|            &&
***            |\},|                                                              &&
***            |\{|                                                               &&
***              |"AssetDepreciationArea":"15"|                                   &&
***            |\}|                                                               &&
***          |]|                                                                  &&
***        |\}|                                                                   &&
***      |]|                                                                      &&
***    |\}|.

    " ── 3. Format capitalization date ───────────────────────────────────────
    DATA(lv_dt_string) = |1900-01-01|.
    " ── 4. Conditional: AcqnProdnCostScrapPercent ───────────────────────────
    DATA(lv_scrap) = COND string(
      WHEN is_asset-ScrapValPct IS NOT INITIAL
      THEN |,"AcqnProdnCostScrapPercent":{ is_asset-ScrapValPct }|
      ELSE ||
    ).



    " ── 6. Build JSON Payload ───────────────────────────────────────────────
    lv_payload = |\{|                                                          &&
      |"CompanyCode":"{ is_asset-CompanyCode }",|                              &&
      |"AssetClass":"{ is_asset-AssetClass }",|                                &&
      |"AssetIsForPostCapitalization":false,|                                  &&

      |"_AccountAssignment":\{|                                                &&
        |"CostCenter":"{ is_asset-CostCenter }",|                             &&
        |"ProfitCenter":"{ is_asset-ProfitCenter }"|                          &&
        lv_plant &&
      |\},|                                                                    &&

      |"_General":\{|                                                          &&
        |"FixedAssetDescription":"{ is_asset-AssetDesc }",|                   &&
        |"BaseUnitSAPCode":"{ is_asset-BaseUom }",|                           &&
        |"BaseUnitISOCode":"{ is_asset-BaseUom }"|                            &&
      |\},|                                                                    &&

      |"_Ledger":[|                                                            &&
        |\{|                                                                   &&
          |"Ledger":"{ is_asset-Ledger }",|                                   &&
*          |"AssetCapitalizationDate":"{ lv_curr_str }",|                      &&
          |"_Valuation":[|                                                     &&
            " ── Depreciation Area 01 ────────────────────────────────────────
            |\{|                                                               &&
              |"AssetDepreciationArea":"{ is_asset-RealDepArea }",|           &&
              |"_TimeBasedValuation":[|                                        &&
                |\{|                                                           &&
                  |"ValidityStartDate":"{ lv_dt_string }",|                         &&
                  |"PlannedUsefulLifeInYears":"6"|      &&
                  lv_scrap &&
                |\}|                                                           &&
              |]|                                                              &&
            |\},|                                                              &&

            " ── Depreciation Area 15 ────────────────────────────────────────
            |\{|                                                               &&
              |"AssetDepreciationArea":"15",|                                  &&
              |"_TimeBasedValuation":[|                                        &&
                |\{|                                                           &&
                  |"ValidityStartDate":"{ lv_dt_string }",|                         &&
                  |"PlannedUsefulLifeInYears":"6"|      &&
                  lv_scrap &&
                |\}|                                                           &&
              |]|                                                              &&
            |\}|                                                               &&

          |]|                                                                  &&
        |\}|                                                                   &&
      |]|                                                                      &&
    |\}|.

    " ── 7. POST to CreateMasterFixedAsset ───────────────────────────────────
    TRY.
        DATA(lo_post_req) = lo_http->get_http_request( ).
        lo_post_req->set_uri_path( i_uri_path = lc_uri_post ).
        lo_post_req->set_header_field( i_name = 'x-csrf-token'  i_value = lv_token ).
        lo_post_req->set_header_field( i_name = 'Authorization' i_value = lv_auth ).
        lo_post_req->set_header_field( i_name = 'Content-Type'  i_value = 'application/json' ).
        lo_post_req->set_header_field( i_name = 'Accept'        i_value = 'application/json' ).
        lo_post_req->set_text( i_text = lv_payload ).

        DATA(lo_post_resp)   = lo_http->execute( i_method = if_web_http_client=>post ).
        lv_response_txt      = lo_post_resp->get_text( ).
        DATA(ls_post_status) = lo_post_resp->get_status( ).

        IF ls_post_status-code = 200 OR ls_post_status-code = 201.

          /ui2/cl_json=>deserialize(
            EXPORTING
              json        = lv_response_txt
              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING
              data        = ls_response_n
          ).

          IF ls_response_n-masterfixedasset IS NOT INITIAL.
            wa_log-status_code  = ls_post_status-code.
            wa_log-asset_class  = is_asset-AssetClass.
            wa_log-asset_desc   = is_asset-AssetDesc.
            wa_log-asset_no     = ls_response_n-masterfixedasset.
            wa_log-message_text = |{ ls_response_n-masterfixedasset }|.
          ENDIF.

        ELSE.

          DATA(lv_msg)       = lv_response_txt.
          DATA(lv_msg_after) = substring_after( val = lv_msg sub = '"message":"' ).
          IF lv_msg_after IS NOT INITIAL.
            DATA(lv_msg_end) = find( val = lv_msg_after sub = '"' ).
            IF lv_msg_end > 0.
              lv_msg = substring( val = lv_msg_after len = lv_msg_end ).
            ENDIF.
          ENDIF.

          wa_log-status_code  = ls_post_status-code.
          wa_log-asset_class  = is_asset-AssetClass.
          wa_log-asset_desc   = is_asset-AssetDesc.
          wa_log-message_text = |{ ls_post_status-code }: { lv_msg }|.
          CLEAR: lv_msg.

        ENDIF.

        APPEND wa_log TO et_log.
        APPEND wa_log TO gt_log.

      CATCH cx_root INTO DATA(lx_post).
        wa_log-status_code  = 500.
        wa_log-asset_class  = is_asset-AssetClass.
        wa_log-asset_desc   = is_asset-AssetDesc.
        wa_log-message_text = |POST exception: { lx_post->get_text( ) }|.
        APPEND wa_log TO et_log.
        APPEND wa_log TO gt_log.
    ENDTRY.

    CLEAR: wa_log, lv_curr_str .
    lo_http->close( ).

  ENDMETHOD.


  METHOD get_hdr_data .
    IF gt_asset[] IS NOT INITIAL.
      et_item = gt_asset[] .
    ENDIF.
  ENDMETHOD.


  METHOD get_log.
    IF gt_log[] IS NOT INITIAL.
      et_log1 =  gt_log[] .
    ENDIF.
  ENDMETHOD.
ENDCLASS.
