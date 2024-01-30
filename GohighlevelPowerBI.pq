// This file contains your Data Connector logic
section GohighlevelPowerBI;

client_id = "";
client_secret = "";

LocationId = Record.Field(Extension.CurrentCredential()[Properties], "locationId");
companyid = Record.Field(Extension.CurrentCredential()[Properties], "companyId");

GohighlevelPowerBI.GetCurrentCredential = () => Extension.CurrentCredential();

redirectUrl = "https://oauth.powerbi.com/views/oauthredirect.html";
authorize_uri = "https://marketplace.gohighlevel.com/oauth/chooselocation?";

windowWidth = 720;
windowHeight = 1024;

[DataSource.Kind="GohighlevelPowerBI", Publish="GohighlevelPowerBI.Publish"]

shared GohighlevelPowerBI.NavTableNested = (location_id as text) as table =>
    let

        /////////////////////////////////////////////////////////////////////////////////////////
        GohighlevelPowerBI.SearchOpportunity = Value.ReplaceType(GohighlevelPowerBI.SearchOpportunityImpl, GohighlevelPowerBI.SearchOpportunityType),
        GohighlevelPowerBI.SearchOpportunityType =
            type function (  
                             /*location_id as (type text meta [
                                Documentation.FieldCaption = "location_id",
                                Documentation.AllowedValues = {location_id}
                                ]),*/
                             optional startDate as (type date meta [
                                Documentation.FieldCaption = "date"
                             ]),
                             optional endDate as (type date meta [
                                Documentation.FieldCaption = "endDate"
                             ])
                           )
                as function meta [
                    Documentation.Name = "Search Opportunity",
                    Documentation.LongDescription = "Search Opportunity"
            ],


        GohighlevelPowerBI.GetContacts = Value.ReplaceType(GohighlevelPowerBI.GetContactsImpl, GohighlevelPowerBI.GetContactsType),
        GohighlevelPowerBI.GetContactsType =
            type function (  /*
                             location_id as (type text meta [
                                Documentation.FieldCaption = "location_id",
                                Documentation.AllowedValues = {location_id}
                                ])*/
                           )
                as function meta [
                    Documentation.Name = "Get Contacts",
                    Documentation.LongDescription = "Get Contacts"
            ],


        GohighlevelPowerBI.GetCustomFields = Value.ReplaceType(GohighlevelPowerBI.GetCustomFieldsImpl, GohighlevelPowerBI.GetCustomFieldsType),
        GohighlevelPowerBI.GetCustomFieldsType =
            type function (  /*
                             location_id as (type text meta [
                                Documentation.FieldCaption = "location_id",
                                Documentation.AllowedValues = {location_id}
                                ]), */
                             optional model as (type text meta [
                                Documentation.FieldCaption = "model",
                                Documentation.AllowedValues = {"contact","opportunity", "all"}
                             ])
                           )
                as function meta [
                    Documentation.Name = "Get Custom Fields",
                    Documentation.LongDescription = "Get Custom Fields"
            ],


        /////////////////////////////////////////////////////////////////////////////////////////



        NavTable = (tb as table) => Table.ToNavigationTable(tb, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        table_header = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},

        lv1 = #table(
            table_header,
            {
                {"SearchOpportunity", "SearchOpportunity", GohighlevelPowerBI.SearchOpportunity, "function", "function", "true"},
                {"GetContacts", "GetContacts", GohighlevelPowerBI.GetContacts, "function", "function", "true"},
                {"GetCustomFields", "GetCustomFields", GohighlevelPowerBI.GetCustomFields, "function", "function", "true"}
                //{"GetCurrentCredential", "GetCurrentCredential", GohighlevelPowerBI.GetCurrentCredential, "function", "function", "true"}
            }   
        )
    in
        NavTable(lv1);


GohighlevelPowerBI.SearchOpportunityImpl = (
        //location_id, 
        optional startDate as date,
        optional endDate as date
        ) =>
    let
        u = "https://services.leadconnectorhq.com/opportunities/search",
        p = 
            let
                p0 = [location_id = LocationId, limit="100"],
                p1 = add_rec(p0, "date",Date.ToText(startDate, "MM-dd-yyyy")),
                p2= add_rec(p1, "endDate",Date.ToText(endDate, "MM-dd-yyyy"))
            in
                p2,
                
        json = GohighlevelPowerBI.GetData(u, p, 1, "opportunities")
    in
        toTable(json);


GohighlevelPowerBI.GetCustomFieldsImpl = (
        //location_id, 
        optional model as text
        ) =>
    let     
        u = "https://services.leadconnectorhq.com/locations/" &LocationId& "/customFields",
        p = 
            let
                //p0 = [location_id = LocationId],
                p1 = add_rec([], "model", model)
            in
                p1,
                
        json = GohighlevelPowerBI.GetData(u, p, null, "customFields")
    in
        toTable(json);


GohighlevelPowerBI.GetContactsImpl = (
        //location_id as text
        ) =>
    let
        u = "https://services.leadconnectorhq.com/contacts/",
        p = 
            let
                p0 = [locationId = LocationId, limit="100"]
            in
                p0,
                
        json = GohighlevelPowerBI.GetData(u, p, null, "contacts")
    in
        toTable(json);


GohighlevelPowerBI.GetData = (endpoint, params as record, optional start_page as number, optional obj_name as text) =>
    let
        h = [Version = "2021-07-28", Accept= "application/json"],
        p = params,

        f = (optional page as number)=>
            let
                p = add_rec(p, "page", page) ,
                j = Json.Document(Web.Contents(endpoint, [Headers=h, Query=p]), 65001)
            in
                Record.FieldOrDefault(j, obj_name, j),
        
        json = if start_page is null then f(110) else GetAllPageData(start_page,1,f)
    in
        json;
//Data Source Authentication


GetAllPageData = (startpos as any, step as number, func as function) as list =>
    if not(startpos is null) then
        List.Combine(
            List.Generate( 
                ()=> [ x = startpos , y = func(x)],
                each not(List.IsEmpty([y])),
                each [ x=[x] + step, y = func(x) ],
                each [y]
            )
        )
    else
        func(startpos);



GohighlevelPowerBI = [
    //TestConnection = (dataSourcePath) => {"XeroBear.NavTableNested"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = "GohighlevelPowerBI"
];

// Data Source Kind description
StartLogin = (resourceUrl, state, display) =>
        let
                AuthorizeUrl = authorize_uri & Uri.BuildQueryString([
                response_type="code",
                client_id = client_id,
                scope = "contacts.readonly opportunities.readonly locations/customFields.readonly",
                redirect_uri = redirectUrl
                ])
        in
            [
                LoginUri = AuthorizeUrl,
                CallbackUri = redirectUrl,
                WindowHeight = windowHeight,
                WindowWidth = windowWidth,
                Context = null
            ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod("authorization_code","&code="&Parts[code]);

TokenMethod = (GrantType, code as text) =>
    let
        url = "https://services.leadconnectorhq.com/oauth/token",
        codeEncodingBase64 = EncodeBase64(),
        header = [Accept= "application/json" , #"Content-Type"="application/x-www-form-urlencoded"],
        data = Text.ToBinary("client_id="&client_id&"&client_secret="&client_secret&"&grant_type="&GrantType&code&"&user_type=Location"&"&redirect_uri="&redirectUrl),
        Parts = Json.Document(Web.Contents(url,[Headers=header,Content=data]),65001)
    in 
        Parts;

Refresh = (resourceUrl, refreshToken) => TokenMethod("refresh_token","&refresh_token="&refreshToken);

EncodeBase64 = () => Binary.ToText(Text.ToBinary(client_id&":"&client_secret, BinaryEncoding.Base64));


// Data Source UI publishing description
GohighlevelPowerBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = GohighlevelPowerBI.Icons,
    SourceTypeImage = GohighlevelPowerBI.Icons
];

GohighlevelPowerBI.Icons = [
    Icon16 = { Extension.Contents("GohighlevelPowerBI16.png"), Extension.Contents("GohighlevelPowerBI20.png"), Extension.Contents("GohighlevelPowerBI24.png"), Extension.Contents("GohighlevelPowerBI32.png") },
    Icon32 = { Extension.Contents("GohighlevelPowerBI32.png"), Extension.Contents("GohighlevelPowerBI40.png"), Extension.Contents("GohighlevelPowerBI48.png"), Extension.Contents("GohighlevelPowerBI64.png") }
];


add_rec = (rec as record, recname as text, value as any) =>
    if value is null then rec else Record.AddField(rec, recname, Text.From(value));

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;


toTable = (lstrec as list, optional index as number, optional filds_name_sample as list) as table =>
    let
        fieldnames = 
            let
                list_combo = if filds_name_sample is null then lstrec else List.Combine( {filds_name_sample, lstrec} ),    
                toprows = if index is null then list_combo else List.FirstN(list_combo, index),
                listfields = List.Transform(toprows, Record.FieldNames),
                namesdistinct = List.Union(listfields)
            in
                namesdistinct,
        tbl = Table.FromRecords( lstrec, fieldnames, MissingField.UseNull)
    in
        tbl;