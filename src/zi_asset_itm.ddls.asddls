@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View - Asset Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_ASSET_ITM
  as select from zdb_asset_itm
  association to parent ZI_ASSET_FILE as _AssetFile on  $projection.EndUser = _AssetFile.EndUser
                                                    and $projection.FileId  = _AssetFile.FileId
{
      /* Keys */
  key end_user      as EndUser,
  key file_id       as FileId,
  key line_id       as LineId,
  key line_no       as LineNo1,

      /* Organizational Data */
      company_code  as CompanyCode,
      plant         as Plant,
      profit_center as ProfitCenter,
      cost_center   as CostCenter,
      base_uom      as BaseUom,

      /* Asset Data */
      asset_class   as AssetClass,
      asset_desc    as AssetDesc,
      asset_desc2   as AssetDesc2,
      ledger        as Ledger,
      real_dep_area as RealDepArea,
      scrap_val_pct as ScrapValPct,
      assetno       as Assetno,
      /* Audit */
      created_by    as CreatedBy,
      created_on    as CreatedOn,

      /* Parent association */
      _AssetFile
}
