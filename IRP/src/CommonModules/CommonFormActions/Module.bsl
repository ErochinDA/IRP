
Procedure EditMultilineText(Form, Item, StandardProcessing) Export
	StandardProcessing = False;
	OpenForm("CommonForm.EditMultilineText", New Structure("ItemName", Item.Name), Form, , , ,
		New NotifyDescription("OnEditedMultilineTextEnd", ThisObject, New Structure("Form, ItemName", Form, Item.Name)),
		FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

Procedure OnEditedMultilineTextEnd(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	If AdditionalParameters.Form.Object[AdditionalParameters.ItemName] <> Result Then
		AdditionalParameters.Form.Modified = True;
	EndIf;
	AdditionalParameters.Form.Object[AdditionalParameters.ItemName] = Result;
	DocumentsClient.SetTextOfDescriptionAtForm(AdditionalParameters.Form.Object, AdditionalParameters.Form);
EndProcedure

// Procedure wich add string In table, or add quantity to exist one
// 
// Parameters:
//  SettingsInfo - Structure:
//  	* RowData       - Structure  - wich add In table
//  	* Object        - DocumentObject, CatalogObject - any object, wich have table
// 		* Settings      - Structure
// 		* Name      - String	     - table name
// 		* Search    - Array of String		 - column name, for search row
// 		* AddNewRow - Boolean  - always And New row
//  AddInfo - Undefined - Add info
// 
// Returns:
//  ValueTableRow
Function AddRowAtObjectTable(SettingsInfo, AddInfo = Undefined) Export
	Table = SettingsInfo.Object[SettingsInfo.Settings.Name];

	FillPropertyValues(SettingsInfo.Settings.Search, SettingsInfo.RowData);

	SearchRow = Table.FindRows(SettingsInfo.Settings.Search);

	If SearchRow.Count() Then
		NewStr = SearchRow[0];
		SourceQuantity = NewStr.Quantity;
		FillPropertyValues(NewStr, SettingsInfo.RowData);
		If SettingsInfo.Settings.AddQuantity Then
			NewStr.Quantity = SourceQuantity + SettingsInfo.RowData.Quantity;
		Else
			NewStr.Quantity = SettingsInfo.RowData.Quantity;
		EndIf;
	Else
		NewStr = Table.Add();
		FillPropertyValues(NewStr, SettingsInfo.RowData);
	EndIf;

	If Not ValueIsFilled(NewStr.Key) Then
		NewStr.Key = New UUID();
	EndIf;

	Return NewStr;
EndFunction

Function SettingsAddRowAtObjectTable(AddInfo = Undefined) Export
	NewSettings = New Structure("RowData, Object, Settings, AddInfo", Undefined, Undefined, New Structure(), Undefined);
	NewSettings.Settings.Insert("Name", "");
	NewSettings.Settings.Insert("Search", New Structure());
	NewSettings.Settings.Insert("AddNewRow", False);
	NewSettings.Settings.Insert("DeleteEmpty", True);
	NewSettings.Settings.Insert("AddQuantity", True);
	NewSettings.Settings.Insert("Currency", Undefined);
	// Using for create info string In table 
	NewSettings.Settings.Insert("Formula", "");
	NewSettings.Settings.Insert("MainTableKey", New UUID());
	Return NewSettings;
EndFunction

Procedure DynamicListBeforeAddRow(Form, Item, Cancel, Clone, Parent, IsFolder, Parameter, NewObjectFormName) Export
	FillingValues = CommonFormActionsServer.RestoreFillingData(Form.FillingData);
	If TypeOf(FillingValues) = Type("Structure") Then
		Cancel = True;
		OpenForm(NewObjectFormName, New Structure("FillingValues", FillingValues));
	EndIf;
EndProcedure