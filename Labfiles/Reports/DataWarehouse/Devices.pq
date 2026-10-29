// Intune Data Warehouse: current device list with ownership and compliance state (for pivot tables)
// Excel: Data > Get Data > From Other Sources > Blank Query > Advanced Editor, paste, set FeedUrl, Done.
// FeedUrl: Reports > Intune Data warehouse > Data warehouse, OData feed URL WITHOUT "?api-version=...".
let
    FeedUrl    = "https://fef.<location>.manage.microsoft.com/ReportingService/DataWarehouseFEService",
    Source     = OData.Feed(FeedUrl, null, [Implementation = "2.0", Query = [#"api-version" = "v1.0"]]),
    Devices    = Source{[Name = "devices", Signature = "table"]}[Data],
    Owners     = Source{[Name = "ownerTypes", Signature = "table"]}[Data],
    Compliance = Source{[Name = "complianceStates", Signature = "table"]}[Data],
    Active     = Table.SelectRows(Devices, each [isDeleted] = false),
    WithOwner  = Table.ExpandTableColumn(Table.NestedJoin(Active, {"ownerTypeKey"}, Owners, {"ownerTypeKey"}, "o", JoinKind.LeftOuter), "o", {"ownerTypeName"}, {"Ownership"}),
    WithState  = Table.ExpandTableColumn(Table.NestedJoin(WithOwner, {"complianceStateKey"}, Compliance, {"complianceStateKey"}, "c", JoinKind.LeftOuter), "c", {"complianceStatus"}, {"Compliance"}),
    Result     = Table.SelectColumns(WithState, {"deviceName", "operatingSystem", "manufacturer", "model", "Ownership", "Compliance", "enrolledDateTime", "lastSyncDateTime", "serialNumber"})
in
    Result
