

#Region FormEvents

Procedure OnCreateAtServer(Object, Form, Cancel, StandardProcessing) Export
	DocumentsClientServer.ChangeTitleCollapse(Object, Form, Not ValueIsFilled(Object.Ref));
	If Form.Parameters.Key.IsEmpty() Then
		Form.CurrentCurrency = Object.Currency;
		Form.CurrentAccount = Object.CashAccount;
		Form.CurrentTransactionType = Object.TransactionType;
		
		SetGroupItemsList(Object, Form);
		DocumentsClientServer.ChangeTitleGroupTitle(Object, Form);
	EndIf;
	DocumentsServer.FillPaymentList(Object);
EndProcedure

Procedure AfterWriteAtServer(Object, Form, CurrentObject, WriteParameters) Export
	Form.CurrentCurrency = CurrentObject.Currency;
	Form.CurrentAccount = CurrentObject.CashAccount;
	Form.CurrentTransactionType = Object.TransactionType;
	
	DocumentsServer.FillPaymentList(Object);
	DocumentsClientServer.ChangeTitleGroupTitle(CurrentObject, Form);
EndProcedure

Procedure OnReadAtServer(Object, Form, CurrentObject) Export
	Form.CurrentCurrency = CurrentObject.Currency;
	Form.CurrentAccount = CurrentObject.CashAccount;
	Form.CurrentTransactionType = Object.TransactionType;
	
	DocumentsServer.FillPaymentList(Object);
	
	If Not Form.GroupItems.Count() Then
		SetGroupItemsList(Object, Form);
	EndIf;
	DocumentsClientServer.ChangeTitleGroupTitle(CurrentObject, Form);
EndProcedure

Procedure FillAttributesByType(TransactionType, ArrayAll, ArrayByType) Export
	Documents.CashReceipt.FillAttributesByType(TransactionType, ArrayAll, ArrayByType);
EndProcedure

#EndRegion

Function GetLegalNameByPartner(Partner, LegalName) Export
	If Not Partner.IsEmpty() Then
		ArrayOfFilters = New Array();
		ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("DeletionMark", True, ComparisonType.NotEqual));
		If ValueIsFilled(LegalName) Then
			ArrayOfFilters.Add(DocumentsClientServer.CreateFilterItem("Ref", LegalName, ComparisonType.Equal));
		EndIf;
		AdditionalParameters = New Structure();
		If ValueIsFilled(Partner) Then
			AdditionalParameters.Insert("Partner", Partner);
			AdditionalParameters.Insert("FilterByPartnerHierarchy", True);
		EndIf;
		Parameters = New Structure("CustomSearchFilter, AdditionalParameters",
				DocumentsServer.SerializeArrayOfFilters(ArrayOfFilters),
				DocumentsServer.SerializeArrayOfFilters(AdditionalParameters));
		Return Catalogs.Companies.GetDefaultChoiseRef(Parameters);
	EndIf;
	Return Undefined;
EndFunction

Function GetPartnerByLegalName(LegalName, Partner) Export
	If Not LegalName.IsEmpty() Then
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
		Parameters = New Structure("CustomSearchFilter, AdditionalParameters",
				DocumentsServer.SerializeArrayOfFilters(ArrayOfFilters),
				DocumentsServer.SerializeArrayOfFilters(AdditionalParameters));
		Return Catalogs.Partners.GetDefaultChoiseRef(Parameters);
	EndIf;
	Return Undefined;
EndFunction

#Region GroupTitle

Procedure SetGroupItemsList(Object, Form)
	AttributesArray = New Array;
	AttributesArray.Add("Company");
	AttributesArray.Add("CashAccount");
	AttributesArray.Add("Currency");
	AttributesArray.Add("TransactionType");
	DocumentsServer.DeleteUnavailableTitleItemNames(AttributesArray);
	For Each Atr In AttributesArray Do
		Form.GroupItems.Add(Atr, ?(ValueIsFilled(Form.Items[Atr].Title),
				Form.Items[Atr].Title,
				Object.Ref.Metadata().Attributes[Atr].Synonym + ":" + Chars.NBSp));
	EndDo;
EndProcedure

#EndRegion

Function GetDocumentTable_CashTransferOrder(ArrayOfBasisDocuments) Export
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	""CashTransferOrder"" AS BasedOn,
	|	CASE
	|		WHEN Doc.SendCurrency = Doc.ReceiveCurrency
	|			THEN VALUE(Enum.IncomingPaymentTransactionType.CashTransferOrder)
	|		ELSE VALUE(Enum.IncomingPaymentTransactionType.CurrencyExchange)
	|	END AS TransactionType,
	|	PlaningCashTransactionsTurnovers.Company AS Company,
	|	PlaningCashTransactionsTurnovers.Account AS CashAccount,
	|	PlaningCashTransactionsTurnovers.Currency AS Currency,
	|	Doc.SendCurrency AS CurrencyExchange,
	|	PlaningCashTransactionsTurnovers.AmountTurnover AS Amount,
	|	PlaningCashTransactionsTurnovers.BasisDocument AS PlaningTransactionBasis,
	|	CashAdvanceBalance.Partner AS Partner,
	|	CashAdvanceBalance.AmountBalance AS AmountExchange
	|INTO tmp
	|FROM
	|	AccumulationRegister.PlaningCashTransactions.Turnovers(,,,
	|		CashFlowDirection = VALUE(Enum.CashFlowDirections.Incoming)
	|	AND CurrencyMovementType = VALUE(ChartOfCharacteristicTypes.CurrencyMovementType.SettlementCurrency)
	|	AND BasisDocument IN (&ArrayOfBasisDocuments)) AS PlaningCashTransactionsTurnovers
	|		INNER JOIN Document.CashTransferOrder AS Doc
	|		ON PlaningCashTransactionsTurnovers.BasisDocument = Doc.Ref
	|		INNER JOIN AccumulationRegister.CashAdvance.Balance(,
	|			CurrencyMovementType = VALUE(ChartOfCharacteristicTypes.CurrencyMovementType.SettlementCurrency)
	|		AND BasisDocument IN (&ArrayOfBasisDocuments)) AS CashAdvanceBalance
	|		ON PlaningCashTransactionsTurnovers.BasisDocument = CashAdvanceBalance.BasisDocument
	|WHERE
	|	PlaningCashTransactionsTurnovers.Account.Type = VALUE(Enum.CashAccountTypes.Cash)
	|	AND PlaningCashTransactionsTurnovers.AmountTurnover > 0
	|
	|UNION ALL
	|
	|SELECT
	|	""CashTransferOrder"",
	|	CASE
	|		WHEN Doc.SendCurrency = Doc.ReceiveCurrency
	|			THEN VALUE(Enum.IncomingPaymentTransactionType.CashTransferOrder)
	|		ELSE VALUE(Enum.IncomingPaymentTransactionType.CurrencyExchange)
	|	END,
	|	PlaningCashTransactionsTurnovers.Company,
	|	PlaningCashTransactionsTurnovers.Account,
	|	PlaningCashTransactionsTurnovers.Currency,
	|	Doc.SendCurrency,
	|	PlaningCashTransactionsTurnovers.AmountTurnover,
	|	PlaningCashTransactionsTurnovers.BasisDocument,
	|	NULL,
	|	0
	|FROM
	|	AccumulationRegister.PlaningCashTransactions.Turnovers(,,,
	|		CashFlowDirection = VALUE(Enum.CashFlowDirections.Incoming)
	|	AND CurrencyMovementType = VALUE(ChartOfCharacteristicTypes.CurrencyMovementType.SettlementCurrency)
	|	AND BasisDocument IN (&ArrayOfBasisDocuments)) AS PlaningCashTransactionsTurnovers
	|		INNER JOIN Document.CashTransferOrder AS Doc
	|		ON PlaningCashTransactionsTurnovers.BasisDocument = Doc.Ref
	|WHERE
	|	PlaningCashTransactionsTurnovers.Account.Type = VALUE(Enum.CashAccountTypes.Cash)
	|	AND PlaningCashTransactionsTurnovers.AmountTurnover > 0
	|	AND Doc.SendCurrency = Doc.ReceiveCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tmp.BasedOn AS BasedOn,
	|	tmp.TransactionType AS TransactionType,
	|	tmp.Company AS Company,
	|	tmp.CashAccount AS CashAccount,
	|	tmp.Currency AS Currency,
	|	tmp.CurrencyExchange AS CurrencyExchange,
	|	tmp.Amount AS Amount,
	|	tmp.PlaningTransactionBasis AS PlaningTransactionBasis,
	|	tmp.Partner AS Partner,
	|	tmp.AmountExchange AS AmountExchange
	|FROM
	|	tmp AS tmp";

	Query.SetParameter("ArrayOfBasisDocuments", ArrayOfBasisDocuments);
	QueryResult = Query.Execute();
	Return QueryResult.Unload();
EndFunction

Function GetDocumentTable_CashTransferOrder_ForClient(ArrayOfBasisDocuments) Export
	ArrayOfResults = New Array();
	ValueTable = GetDocumentTable_CashTransferOrder(ArrayOfBasisDocuments);
	For Each Row In ValueTable Do
		NewRow = New Structure();
		NewRow.Insert("BasedOn", Row.BasedOn);
		NewRow.Insert("TransactionType", Row.TransactionType);
		NewRow.Insert("Company", Row.Company);
		NewRow.Insert("CashAccount", Row.CashAccount);
		NewRow.Insert("Currency", Row.Currency);
		NewRow.Insert("CurrencyExchange", Row.CurrencyExchange);
		NewRow.Insert("Amount", Row.Amount);
		NewRow.Insert("PlaningTransactionBasis", Row.PlaningTransactionBasis);
		NewRow.Insert("Partner", Row.Partner);
		NewRow.Insert("AmountExchange", Row.AmountExchange);
		ArrayOfResults.Add(NewRow);
	EndDo;
	Return ArrayOfResults;
EndFunction

