// Intune Data Warehouse: daily compliance trend (last 30 days)
// Excel: Data > Get Data > From Other Sources > Blank Query > Advanced Editor, paste, set FeedUrl, Done.
// Sign in with "Organizational account" when Excel asks.
// FeedUrl: Intune admin center > Reports > Intune Data warehouse > Data warehouse, copy the OData feed URL
//          WITHOUT "?api-version=..." (the query below adds it).
let
    FeedUrl  = "https://fef.<location>.manage.microsoft.com/ReportingService/DataWarehouseFEService",
    Source   = OData.Feed(FeedUrl & "?maxHistoryDays=30", null, [Implementation = "2.0", Query = [#"api-version" = "v1.0"]]),
    Activity = Source{[Name = "compliancePolicyStatusDeviceActivities", Signature = "table"]}[Data],
    Dates    = Source{[Name = "dates", Signature = "table"]}[Data],
    Joined   = Table.NestedJoin(Activity, {"dateKey"}, Dates, {"dateKey"}, "d", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "d", {"fullDate"}, {"Date"}),
    Columns  = Table.SelectColumns(Expanded, {"Date", "compliant", "nonCompliant", "inGracePeriod", "notApplicable", "unknown", "error"}),
    Typed    = Table.TransformColumnTypes(Columns, {{"Date", type date}}),
    Sorted   = Table.Sort(Typed, {{"Date", Order.Ascending}})
in
    Sorted
