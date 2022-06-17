#Region FormEvents

Procedure OnCreateAtServer(Object, Form, Cancel, StandardProcessing) Export
	If Not Object.Ref.Metadata().TabularSections.Find("AddAttributes") = Undefined 
		And Not Form.Items.Find("GroupOther") = Undefined Then
		AddAttributesAndPropertiesServer.OnCreateAtServer(Form, "GroupOther");
		ExtensionServer.AddAttributesFromExtensions(Form, Object.Ref, Form.Items.GroupOther);
	EndIf;

	AddCommonAttributesToForm(Object, Form);

	If SessionParameters.isMobile Then
		DocumentsServerMobile.OnCreateAtServer(Object, Form, Cancel, StandardProcessing);
	Else
		If Form.Items.Find("GroupTitleCollapsed") <> Undefined Then
			DocumentsClientServer.ChangeTitleCollapse(Object, Form, Not ValueIsFilled(Object.Ref));
		EndIf;
	EndIf;

	ExternalCommandsServer.CreateCommands(Form, Object.Ref.Metadata().FullName(), Enums.FormTypes.ObjectForm);
EndProcedure

Procedure OnReadAtServer(Object, Form, CurrentObject) Export
	Return;
EndProcedure

Procedure OnWriteAtServer(Object, Form, Cancel, CurrentObject, WriteParameters) Export
	If Not Object.Ref.Metadata().TabularSections.Find("ItemList") = Undefined Then
		WriteSavedItems(Object, CurrentObject);
	EndIf;
EndProcedure

#EndRegion

#Region ItemList

Procedure SetNewTableUUID(Table, LinkedTables) Export
	For Each TableRow In Table Do

		CurrentKey = TableRow.Key;
		TableRow.Key = New UUID();

		For Each LinkedTable In LinkedTables Do
			Rows = LinkedTable.FindRows(New Structure("Key", CurrentKey));
			For Each Row In Rows Do
				Row.Key = TableRow.Key;
			EndDo;
		EndDo;

	EndDo;
EndProcedure

Procedure FillItemList(Object, Form = Undefined) Export

	RowMap = New Map();

	For Each Row In Object.ItemList Do
		RowMap.Insert(Row.Key, Row);
		Row.Item = Row.ItemKey.Item;
		If TypeOf(Object.Ref) = Type("DocumentRef.SalesOrder") Then
			Row.ItemType = Row.Item.ItemType.Type;
		EndIf;
	EndDo;

	Query = New Query();
	Query.Text =
	"SELECT
	|	SavedItems.Key,
	|	SavedItems.Item
	|FROM
	|	InformationRegister.SavedItems AS SavedItems
	|WHERE
	|	SavedItems.ObjectRef = &ObjectRef";

	Query.SetParameter("ObjectRef", Object.Ref);

	QueryResult = Query.Execute();

	SelectionDetailRecords = QueryResult.Select();

	While SelectionDetailRecords.Next() Do
		RowMap[SelectionDetailRecords.Key].Item = SelectionDetailRecords.Item;
		If TypeOf(Object.Ref) = Type("DocumentRef.SalesOrder") Then
			RowMap[SelectionDetailRecords.Key].ItemType = RowMap[SelectionDetailRecords.Key].Item.ItemType.Type;
		EndIf;
	EndDo;

EndProcedure

Procedure WriteSavedItems(Object, CurrentObject)

	ObjectRef = CurrentObject.Ref;
	ItemList = Object.ItemList.Unload().Copy(New Structure("ItemKey", PredefinedValue("Catalog.ItemKeys.EmptyRef")));

	If ItemList.Count() = 0 Then
		RecordSet = InformationRegisters.SavedItems.CreateRecordSet();
		RecordSet.Filter.ObjectRef.Set(ObjectRef);
		RecordSet.Write(True);
		Return;
	EndIf;

	ItemList.Columns.Add("ObjectRef");
	ItemList.FillValues(ObjectRef, "ObjectRef");

	RecordSet = InformationRegisters.SavedItems.CreateRecordSet();
	RecordSet.Filter.ObjectRef.Set(ObjectRef);

	RecordSet.Load(ItemList);
	RecordSet.Write(True);

EndProcedure

Function CheckItemListStores(Object) Export

	Query = New Query();
	Query.Text =
	"SELECT
	|	Table.LineNumber,
	|	Table.Store,
	|	Table.ItemKey
	|INTO ItemList
	|FROM
	|	&ItemList AS Table
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ItemList.LineNumber,
	|	ItemList.Store,
	|	ItemList.ItemKey
	|FROM
	|	ItemList AS ItemList
	|WHERE
	|	Not ItemList.ItemKey.Item.ItemType.Type = Value(Enum.ItemTypes.Service)
	|	AND  ItemList.Store = Value(Catalog.Stores.EmptyRef)";

	Query.SetParameter("ItemList", Object.ItemList.Unload());
	QueryResult = Query.Execute();

	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;

	SelectionDetailRecords = QueryResult.Select();

	While SelectionDetailRecords.Next() Do
		CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_072, SelectionDetailRecords.LineNumber),
			"ItemList[" + Format((SelectionDetailRecords.LineNumber - 1), "NZ=0; NG=0;") + "].Store", Object);
	EndDo;

	Return True;
EndFunction

#EndRegion

#Region PaymentList

Procedure FillCheckBankCashDocuments(Object, CheckedAttributes) Export
	If Object.TransactionType = PredefinedValue("Enum.IncomingPaymentTransactionType.CurrencyExchange")
		Or Object.TransactionType = PredefinedValue("Enum.OutgoingPaymentTransactionTypes.CurrencyExchange") Then

		CheckedAttributes.Add("PaymentList.PlaningTransactionBasis");
		CheckedAttributes.Add("CurrencyExchange");

	ElsIf Object.TransactionType = PredefinedValue("Enum.IncomingPaymentTransactionType.CashTransferOrder")
		Or Object.TransactionType = PredefinedValue("Enum.OutgoingPaymentTransactionTypes.CashTransferOrder") Then

		CheckedAttributes.Add("PaymentList.PlaningTransactionBasis");

	EndIf;
EndProcedure

#EndRegion

#Region PartnerData

Function GetManagerSegmentByPartner(Partner) Export
	Return Partner.ManagerSegment;
EndFunction

// Description
// 
// Parameters:
// 	AgreementParameters - Structure:
//		* Partner - CatalogRef.Partners
//		* Agreement - CatalogRef.Agreements
//		* CurrentDate - Date
//		* ArrayOfFilters - Array of Filter
// Returns:
// 	CatalogRef.Agreements - Description
Function GetAgreementByPartner(AgreementParameters) Export

	Partner = AgreementParameters.Partner;

	If Not ValueIsFilled(Partner) Then
		Return Catalogs.Agreements.EmptyRef();
	EndIf;

	ArrayOfFilters = New Array();
	If AgreementParameters.Property("ArrayOfFilters") Then
		ArrayOfFilters = AgreementParameters.ArrayOfFilters;
	Else
		ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
		If AgreementParameters.Property("AgreementType") And ValueIsFilled(AgreementParameters.AgreementType) Then
			ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Type", AgreementParameters.AgreementType,
				ComparisonType.Equal));
		EndIf;
	EndIf;

	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("IncludeFilterByEndOfUseDate", True);
	AdditionalParameters.Insert("IncludeFilterByPartner", True);
	AdditionalParameters.Insert("IncludePartnerSegments", True);

	If AgreementParameters.Property("CurrentDate") Then
		CurrentDate = AgreementParameters.CurrentDate;
	Else
		CurrentDate = CurrentDate();
	EndIf;

	AdditionalParameters.Insert("EndOfUseDate", CurrentDate);
	AdditionalParameters.Insert("Partner", Partner);
	Parameters = New Structure("CustomSearchFilter, AdditionalParameters, Agreement",
		DocumentsServer.SerializeArrayOfFilters(ArrayOfFilters), DocumentsServer.SerializeArrayOfFilters(
		AdditionalParameters), AgreementParameters.Agreement);
	Return Catalogs.Agreements.GetDefaultChoiceRef(Parameters);

EndFunction

Function GetLegalNameByPartner(Partner, LegalName) Export
	If ValueIsFilled(Partner) Then
		ArrayOfFilters = New Array();
		ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
		AdditionalParameters = New Structure();
		If ValueIsFilled(Partner) Then
			AdditionalParameters.Insert("Partner", Partner);
			AdditionalParameters.Insert("FilterByPartnerHierarchy", True);
		EndIf;
		Parameters = New Structure("CustomSearchFilter, AdditionalParameters, LegalName",
			DocumentsServer.SerializeArrayOfFilters(ArrayOfFilters), DocumentsServer.SerializeArrayOfFilters(
			AdditionalParameters), LegalName);
		Return Catalogs.Companies.GetDefaultChoiceRef(Parameters);
	EndIf;
	Return Undefined;
EndFunction

Function GetBankAccountByPartner(Partner, LegalName, Currency) Export
	If Not (ValueIsFilled(Partner) And ValueIsFilled(LegalName) And ValueIsFilled(Currency)) Then
		Return Undefined;
	EndIf;
	Query = New Query();
	Query.Text =
	"SELECT TOP 1
	|	PartnersBankAccounts.Ref
	|FROM
	|	Catalog.PartnersBankAccounts AS PartnersBankAccounts
	|WHERE
	|	PartnersBankAccounts.Currency = &Currency
	|	AND PartnersBankAccounts.Partner = &Partner
	|	AND PartnersBankAccounts.LegalEntity = &LegalName
	|	AND NOT PartnersBankAccounts.DeletionMark";
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("Partner", Partner);
	Query.SetParameter("LegalName", LegalName);
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Return QuerySelection.Ref;
	Else
		Return Undefined;
	EndIf;
EndFunction

#EndRegion

#Region ListFormEvents

Procedure OnCreateAtServerListForm(Form, Cancel, StandardProcessing) Export
	FormNamesArray = StrSplit(Form.FormName, ".");
	DocumentFullName = FormNamesArray[0] + "." + FormNamesArray[1];
	ExternalCommandsServer.CreateCommands(Form, DocumentFullName, Enums.FormTypes.ListForm);
EndProcedure

#EndRegion

#Region ChoiceFormEvents

Procedure OnCreateAtServerChoiceForm(Form, Cancel, StandardProcessing) Export
	FormNamesArray = StrSplit(Form.FormName, ".");
	DocumentFullName = FormNamesArray[0] + "." + FormNamesArray[1];
	ExternalCommandsServer.CreateCommands(Form, DocumentFullName, Enums.FormTypes.ChoiceForm);
EndProcedure

#EndRegion

#Region TitleItems

Procedure DeleteUnavailableTitleItemNames(ItemNames) Export
	UnavailableNames = New Array();
	If Not FOServer.IsUseCompanies() Then
		UnavailableNames.Add("Company");
		UnavailableNames.Add("LegalName");
	EndIf;
	If Not FOServer.IsUsePartnerTerms() Then
		UnavailableNames.Add("Agreement");
	EndIf;
	For Each Name In UnavailableNames Do
		FoundedName = ItemNames.Find(Name);
		If FoundedName <> Undefined Then
			ItemNames.Delete(FoundedName);
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region PrepareServerData

Function PrepareServerData(Parameters) Export
	Result = New Structure();

	If Parameters.Property("TaxesCache") Then
		ArrayOfTaxInfo = New Array();
		RequireCallCreateTaxesFormControls = True;

		If ValueIsFilled(Parameters.TaxesCache.Cache) Then

			ArrayOfTaxesInCache = New Array();

			ArrayOfTaxes = New Array();

			DocumentName = Parameters.TaxesCache.Ref.Metadata().Name;
			ArrayOfAllTaxes = TaxesServer.GetTaxesByCompany(Parameters.TaxesCache.Date, Parameters.TaxesCache.Company);
			For Each ItemOfAllTaxes In ArrayOfAllTaxes Do
				If ItemOfAllTaxes.UseDocuments.FindRows(New Structure("DocumentName", DocumentName)).Count() Then
					ArrayOfTaxes.Add(ItemOfAllTaxes.Tax);
				EndIf;
			EndDo;

			AllTaxesInCache = True;
			For Each ItemOfTaxes In ArrayOfTaxes Do
				If ArrayOfTaxesInCache.Find(ItemOfTaxes) = Undefined Then
					AllTaxesInCache = False;
					Break;
				EndIf;
			EndDo;
			If AllTaxesInCache Then
				For Each ItemOfTaxesInCache In ArrayOfTaxesInCache Do
					If ArrayOfTaxes.Find(ItemOfTaxesInCache) = Undefined Then
						AllTaxesInCache = False;
						Break;
					EndIf;
				EndDo;
			EndIf;

			If AllTaxesInCache Then
				RequireCallCreateTaxesFormControls = False;
			EndIf;

		EndIf;

		Result.Insert("RequireCallCreateTaxesFormControls", RequireCallCreateTaxesFormControls);
		Result.Insert("ArrayOfTaxInfo", ArrayOfTaxInfo);
	EndIf;

	If Parameters.Property("GetManagerSegmentByPartner") Then
		Result.Insert("ManagerSegmentByPartner", DocumentsServer.GetManagerSegmentByPartner(
			Parameters.GetManagerSegmentByPartner.Partner));
	EndIf;

	If Parameters.Property("GetLegalNameByPartner") Then
		Result.Insert("LegalNameByPartner", DocumentsServer.GetLegalNameByPartner(
			Parameters.GetLegalNameByPartner.Partner, Parameters.GetLegalNameByPartner.LegalName));
	EndIf;

	If Parameters.Property("GetAgreementByPartner") Then
		AgreementParameters = New Structure();
		AgreementParameters.Insert("Partner", Parameters.GetAgreementByPartner.Partner);
		AgreementParameters.Insert("Agreement", Parameters.GetAgreementByPartner.Agreement);
		AgreementParameters.Insert("CurrentDate", Parameters.GetAgreementByPartner.Date);
		AgreementParameters.Insert("AgreementType", Enums.AgreementTypes.EmptyRef());

		AgreementParameters.AgreementType = Enums.AgreementTypes.Vendor;
		Result.Insert("AgreementByPartner_Vendor", DocumentsServer.GetAgreementByPartner(AgreementParameters));

		If Parameters.GetAgreementByPartner.Property("WithAgreementInfo") Then
			Result.Insert("AgreementInfoByPartner_Vendor", CatAgreementsServer.GetAgreementInfo(
				Result.AgreementByPartner_Vendor));
		EndIf;

		AgreementParameters.AgreementType = Enums.AgreementTypes.Customer;
		Result.Insert("AgreementByPartner_Customer", DocumentsServer.GetAgreementByPartner(AgreementParameters));

		If Parameters.GetAgreementByPartner.Property("WithAgreementInfo") Then
			Result.Insert("AgreementInfoByPartner_Customer", CatAgreementsServer.GetAgreementInfo(
				Result.AgreementByPartner_Customer));
		EndIf;
	EndIf;

	If Parameters.Property("GetAgreementInfo") Then
		AgreementInfo = CatAgreementsServer.GetAgreementInfo(Parameters.GetAgreementInfo.Agreement);
		Result.Insert("AgreementInfo", AgreementInfo);
		Result.Insert("AgreementInfo_PriceType_Presentation", String(AgreementInfo.PriceType));
	EndIf;

	If Parameters.Property("GetMetaDataStructure") Then
		Result.Insert("MetaDataStructure", ServiceSystemServer.GetMetaDataStructure(
			Parameters.GetMetaDataStructure.Ref));
	EndIf;

	If Parameters.Property("GetItemKeyByItem") Then
		Result.Insert("ItemKeyByItem", CatItemsServer.GetItemKeyByItem(Parameters.GetItemKeyByItem.Item));
	EndIf;

	If Parameters.Property("GetAgreementTypes_Vendor") Then
		Result.Insert("AgreementTypes_Vendor", PredefinedValue("Enum.AgreementTypes.Vendor"));
	EndIf;

	If Parameters.Property("GetAgreementTypes_Customer") Then
		Result.Insert("AgreementTypes_Customer", PredefinedValue("Enum.AgreementTypes.Customer"));
	EndIf;

	If Parameters.Property("GetPurchaseOrder_EmptyRef") Then
		Result.Insert("PurchaseOrder_EmptyRef", PredefinedValue("Document.PurchaseOrder.EmptyRef"));
	EndIf;

	If Parameters.Property("GetSalesOrder_EmptyRef") Then
		Result.Insert("SalesOrder_EmptyRef", PredefinedValue("Document.SalesOrder.EmptyRef"));
	EndIf;

	If Parameters.Property("GetPurchaseReturnOrder_EmptyRef") Then
		Result.Insert("PurchaseReturnOrder_EmptyRef", PredefinedValue("Document.PurchaseReturnOrder.EmptyRef"));
	EndIf;

	If Parameters.Property("GetSalesReturnOrder_EmptyRef") Then
		Result.Insert("SalesReturnOrder_EmptyRef", PredefinedValue("Document.SalesReturnOrder.EmptyRef"));
	EndIf;

	If Parameters.Property("GetPriceTypes_ManualPriceType") Then
		Result.Insert("PriceTypes_ManualPriceType", PredefinedValue("Catalog.PriceTypes.ManualPriceType"));
	EndIf;

	If Parameters.Property("GetTaxes_EmptyRef") Then
		Result.Insert("Taxes_EmptyRef", PredefinedValue("Catalog.Taxes.EmptyRef"));
	EndIf;

	If Parameters.Property("GetTaxAnalytics_EmptyRef") Then
		Result.Insert("TaxAnalytics_EmptyRef", PredefinedValue("Catalog.TaxAnalytics.EmptyRef"));
	EndIf;

	If Parameters.Property("GetTaxRates_EmptyRef") Then
		Result.Insert("TaxRates_EmptyRef", PredefinedValue("Catalog.TaxRates.EmptyRef"));
	EndIf;

	If Parameters.Property("GetItemUnitInfo") Then
		Result.Insert("ItemUnitInfo", GetItemInfo.ItemUnitInfo(Parameters.GetItemUnitInfo.ItemKey));
	EndIf;

	If Parameters.Property("GetItemKeysWithSerialLotNumbers") Then
		Query = New Query();
		Query.Text =
		"SELECT
		|	ItemKeys.Ref AS ItemKey
		|FROM
		|	Catalog.ItemKeys AS ItemKeys
		|WHERE
		|	ItemKeys.Item.ItemType.UseSerialLotNumber
		|	AND ItemKeys.Ref IN (&Refs)";
		Query.SetParameter("Refs", Parameters.GetItemKeysWithSerialLotNumbers);
		QueryResult = Query.Execute();
		ArrayOfItemKeysWithSerialLotNumbers = QueryResult.Unload().UnloadColumn("ItemKey");
		Result.Insert("ItemKeysWithSerialLotNumbers", ArrayOfItemKeysWithSerialLotNumbers);
	EndIf;

	If Parameters.Property("GetPaymentTerms") Then
		Agreement = Parameters.GetPaymentTerms.Agreement;
		ArrayOfPaymentTerms = New Array();
		If ValueIsFilled(Agreement) And ValueIsFilled(Agreement.PaymentTerm) Then
			For Each Stage In Agreement.PaymentTerm.StagesOfPayment Do
				NewRow = New Structure();
				NewRow.Insert("CalculationType", Stage.CalculationType);
				NewRow.Insert("ProportionOfPayment", Stage.ProportionOfPayment);
				NewRow.Insert("DuePeriod", Stage.DuePeriod);
				ArrayOfPaymentTerms.Add(NewRow);
			EndDo;
		EndIf;
		Result.Insert("PaymentTerms", ArrayOfPaymentTerms);
	EndIf;

	If Parameters.Property("GetRetailCustomerInfo") Then
		Result.Insert("RetailCustomerInfo", CatRetailCustomersServer.GetRetailCustomerInfo(
			Parameters.GetRetailCustomerInfo.RetailCustomer));
	EndIf;

	Return Result;
EndFunction

#EndRegion

#Region SpecialOffersInReturns

Procedure FillSpecialOffersCache(Object, Form, BasisDocumentName, AddInfo = Undefined) Export
	Form.SpecialOffersCache.Clear();
	Query = New Query();
	Query.TempTablesManager = New TempTablesManager();
	Query.Text =
	"SELECT
	|	ItemList.Key,
	|	ItemList.%1
	|INTO _tmpItemList
	|FROM
	|	&ItemList AS ItemList
	|;
	|Select
	|	RowIDInfo.Key AS Key,
	|	RowIDInfo.Basis AS Basis,
	|	RowIDInfo.BasisKey AS BasisKey
	|INTO tmpRowIDInfo
	|FROM
	|	&RowIDInfo AS RowIDInfo
	|;
	|Select
	|	RowIDInfo.BasisKey AS BasisKey,
	|	_tmpItemList.Key AS Key,
	|	_tmpItemList.%1
	|INTO tmpItemList
	|from _tmpItemList AS _tmpItemList
	|inner join tmpRowIDInfo AS RowIDInfo 
	|	ON _tmpItemList.%1 = RowIDInfo.Basis
	|	AND _tmpItemList.Key = RowIDInfo.Key
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tmpItemList.Key,
	|	BasisDocumentSpecialOffers.Offer,
	|	BasisDocumentSpecialOffers.Amount,
	|	BasisDocumentItemList.Quantity
	|FROM
	|	tmpItemList AS tmpItemList
	|		INNER JOIN Document.%1.SpecialOffers AS BasisDocumentSpecialOffers
	|		ON BasisDocumentSpecialOffers.Ref = tmpItemList.%1
	|		AND BasisDocumentSpecialOffers.Key = tmpItemList.BasisKey
	|		INNER JOIN Document.%1.ItemList AS BasisDocumentItemList
	|		ON BasisDocumentItemList.Ref = tmpItemList.%1
	|		AND BasisDocumentItemList.Key = tmpItemList.BasisKey";
	Query.Text = StrTemplate(Query.Text, BasisDocumentName);
	Query.SetParameter("ItemList", Object.ItemList.Unload());
	Query.SetParameter("RowIDInfo", Object.RowIDInfo.Unload());
	QueryResult = Query.Execute();
	Form.SpecialOffersCache.Load(QueryResult.Unload());
EndProcedure
#EndRegion

#Region CommonAttributes

Procedure AddCommonAttributesToForm(Object, Form)
	GroupOther = Form.Items.Find("GroupOther");
	If GroupOther <> Undefined Then
		AddCommonAttributesDimensions(Object, Form, GroupOther);
		AddCommonAttributesWeight(Object, Form, GroupOther);
	EndIf;
EndProcedure

Procedure AddCommonAttributesDimensions(Object, Form, ParentGroup)
	AddedAttributes = New Array();
	If ServiceSystemServer.ObjectHasAttribute(Metadata.CommonAttributes.Length.Name, Object) Then
		AddedAttributes.Add(Metadata.CommonAttributes.Length);
	EndIf;
	If ServiceSystemServer.ObjectHasAttribute(Metadata.CommonAttributes.Width.Name, Object) Then
		AddedAttributes.Add(Metadata.CommonAttributes.Width);
	EndIf;
	If ServiceSystemServer.ObjectHasAttribute(Metadata.CommonAttributes.Height.Name, Object) Then
		AddedAttributes.Add(Metadata.CommonAttributes.Height);
	EndIf;
	If ServiceSystemServer.ObjectHasAttribute(Metadata.CommonAttributes.Volume.Name, Object) Then
		AddedAttributes.Add(Metadata.CommonAttributes.Volume);
	EndIf;
	If Not AddedAttributes.Count() Then
		Return;
	EndIf;

	ItemsParent = Form.Items.Add("GroupDimensions", Type("FormGroup"), ParentGroup);
	ItemsParent.Type = FormGroupType.UsualGroup;
	ItemsParent.Group = ChildFormItemsGroup.Vertical;
	ItemsParent.Behavior = UsualGroupBehavior.Collapsible;
	ItemsParent.Title = R().Form_030;
	For Each Attribute In AddedAttributes Do
		NewAttribute = Form.Items.Add(Attribute.Name, Type("FormField"), ItemsParent);
		NewAttribute.Type = FormFieldType.InputField;
		NewAttribute.DataPath = "Object." + Attribute.Name;
	EndDo;
EndProcedure

Procedure AddCommonAttributesWeight(Object, Form, ParentGroup)
	AddedAttributes = New Array();
	If ServiceSystemServer.ObjectHasAttribute(Metadata.CommonAttributes.Weight.Name, Object) Then
		AddedAttributes.Add(Metadata.CommonAttributes.Weight);
	EndIf;
	If Not AddedAttributes.Count() Then
		Return;
	EndIf;

	ItemsParent = Form.Items.Add("GroupWeights", Type("FormGroup"), ParentGroup);
	ItemsParent.Type = FormGroupType.UsualGroup;
	ItemsParent.Group = ChildFormItemsGroup.Vertical;
	ItemsParent.Behavior = UsualGroupBehavior.Collapsible;
	ItemsParent.Title = R().Form_031;
	For Each Attribute In AddedAttributes Do
		NewAttribute = Form.Items.Add(Attribute.Name, Type("FormField"), ItemsParent);
		NewAttribute.Type = FormFieldType.InputField;
		NewAttribute.DataPath = "Object." + Attribute.Name;
	EndDo;
EndProcedure

#EndRegion

#Region Service

Procedure ShowUserMessageOnCreateAtServer(Form) Export
	If Form.Parameters.Property("InfoMessage") Then
		CommonFunctionsClientServer.ShowUsersMessage(Form.Parameters.InfoMessage);
	EndIf;
EndProcedure

Function SerializeArrayOfFilters(ArrayOfFilters) Export
	Return CommonFunctionsServer.SerializeXMLUseXDTO(ArrayOfFilters);
EndFunction

Procedure RecalculateQuantityInTable(Table, UnitQuantityName = "QuantityUnit") Export
	For Each Row In Table Do
		RecalculateQuantityInRow(Row, UnitQuantityName);
	EndDo;
EndProcedure

Procedure RecalculateQuantityInRow(Row, UnitQuantityName = "QuantityUnit") Export
	ItemKeyUnit = CatItemsServer.GetItemKeyUnit(Row.ItemKey);
	UnitFactorFrom = Catalogs.Units.GetUnitFactor(Row[UnitQuantityName], ItemKeyUnit);
	UnitFactorTo = Catalogs.Units.GetUnitFactor(Row.Unit, ItemKeyUnit);
	Row.Quantity = ?(UnitFactorTo = 0, 0, Row.Quantity * UnitFactorFrom / UnitFactorTo);
EndProcedure

#EndRegion

#Region Subscriptions

Procedure OnCopyDocumentProcessingOnCopy(Source, CopiedObject, AddInfo = Undefined) Export
	If Metadata.CommonAttributes.Author.Content.Contains(Source.Metadata()) Then
		FillingStructure = New Structure();
		FillingStructure.Insert("Author", SessionParameters.CurrentUser);

		FillPropertyValues(Source, FillingStructure);
	EndIf;
EndProcedure

#EndRegion

#Region ShipmentConfirationsGoodsReceiptd

Procedure RecalculateInvoiceQuantity(ArrayOfRows) Export
	For Each Row In ArrayOfRows Do
		Row.Unit = ?(ValueIsFilled(Row.ItemKey.Unit), Row.ItemKey.Unit, Row.ItemKey.Item.Unit);
		RecalculateQuantityInRow(Row);
	EndDo;
EndProcedure

#EndRegion

Function GetPartnerByLegalName(LegalName, Partner) Export
	If ValueIsFilled(LegalName) Then
		ArrayOfFilters = New Array();
		ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
		If ValueIsFilled(Partner) Then
			ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Ref", Partner, ComparisonType.Equal));
		EndIf;
		AdditionalParameters = New Structure();
		If ValueIsFilled(LegalName) Then
			AdditionalParameters.Insert("Company", LegalName);
			AdditionalParameters.Insert("FilterPartnersByCompanies", True);
		EndIf;
		Parameters = New Structure("CustomSearchFilter, AdditionalParameters", SerializeArrayOfFilters(ArrayOfFilters),
			SerializeArrayOfFilters(AdditionalParameters));
		Return Catalogs.Partners.GetDefaultChoiceRef(Parameters);
	EndIf;
	Return Undefined;
EndFunction

Function GetItemAndItemKeyByPartnerItem(PartnerItem) Export
	Result = New Structure("Item, ItemKey");
	If Not ValueIsFilled(PartnerItem) Then
		Return Result;
	EndIf;
	Result.Item = PartnerItem.Item;
	Result.ItemKey = PartnerItem.ItemKey;
	Return Result;
EndFunction

Function GetStoreInfo(Store, ItemKey) Export
	Result = New Structure();
	Result.Insert("IsService", True);
	If ValueIsFilled(ItemKey) Then
		Result.IsService = (ItemKey.Item.ItemType.Type = Enums.ItemTypes.Service);
	ENdIf;
	Result.Insert("UseGoodsReceipt", Store.UseGoodsReceipt);
	Result.Insert("UseShipmentConfirmation", Store.UseShipmentConfirmation);
	Return Result;
EndFunction

Function GetArrayOfPurchaseOrdersByPurchaseInvoice(PurchaseInvoice) Export
	Query = New Query();
	Query.Text = 
	"SELECT
	|	PurchaseInvoiceItemList.PurchaseOrder
	|FROM
	|	Document.PurchaseInvoice.ItemList AS PurchaseInvoiceItemList
	|WHERE
	|	PurchaseInvoiceItemList.Ref = &Ref
	|	AND NOT PurchaseInvoiceItemList.PurchaseOrder.Ref IS NULL";
	Query.SetParameter("Ref", PurchaseInvoice);
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	ArrayOfOrders = QueryTable.UnloadColumn("PurchaseOrder");
	Return ArrayOfOrders;
EndFunction

Function GetArrayOfSalesOrdersBySalesInvoice(SalesInvoice) Export
	Query = New Query();
	Query.Text = 
	"SELECT
	|	SalesInvoiceItemList.SalesOrder
	|FROM
	|	Document.SalesInvoice.ItemList AS SalesInvoiceItemList
	|WHERE
	|	SalesInvoiceItemList.Ref = &Ref
	|	AND NOT SalesInvoiceItemList.SalesOrder.Ref IS NULL";
	Query.SetParameter("Ref", SalesInvoice);
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	ArrayOfOrders = QueryTable.UnloadColumn("SalesOrder");
	Return ArrayOfOrders;
EndFunction

