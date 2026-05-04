@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View - Asset File'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define root view entity ZI_ASSET_FILE
  as select from zdb_asset_file
  composition [0..*] of ZI_ASSET_ITM as _AssetData
{
  key end_user              as EndUser,
  key file_id               as FileId,

      file_status           as FileStatus,

      attachment            as Attachment,

      @Semantics.mimeType: true
      mimetype              as Mimetype,

      filename              as Filename,

      create_ondt           as CreateOndt,

      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,

      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,

      @Semantics.user.lastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      ui_refresh_ts         as UiRefreshTs,

      _AssetData

}
