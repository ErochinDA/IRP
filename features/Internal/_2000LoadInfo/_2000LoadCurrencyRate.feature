#language: ru
@tree
@Positive

Функционал: check loading currency from external resources

As a developer
I want to create a processing to download currency rates from external resources.
To upload currency rates to the base

Контекст:
	Дано Я запускаю сценарий открытия TestClient или подключаю уже существующий.


Сценарий: check load currency rate
	# Включая проверку загрузки только выбранных валют
	И я включаю асинхронный режим выполнения шагов с интервалом "1"
	* Filling in the setting for currency rate loading from Bank UA
		И я открываю навигационную ссылку "e1cib/list/Catalog.IntegrationSettings"
		И в таблице "List" я перехожу к строке:
			| Description |
			| Bank UA     |
		И в таблице "List" я выбираю текущую строку
		И я нажимаю на кнопку 'Settings'
		И я нажимаю кнопку выбора у поля "Currency from"
		И в таблице "List" я перехожу к строке:
			| Code | Description     |
			| UAH  | Ukraine Hryvnia |
		И в таблице "List" я выбираю текущую строку
		И я нажимаю на кнопку 'Ok'
		И я нажимаю на кнопку 'Save and close'
	* Open catalog currency
		И я открываю навигационную ссылку "e1cib/list/Catalog.Currencies"
	* Upload currency rate Forex Buying (from tcmb.gov.tr)
		И я нажимаю на кнопку 'Integrations'
		И в таблице "IntegrationTable" я перехожу к строке:
			| Integration settings |
			| Forex Buying         |
		И я нажимаю на кнопку 'Ok'
		И я нажимаю кнопку выбора у поля "Period"
		И я нажимаю на кнопку 'Clear period'
		И в поле "DateBegin" я ввожу начало текущего месяца
		И в поле "DateEnd" я ввожу текущую дату
		И я нажимаю на кнопку 'Select'
		И в таблице "Currencies" я перехожу к строке:
			| 'Code' |
			| 'USD'  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я перехожу к строке:
			| 'Code' |
			| 'EUR'  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я нажимаю на кнопку 'Download'
		И Пауза 40
		И Я закрываю текущее окно
	* Upload currency rate Forex Selling (from tcmb.gov.tr)
		И я нажимаю на кнопку 'Integrations'
		И в таблице "IntegrationTable" я перехожу к строке:
			| Integration settings |
			| Forex Seling         |
		И я нажимаю на кнопку 'Ok'
		И я нажимаю кнопку выбора у поля "Period"
		И я нажимаю на кнопку 'Clear period'
		И в поле "DateBegin" я ввожу начало текущего месяца
		И в поле "DateEnd" я ввожу текущую дату
		И я нажимаю на кнопку 'Select'
		И в таблице "Currencies" я перехожу к строке:
			| Code |
			| USD  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я нажимаю на кнопку 'Download'
		И Пауза 40
		И Я закрываю текущее окно
	* Upload currency rate Bank UA (from bank.gov.ua)
		И я нажимаю на кнопку 'Integrations'
		И в таблице "IntegrationTable" я перехожу к строке:
			| Integration settings |
			| Bank UA         |
		И я нажимаю на кнопку 'Ok'
		И я нажимаю кнопку выбора у поля "Period"
		И я нажимаю на кнопку 'Clear period'
		И в поле "DateBegin" я ввожу начало текущего месяца
		И в поле "DateEnd" я ввожу текущую дату
		И я нажимаю на кнопку 'Select'
		И в таблице "Currencies" я перехожу к строке:
			| 'Code' |
			| 'USD'  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я перехожу к строке:
			| 'Code' |
			| 'EUR'  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я перехожу к строке:
			| 'Code' |
			| 'TRY'  |
		И в таблице "Currencies" я устанавливаю флаг 'Download'
		И в таблице "Currencies" я завершаю редактирование строки
		И в таблице "Currencies" я нажимаю на кнопку 'Download'
		И Пауза 40
		И Я закрываю текущее окно
	* Check currency downloads
		И я открываю навигационную ссылку "e1cib/list/InformationRegister.CurrencyRates"
		Тогда таблица "List" содержит строки:
			| 'Currency from'  | 'Currency to'   | 'Source'        | 'Multiplicity' | 'Rate'  |
			# | 'TRY'            | 'USD'           | 'Forex Buying'  | '1'            | '*'     |
			# | 'TRY'            | 'EUR'           | 'Forex Buying'  | '1'            | '*'     |
			# | 'TRY'            | 'USD'           | 'Forex Selling' | '1'            | '*'     |
			| 'UAH'            | 'USD'           | 'Bank UA'       | '1'            | '*'     |
			| 'UAH'            | 'EUR'           | 'Bank UA'       | '1'            | '*'     |
			| 'UAH'            | 'TRY'           | 'Bank UA'       | '1'            | '*'     |
		И Я закрыл все окна клиентского приложения

