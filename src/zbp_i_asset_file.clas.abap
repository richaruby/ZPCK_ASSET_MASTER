CLASS zbp_i_asset_file DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_asset_file.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_asset_itm,
             company_code  TYPE string,
             asset_class   TYPE string,
             asset_desc    TYPE string,
             asset_desc2   TYPE string,
             base_uom      TYPE string,
             cost_center   TYPE string,
             profit_center TYPE string,
             plant         TYPE string,
             ledger        TYPE string,
             real_dep_area TYPE string,
             scrap_val_pct TYPE string,
           END OF ty_asset_itm,
           tt_asset_itm TYPE STANDARD TABLE OF ty_asset_itm WITH EMPTY KEY.


ENDCLASS.



CLASS ZBP_I_ASSET_FILE IMPLEMENTATION.
ENDCLASS.
