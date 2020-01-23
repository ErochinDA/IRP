#Region FormEvents

Procedure OnOpen(Object, Form, Cancel, AddInfo = Undefined) Export
	DocumentsClient.SetTextOfDescriptionAtForm(Object, Form);
	If Not ValueIsFilled(Object.Ref) Then
		CheckFillData(Object, Form);
	EndIf;
	SetVisibilityAvailability(Object, Form);
EndProcedure

#EndRegion

#Region ItemCompany

Procedure CompanyOnChange(Object, Form, Item) Export
	RefillData = New Structure;		
	If ValueIsFilled(Object.Sender) Then
		TransferParameters = New Structure("Company", Object.Company);
		CustomParameters = CatCashAccountsClient.DefaultCustomParameters(TransferParameters);
		CustomParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Ref",
																			Object.Sender,
																			ComparisonType.Equal,
																			DataCompositionComparisonType.Equal));
		GetDefaultChoiseRef = CatCashAccountsServer.GetDefaultChoiseRef(CustomParameters);
		If Object.Sender <> GetDefaultChoiseRef Then
			RefillData.Insert("Sender", PredefinedValue("Catalog.CashAccounts.EmptyRef"));
		EndIf;
	EndIf;
	If ValueIsFilled(Object.Receiver) Then
		TransferParameters = New Structure("Company", Object.Company);
		CustomParameters = CatCashAccountsClient.DefaultCustomParameters(TransferParameters);
		CustomParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Ref",
																			Object.Receiver,
																			ComparisonType.Equal,
																			DataCompositionComparisonType.Equal));
		GetDefaultChoiseRef = CatCashAccountsServer.GetDefaultChoiseRef(CustomParameters);
		If Object.Receiver <> GetDefaultChoiseRef Then
			RefillData.Insert("Receiver", PredefinedValue("Catalog.CashAccounts.EmptyRef"));
		EndIf;
	EndIf;		
	If RefillData.Count() Then
		NotifyParameters = New Structure;
		NotifyParameters.Insert("Form", Form);
		NotifyParameters.Insert("Object", Object);
		NotifyParameters.Insert("RefillData", RefillData);
		Notify = New NotifyDescription("CompanyOnChangeEnd", ThisObject, NotifyParameters);
		QueryText = R().QuestionToUser_015;
		QueryButtons = QuestionDialogMode.OKCancel;
		ShowQueryBox(Notify, QueryText, QueryButtons);
	Else
		DocumentsClientServer.ChangeTitleGroupTitle(Object, Form);
	EndIf;
EndProcedure

Procedure CompanyOnChangeEnd(Result, AdditionalParameters) Export
	Object = AdditionalParameters.Object;
	Form = AdditionalParameters.Form;
	RefillData = AdditionalParameters.RefillData;
	If Result = DialogReturnCode.OK Then
		CommonFunctionsClientServer.SetObjectPreviousValue(Object, Form, "Company");
		For Each RefillDataItem In RefillData Do
			Object[RefillDataItem.Key] = RefillDataItem.Value;
		EndDo;
		DocumentsClientServer.ChangeTitleGroupTitle(Object, Form);
	Else
		Object.Company = CommonFunctionsClientServer.GetObjectPreviousValue(Object, Form, "Company");	
	EndIf;	
EndProcedure

Procedure CompanyStartChoice(Object, Form, Item, ChoiceData, StandardProcessing) Export
	OpenSettings = DocumentsClient.GetOpenSettingsStructure();
	
	OpenSettings.ArrayOfFilters = New Array();
	OpenSettings.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", 
																		False, DataCompositionComparisonType.Equal));
	OpenSettings.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Our", 
																		True, DataCompositionComparisonType.Equal));
	OpenSettings.FillingData = New Structure("Our", True);
	
	DocumentsClient.CompanyStartChoice(Object, Form, Item, ChoiceData, StandardProcessing, OpenSettings);
EndProcedure

Procedure CompanyEditTextChange(Object, Form, Item, Text, StandardProcessing) Export
	ArrayOfFilters = New Array();
	ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
	ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Our", True, ComparisonType.Equal));
	DocumentsClient.CompanyEditTextChange(Object, Form, Item, Text, StandardProcessing, ArrayOfFilters);
EndProcedure

#EndRegion


#Region ItemDate

Procedure DateOnChange(Object, Form, Item) Export
	DocumentsClientServer.ChangeTitleGroupTitle(Object, Form);
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
	FillSendDate(Object, Form);
	FillReceiveDate(Object, Form);
EndProcedure

#EndRegion


#Region ItemDescription

Procedure DescriptionClick(Object, Form, Item, StandardProcessing) Export
	StandardProcessing = False;
	CommonFormActions.EditMultilineText(Item.Name, Form);
EndProcedure

#EndRegion

#Region GroupTitleDecorationsEvents

Procedure DecorationGroupTitleCollapsedPictureClick(Object, Form, Item) Export
	DocumentsClientServer.ChangeTitleCollapse(Object, Form, True);
EndProcedure

Procedure DecorationGroupTitleCollapsedLalelClick(Object, Form, Item) Export
	DocumentsClientServer.ChangeTitleCollapse(Object, Form, True);
EndProcedure

Procedure DecorationGroupTitleUncollapsedPictureClick(Object, Form, Item) Export
	DocumentsClientServer.ChangeTitleCollapse(Object, Form, False);
EndProcedure

Procedure DecorationGroupTitleUncollapsedLalelClick(Object, Form, Item) Export
	DocumentsClientServer.ChangeTitleCollapse(Object, Form, False);
EndProcedure

#EndRegion


#Region ItemSendDate

Procedure SendDateOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
EndProcedure

Procedure FillSendDate(Object, Form)
	If Not CommonFunctionsClientServer.IsFormItemModifiedByUser(Form, "SendDate") Then
		Object.SendDate = Object.Date;		
	EndIf;
EndProcedure

#EndRegion


#Region ItemReceiveDate

Procedure ReceiveDateOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
EndProcedure

Procedure FillReceiveDate(Object, Form)
	If Not CommonFunctionsClientServer.IsFormItemModifiedByUser(Form, "ReceiveDate") Then
		Object.ReceiveDate = Object.Date;		
	EndIf;
EndProcedure

#EndRegion


#Region ItemReceiveAmount

Procedure ReceiveAmountOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
EndProcedure

#EndRegion


#Region ItemSendAmount

Procedure SendAmountOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
	If Not CommonFunctionsClientServer.IsFormItemModifiedByUser(Form, "ReceiveAmount")
		And ValueIsFilled(Object.SendCurrency) = ValueIsFilled(Object.ReceiveCurrency)
		And Object.SendCurrency = Object.ReceiveCurrency Then
		Object.ReceiveAmount = Object.SendAmount;
	EndIf;  
EndProcedure

#EndRegion


#Region ItemSender

Procedure SenderEditTextChange(Object, Form, Item, Text, StandardProcessing) Export
	DefaultEditTextParameters = New Structure("Company", Object.Company);
	EditTextParameters = CatCashAccountsClient.GetDefaultEditTextParameters(DefaultEditTextParameters);
	EditTextParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Type",
																		PredefinedValue("Enum.CashAccountTypes.Transit"),
																		ComparisonType.NotEqual));
	Item.ChoiceParameters = CatCashAccountsClient.FixedArrayOfChoiceParameters(EditTextParameters);
EndProcedure

Procedure SenderOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
	FillSenderCurrency(Object, Form);
	SetVisibilityAvailability(Object, Form);
EndProcedure

Procedure SenderStartChoice(Object, Form, Item, ChoiceData, StandardProcessing) Export
	StandardProcessing = False;
	DefaultStartChoiceParameters = New Structure("Company", Object.Company);
	StartChoiceParameters = CatCashAccountsClient.GetDefaultStartChoiceParameters(DefaultStartChoiceParameters);
	StartChoiceParameters.CustomParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Type",
																		PredefinedValue("Enum.CashAccountTypes.Transit"),
																		,
																		DataCompositionComparisonType.NotEqual));
	OpenForm(StartChoiceParameters.FormName, StartChoiceParameters, Item, Form.UUID, , Form.URL);	
EndProcedure

#EndRegion

#Region CashAdvanceHolder
Procedure CashAdvanceHolderStartChoice(Object, Form, Item, ChoiceData, StandardProcessing) Export
	OpenSettings = DocumentsClient.GetOpenSettingsStructure();
	
	OpenSettings.ArrayOfFilters = New Array();
	OpenSettings.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", 
																		True, DataCompositionComparisonType.NotEqual));
	OpenSettings.ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Employee", 
																		True, DataCompositionComparisonType.Equal));
	OpenSettings.FormParameters = New Structure();
	OpenSettings.FillingData = New Structure("Customer", True);
	
	DocumentsClient.PartnerStartChoice(Object, Form, Item, ChoiceData, StandardProcessing, OpenSettings);
EndProcedure

Procedure CashAdvanceHolderTextChange(Object, Form, Item, Text, StandardProcessing) Export
	ArrayOfFilters = New Array();
	ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
	ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Employee", True, ComparisonType.Equal));
	AdditionalParameters = New Structure();
	DocumentsClient.PartnerEditTextChange(Object, Form, Item, Text, StandardProcessing,
		ArrayOfFilters, AdditionalParameters);
EndProcedure
#EndRegion

#Region ItemReceiver

Procedure ReceiverEditTextChange(Object, Form, Item, Text, StandardProcessing) Export
	DefaultEditTextParameters = New Structure("Company", Object.Company);
	EditTextParameters = CatCashAccountsClient.GetDefaultEditTextParameters(DefaultEditTextParameters);
	EditTextParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Type",
																		PredefinedValue("Enum.CashAccountTypes.Transit"),
																		ComparisonType.NotEqual));
	Item.ChoiceParameters = CatCashAccountsClient.FixedArrayOfChoiceParameters(EditTextParameters);
EndProcedure

Procedure ReceiverOnChange(Object, Form, Item) Export
	CommonFunctionsClientServer.SetFormItemModifiedByUser(Form, Item.Name);
	FillReceiverCurrency(Object, Form);
	SetVisibilityAvailability(Object, Form);
EndProcedure

Procedure SetVisibilityAvailability(Object, Form) Export
	
	Settings = New Structure("Sender, Receiver, SendCurrency, ReceiveCurrency");
	FillPropertyValues(Settings, Object);
	
	If DocCashTransferOrderServer.CashAdvanceHolderVisibility(Settings) Then
		Form.Items.CashAdvanceHolder.Visible = True;
	Else
		Form.Items.CashAdvanceHolder.Visible = False;
		Object.CashAdvanceHolder = PredefinedValue("Catalog.Partners.EmptyRef");
	EndIf;
EndProcedure	

Procedure ReceiverStartChoice(Object, Form, Item, ChoiceData, StandardProcessing) Export
	StandardProcessing = False;
	DefaultStartChoiceParameters = New Structure("Company", Object.Company);
	StartChoiceParameters = CatCashAccountsClient.GetDefaultStartChoiceParameters(DefaultStartChoiceParameters);
	StartChoiceParameters.CustomParameters.Filters.Add(DocumentsClientServer.CreateFilterItem("Type",
																		PredefinedValue("Enum.CashAccountTypes.Transit"),
																		,
																		DataCompositionComparisonType.NotEqual));
	OpenForm(StartChoiceParameters.FormName, StartChoiceParameters, Item, Form.UUID, , Form.URL);
EndProcedure

#EndRegion


#Region ItemSenderCurrency

Procedure FillSenderCurrency(Object, Form)
	ObjectSenderCurrency = ServiceSystemServer.GetObjectAttribute(Object.Sender, "Currency"); 
	If ValueIsFilled(ObjectSenderCurrency) Then
		Object.SendCurrency = ObjectSenderCurrency;
	EndIf;
	Form.Items.SendCurrency.ReadOnly = ValueIsFilled(ObjectSenderCurrency);
EndProcedure

#EndRegion


#Region ItemReceiverCurrency

Procedure FillReceiverCurrency(Object, Form)
	ObjectReceiverCurrency = ServiceSystemServer.GetObjectAttribute(Object.Receiver, "Currency"); 
	If ValueIsFilled(ObjectReceiverCurrency) Then
		Object.ReceiveCurrency = ObjectReceiverCurrency;
	EndIf;
	Form.Items.ReceiveCurrency.ReadOnly = ValueIsFilled(ObjectReceiverCurrency);
EndProcedure

#EndRegion


#Region CheckFillData

Procedure CheckFillData(Object, Form)
	FillSendDate(Object, Form);
	FillReceiveDate(Object, Form);
	FillSenderCurrency(Object, Form);
	FillReceiverCurrency(Object, Form);
EndProcedure

#EndRegion