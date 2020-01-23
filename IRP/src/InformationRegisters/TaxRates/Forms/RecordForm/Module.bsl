&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If ValueIsFilled(Record.ItemKey) Then
		ThisObject.RecordType = "ItemKey";
	ElsIf ValueIsFilled(Record.Item) Then
		ThisObject.RecordType = "Item";
	ElsIf ValueIsFilled(Record.ItemType) Then
		ThisObject.RecordType = "ItemType";
	ElsIf ValueIsFilled(Record.Agreement) Then
		ThisObject.RecordType = "Agreement";
	Else
		ThisObject.RecordType = "All";
	EndIf;
	SetVisible();
	FillTaxRateChoiceList();
EndProcedure

&AtClient
Procedure RecordTypeOnChange(Item)
	SetVisible();
EndProcedure

&AtServer
Procedure FillTaxRateChoiceList()
	ThisObject.Items.TaxRate.ChoiceList.LoadValues(TaxesServer.GetTaxRatesByTax(Record.Tax));
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If ThisObject.RecordType <> "ItemType" Then
		CurrentObject.ItemType = Undefined;
	EndIf;
	
	If ThisObject.RecordType <> "Item" Then
		CurrentObject.Item = Undefined;
	EndIf;
	
	If ThisObject.RecordType <> "ItemKey" Then
		CurrentObject.ItemKey = Undefined;
	EndIf;
	
	If ThisObject.RecordType <> "Agreement" Then
		CurrentObject.Agreement = Undefined;
	EndIf;
EndProcedure

&AtServer
Procedure SetVisible()
	Items.ItemType.Visible = ThisObject.RecordType = "ItemType";
	Items.Item.Visible = ThisObject.RecordType = "Item";
	Items.ItemKey.Visible = ThisObject.RecordType = "ItemKey";
	Items.Agreement.Visible = ThisObject.RecordType = "Agreement";
EndProcedure

&AtClient
Procedure TaxRateStartListChoice(Item, StandardProcessing)
	FillTaxRateChoiceList();
EndProcedure

&AtClient
Procedure TaxOnChange(Item)
	FillTaxRateChoiceList();
EndProcedure

