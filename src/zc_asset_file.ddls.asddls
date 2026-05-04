@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection Entity - Asset File'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define root view entity ZC_ASSET_FILE
  provider contract transactional_query
  as projection on ZI_ASSET_FILE
{
  key EndUser,
  key FileId,

      FileStatus,

      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'Filename',
        acceptableMimeTypes: [
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/pdf',
          'image/jpeg',
          'image/png'
        ],
        contentDispositionPreference: #INLINE
      }
      Attachment,

      @Semantics.mimeType: true
      Mimetype,

      Filename,

      CreateOndt,

      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      UiRefreshTs,  
      /* Associations */
      _AssetData : redirected to composition child ZC_ASSET_ITEM
}
