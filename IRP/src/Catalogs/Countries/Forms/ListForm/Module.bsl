&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.List.QueryText = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(ThisObject.List.QueryText);
	FillingFromClassifiers.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
EndProcedure

&AtClient
Procedure CreateFromClassifier(Command)
	FormParameters = New Structure("MetadataName", "Catalogs.Countries");
	OpenForm("CommonForm.DataClassifier", 
				FormParameters, 
				ThisObject, , , , ,
				FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

