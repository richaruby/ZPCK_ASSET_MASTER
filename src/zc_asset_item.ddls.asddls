@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection Entity - Asset Item'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_ASSET_ITEM
  as projection on ZI_ASSET_ITM
{
  key EndUser,
  key FileId,
  key LineId,
  key LineNo1,

      CompanyCode,
      Plant,
      ProfitCenter,
      CostCenter,
      BaseUom,
      AssetClass,
      AssetDesc,
      AssetDesc2,
      Ledger,
      RealDepArea,
      ScrapValPct,
      Assetno,
      CreatedBy,
      CreatedOn,
      /* Associations */
      _AssetFile : redirected to parent ZC_ASSET_FILE
}
