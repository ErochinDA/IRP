Procedure FillingWithDefaultDataFilling(Source, FillingData, FillingText, StandardProcessing, Force = False) Export
	If Force = Undefined Then
		Force = False;
	EndIf;

//===
IsUsedNewFunctionality = TypeOf(Source) = Type("DocumentObject.IncomingPaymentOrder")
	Or TypeOf(Source) = Type("DocumentObject.ShipmentConfirmation")
	Or TypeOf(Source) = Type("DocumentObject.GoodsReceipt")
	Or TypeOf(Source) = Type("DocumentObject.SalesInvoice");
//===

	Data = New Structure();

	Data.Insert("Author", SessionParameters.CurrentUser);
	FillPropertyValues(Source, Data);

	FilterParameters = New Structure();
	FilterParameters.Insert("MetadataObject", Source.Metadata());
	UserSettings = UserSettingsServer.GetUserSettings(SessionParameters.CurrentUser, FilterParameters);

	Data = New Structure();
	Data.Insert("ManagerSegment", SessionParameters.CurrentUserPartner);
	For Each Row In UserSettings Do
		If Row.KindOfAttribute = Enums.KindsOfAttributes.Regular 
			Or Row.KindOfAttribute = Enums.KindsOfAttributes.Common Then
			Data.Insert(Row.AttributeName, Row.Value);
		EndIf;
	EndDo;
	
	//==
	If IsUsedNewFunctionality Then
		ArrayOfAllMainTables = New Array();
		ArrayOfAllMainTables.Add("ItemList");
		ArrayOfAllMainTables.Add("PaymentList");
		ArrayOfAllMainTables.Add("Transactions");
		ArrayOfMainTables = New Array();
		For Each TableName In ArrayOfAllMainTables Do
			If CommonFunctionsClientServer.ObjectHasProperty(Source, TableName) Then
				ArrayOfMainTables.Add(TableName);
			EndIf;
		EndDo;
	
		ReadOnlyProperties = "";
		Source.AdditionalProperties.Property("ReadOnlyProperties", ReadOnlyProperties);
	
		// если документ был введен на основании то у него уже есть заполненные реквизиты
		// список этих реквизитов в ReadOnlyProperties
		// нужно для каждого уже заполненного реквизита вызвать его обработчик
	
		ArrayOfProperties = StrSplit(ReadOnlyProperties, ",");
	
		For Each TableName In ArrayOfMainTables Do
		
			For Each PropertyName In ArrayOfProperties Do
				If Not ValueIsFilled(PropertyName) Then
					Continue;
				EndIf;
				DataPath = StrSplit(PropertyName, ".");
				If DataPath.Count() = 1 Then // для табличных частей пока не реализовано
					Property = New Structure("DataPath", TrimAll(DataPath[0]));
				
					ServerParameters = ControllerClientServer_V2.GetServerParameters(Source);
					ServerParameters.TableName          = TableName;
					ServerParameters.ReadOnlyProperties = ReadOnlyProperties;
					Parameters = ControllerClientServer_V2.GetParameters(ServerParameters);
				
					ControllerClientServer_V2.API_SetProperty(Parameters, Property, Source[Property.DataPath]);
				EndIf;
			EndDo;
		
		EndDo;
	EndIf; // IsUsedNewFunctionality 
	//==
	
	For Each KeyValue In Data Do
		If CommonFunctionsClientServer.ObjectHasProperty(Source, KeyValue.Key) Then
			//==
			If IsUsedNewFunctionality Then
				// временно, потом перенести в модуль Controller
				
				// заполняем реквизиты из настроек пользователя,
				// но только не те что в ReadOnlyProperties
				Property = New Structure("DataPath", KeyValue.Key);
				Value    = KeyValue.Value;
				
				For Each TableName In ArrayOfMainTables Do
					ServerParameters = ControllerClientServer_V2.GetServerParameters(Source);
					ServerParameters.TableName          = TableName;
					ServerParameters.ReadOnlyProperties = ReadOnlyProperties;
					Parameters = ControllerClientServer_V2.GetParameters(ServerParameters);
					
					ControllerClientServer_V2.API_SetProperty(Parameters, Property, Value);
				EndDo;
			Else
			//==
				If TypeOf(Source[KeyValue.Key]) = Type("Boolean") And Not Source[KeyValue.Key] Then
					Source[KeyValue.Key] = KeyValue.Value;
				ElsIf Not ValueIsFilled(Source[KeyValue.Key]) Or Force Then
					Source[KeyValue.Key] = KeyValue.Value;
				EndIf;
			EndIf;
			//==
		EndIf;
	EndDo;

	Attributes = Source.Metadata().Attributes;
	
	StatusAttribute = Attributes.Find("Status");
	If StatusAttribute <> Undefined And StatusAttribute.Type = New TypeDescription("CatalogRef.ObjectStatuses")
		And Not ValueIsFilled(Source.Status) Then
		Source.Status = ObjectStatusesServer.GetStatusByDefault(Source.Ref);
	EndIf;
	
	//===
	If IsUsedNewFunctionality Then
		Return;
	EndIf;
	//===
	
	UseShipmentConfirmation = False;
	If Attributes.Find("StoreSender") <> Undefined And Attributes.Find("UseShipmentConfirmation") <> Undefined Then
		UseShipmentConfirmation = Source.StoreSender.UseShipmentConfirmation;
		Source.UseShipmentConfirmation = UseShipmentConfirmation;
	EndIf;

	If Attributes.Find("StoreReceiver") <> Undefined And Attributes.Find("UseGoodsReceipt") <> Undefined Then
		Source.UseGoodsReceipt = Source.StoreReceiver.UseGoodsReceipt Or UseShipmentConfirmation;
	EndIf;

	AgreementAttribute = Attributes.Find("Agreement");
	If AgreementAttribute <> Undefined And AgreementAttribute.Type = New TypeDescription("CatalogRef.Agreements") Then

		If Attributes.Find("Partner") <> Undefined 
			And ValueIsFilled(Source.Partner) 
			And ValueIsFilled(Source.Agreement) Then
				AgreementParameters = New Structure();
				AgreementParameters.Insert("Partner"        , Source.Partner);
				AgreementParameters.Insert("Agreement"      , Source.Agreement);
				AgreementParameters.Insert("CurrentDate"    , CurrentDate());
				AgreementParameters.Insert("ArrayOfFilters" , New Array());
				AgreementParameters.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark",
					True, ComparisonType.NotEqual));
				AgreementParameters.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Kind",
					PredefinedValue("Enum.AgreementKinds.Standard"), ComparisonType.NotEqual));
				Source.Agreement = DocumentsServer.GetAgreementByPartner(AgreementParameters);
		EndIf;

	EndIf;

EndProcedure

Procedure ClearDocumentBasisesOnCopy(Source, CopiedObject) Export
	SourceMetadata = Source.Metadata();
	For Each AttributeMetadata In SourceMetadata.Attributes Do
		If CommonFunctionsServer.IsDocumentRef(Source[AttributeMetadata.Name]) Then
			Source[AttributeMetadata.Name] = Undefined;
		EndIf;
	EndDo;
	For Each TabularSectionMetadata In SourceMetadata.TabularSections Do
		For Each AttributeMetadata In TabularSectionMetadata.Attributes Do
			For Each Row In Source[TabularSectionMetadata.Name] Do
				If CommonFunctionsServer.IsDocumentRef(Row[AttributeMetadata.Name]) Then
					Row[AttributeMetadata.Name] = Undefined;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// Clear link to other rows
	If CommonFunctionsClientServer.ObjectHasProperty(Source, "RowIDInfo") Then
		Source.RowIDInfo.Clear();
	EndIf;
	
	// Clear link to other documents
	If CommonFunctionsClientServer.ObjectHasProperty(Source, "ShipmentConfirmations") Then
		Source.ShipmentConfirmations.Clear();
	EndIf;

	If CommonFunctionsClientServer.ObjectHasProperty(Source, "GoodsReceipts") Then
		Source.GoodsReceipts.Clear();
	EndIf;
	
	// Update key in tabular sections
	If CommonFunctionsClientServer.ObjectHasProperty(Source, "ItemList") Then
		LinkedTables = New Array();
		For Each TabularSectionMetadata In SourceMetadata.TabularSections Do
			If Upper(TabularSectionMetadata.Name) = Upper("ItemList") Then
				Continue;
			EndIf;
			If TabularSectionMetadata.Attributes.Find("Key") <> Undefined Then
				LinkedTables.Add(Source[TabularSectionMetadata.Name]);
			EndIf;
		EndDo;
		DocumentsServer.SetNewTableUUID(Source.ItemList, LinkedTables);
	EndIf;
EndProcedure