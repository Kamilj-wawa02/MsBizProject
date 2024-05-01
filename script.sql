/*
 * Projekt na przedmiot: Wykorzystanie MS SQL i pakietow MS Business Intelligence do budowy aplikacji
 * Kamil Jablkowski
 * 05.2024
 */

/* tworzenie bazy danych jesli nie istnieje */
IF NOT EXISTS (SELECT 1 FROM master..sysdatabases d WHERE d.[name] = 'msbizproj')
BEGIN
	EXEC sp_sqlexec N'CREATE DATABASE msbizproj'
END

USE msbizproj
go

/* tworzenie pustej procedury o nazwie zawartej jako argument */
IF NOT EXISTS ( SELECT 1 FROM sysobjects o WHERE (o.name = 'create_empty_proc') AND (OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1) )
BEGIN
	DECLARE @sql nvarchar(500)
	SET @sql = 'CREATE PROCEDURE dbo.create_empty_proc AS '
	EXEC sp_sqlexec @sql
END
GO
ALTER PROCEDURE dbo.create_empty_proc (@proc_name nvarchar(100))
AS
	IF NOT EXISTS ( SELECT 1 FROM sysobjects o WHERE (o.name = @proc_name) AND (OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1) )
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE PROCEDURE dbo.' + @proc_name + N' AS '
		EXEC sp_sqlexec @sql
	END
GO

/* procedura do usuwania tabel */
EXEC dbo.create_empty_proc @proc_name = 'clear_table'
GO
ALTER PROCEDURE dbo.clear_table (@tab_name nvarchar(100)) AS
	IF EXISTS ( SELECT 1 FROM sysobjects o WHERE (o.[name] = @tab_name) AND (OBJECTPROPERTY(o.[ID], N'IsUserTable') = 1) )
	BEGIN
		DECLARE @sql nvarchar(1000)
		SET @sql = 'DROP TABLE ' + @tab_name
		EXEC sp_sqlexec @sql
	END
GO

/* tworzenie tabel tymczasowych */
-- SELECT * FROM tmp_books_data
-- DROP TABLE tmp_books_data
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'tmp_books_data' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1) )
BEGIN
	CREATE TABLE dbo.tmp_books_data
	(
		book_id         nvarchar(50)    NOT NULL CHECK (LEN(book_id) > 0),
		title           nvarchar(100)   NOT NULL CHECK (LEN(title) > 0),
		author          nvarchar(100)   NOT NULL CHECK (LEN(author) > 0),
		genre           nvarchar(100)   NOT NULL,
		descr           nvarchar(100)   NOT NULL,
		country         nvarchar(50)    NOT NULL CHECK (LEN(country) > 0),
		netto_value     nvarchar(50)    NOT NULL CHECK (LEN(netto_value) > 0),
		vat             nvarchar(50)    NOT NULL CHECK (LEN(vat) > 0),
		brutto_value    nvarchar(50)    NOT NULL CHECK (LEN(brutto_value) > 0)
	)
END
GO

-- SELECT * FROM tmp_sales_data
-- DROP TABLE tmp_sales_data
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'tmp_sales_data' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1) )
BEGIN
	CREATE TABLE dbo.tmp_sales_data
	(
		sales_id        nvarchar(50)    NOT NULL CHECK (LEN(sales_id) > 0),
		sale_date       nchar(10)       NOT NULL CHECK (LEN(sale_date) > 0),
		client_name     nvarchar(50)    NOT NULL CHECK (LEN(client_name) > 0),
		client_nip      nvarchar(20)    NOT NULL CHECK (LEN(client_nip) > 0),
		book_id         nvarchar(50)    NOT NULL CHECK (LEN(book_id) > 0),
		quantity_sold   nvarchar(50)    NOT NULL CHECK (LEN(quantity_sold) > 0),
		unit_price      nvarchar(50)    NOT NULL CHECK (LEN(unit_price) > 0),
		netto_value     nvarchar(50)    NOT NULL CHECK (LEN(netto_value) > 0),
		brutto_value    nvarchar(50)    NOT NULL CHECK (LEN(brutto_value) > 0)
	)
END
GO

--DELETE FROM tmp_sales_data
--DELETE FROM tmp_books_data
--GO

/* tabele do bledow */
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ERROR_LOGS' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1) )
BEGIN
	CREATE TABLE dbo.ERROR_LOGS
	(
		error_log_id		int NOT NULL IDENTITY CONSTRAINT error_log_id_pk PRIMARY KEY,
		error_description	nvarchar(200) NOT NULL,
		error_date			datetime NOT NULL DEFAULT GETDATE(),
		username			nvarchar(40) NOT NULL DEFAULT USER_NAME(),
		hostname			nvarchar(100) NOT NULL DEFAULT HOST_NAME()
	) 
END
GO
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ERROR_LOGS_DETAILS' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1) )
BEGIN
	CREATE TABLE dbo.ERROR_LOGS_DETAILS
	(
		error_log_id		int NOT NULL CONSTRAINT error_log_id_fk FOREIGN KEY REFERENCES ERROR_LOGS(error_log_id),
		error_description	nvarchar(200) NOT NULL
	)
END
GO

/*
 * WALIDACJA
 */

/* procedura do walidacji danych w tmp_books_data */
EXEC dbo.create_empty_proc @proc_name = 'tmp_books_data_check'
GO
ALTER PROCEDURE dbo.tmp_books_data_check(@error int = 0 output)
AS
	DECLARE @count int, @error_notification nvarchar(100), @error_id int
	SET @error = 0
	SET @error_notification = 'Blad przy sprawdzaniu danych w tmp_books_data: '

	SELECT @count = COUNT(*) FROM tmp_books_data
	IF @count = 0
	BEGIN
		SET @error_notification = @error_notification + 'plik jest pusty'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description) VALUES (@error_id, 'Brak wierszy w tmp_books_data')

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	SELECT @count = COUNT(*) FROM tmp_books_data WHERE book_id IN (SELECT book_id FROM tmp_books_data GROUP BY book_id HAVING COUNT(*) > 1)
	IF @count > 1
	BEGIN
		SET @error_notification = @error_notification + 'plik nie moze zawierac powtarzajacych sie book_id'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()

		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.book_id FROM tmp_books_data t WHERE book_id IN (SELECT book_id FROM tmp_books_data GROUP BY book_id HAVING COUNT(*) > 1)

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	SELECT @count = COUNT(*) FROM tmp_books_data WHERE book_id < 0
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'plik nie moze zawierac book_id mniejszych od 0'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.book_id FROM tmp_books_data t WHERE book_id < 0

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END
GO

/* procedura do walidacji danych w tmp_sales_data */
EXEC dbo.create_empty_proc @proc_name = 'tmp_sales_data_check'
GO
ALTER PROCEDURE dbo.tmp_sales_data_check(@error int = 0 output)
AS
	EXEC dbo.tmp_books_data_check

	DECLARE @count int, @error_notification nvarchar(100), @error_id int
	SET @error = 0
	SET @error_notification = 'Blad przy sprawdzaniu danych w tmp_sales_data: '

	SELECT @count = COUNT(*) FROM tmp_sales_data
	IF @count = 0
	BEGIN
		SET @error_notification = @error_notification + 'plik jest pusty'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description) VALUES (@error_id, 'Brak wierszy w tmp_books_data')

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	SELECT @count = COUNT(*) FROM tmp_sales_data WHERE sales_id IN (SELECT sales_id FROM tmp_sales_data GROUP BY sales_id HAVING COUNT(*) > 1)
	IF @count > 1
	BEGIN
		SET @error_notification = @error_notification + 'plik nie moze zawierac powtarzajacych sie sales_id'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()

		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.sales_id FROM tmp_sales_data t WHERE sales_id IN (SELECT sales_id FROM tmp_sales_data GROUP BY sales_id HAVING COUNT(*) > 1)

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	SELECT @count = COUNT(*) FROM tmp_sales_data WHERE sales_id < 0
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'plik nie moze zawierac sales_id mniejszych od 0'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.sales_id FROM tmp_sales_data t WHERE sales_id < 0

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	DECLARE @ym_max nchar(10)
	SET @ym_max = FORMAT(GETDATE(), 'yyyy-MM-dd')
	SELECT @count = COUNT(*) FROM tmp_sales_data WHERE sale_date >= @ym_max
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'sale_date musi byc starsze od aktualnej daty'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.sale_date FROM tmp_sales_data t WHERE sale_date >= @ym_max

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	/* 
	 * INTEGRACJA 
	 */
	SELECT @count = COUNT(*) FROM tmp_sales_data WHERE book_id NOT IN (SELECT book_id FROM tmp_books_data)
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'nie znaleziono book_id w tmp_books_data'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,t.book_id FROM tmp_sales_data t WHERE book_id NOT IN (SELECT book_id FROM tmp_books_data)

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	/* 
	 * Sprawdzenie czy wartosc unit_price w tmp_sales_data odpowiada netto_value w tmp_books_data ksiazdki z danym book_id
	 *
	 SELECT s.sales_id,s.unit_price AS unit_price_sales,b.netto_value AS netto_value_books
		FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id WHERE NOT s.unit_price = b.netto_value
	 */
	SELECT @count = COUNT(*) FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id WHERE NOT s.unit_price = b.netto_value
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'wartosc unit_price nie odpowiada netto_value ksiazki'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,s.book_id FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id WHERE NOT s.unit_price = b.netto_value

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END

	/* 
	 * Sprawdzenie czy netto_value zgadza sie z wartoscia uzyskana po 
	 * pomnozeniu unit_price oraz quantity_sold
	 *
	SELECT s.sales_id,CONVERT(FLOAT, s.netto_value),CONVERT(FLOAT, s.unit_price) * CONVERT(FLOAT, s.quantity_sold) AS calculated_netto_value
		FROM tmp_sales_data s WHERE ABS(CONVERT(FLOAT, s.netto_value) - CONVERT(FLOAT, s.unit_price) * CONVERT(FLOAT, s.quantity_sold)) > 0.001
	*/
	SELECT @count = COUNT(*) FROM tmp_sales_data s WHERE ABS(CONVERT(FLOAT, s.netto_value) - CONVERT(FLOAT, s.unit_price) * CONVERT(FLOAT, s.quantity_sold)) > 0.001
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'nieprawidlowo wyliczone netto_value w tmp_sales_data'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,s.netto_value FROM tmp_sales_data s WHERE ABS(CONVERT(FLOAT, s.netto_value) - CONVERT(FLOAT, s.unit_price) * CONVERT(FLOAT, s.quantity_sold)) > 0.001

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END


	/* 
	 * Sprawdzenie czy wymnozona wartosc brutto sie zgadza
	 * wzgledem wartosci netto_value ksiazki oraz quantity_sold zamowienia
	 *
	SELECT s.sales_id,s.brutto_value,ROUND(CONVERT(FLOAT, s.netto_value) * (1 + CONVERT(FLOAT, b.vat)), 2) AS calculated_brutto_value_books_sales
		FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id
		WHERE NOT s.brutto_value = ROUND(CONVERT(FLOAT, s.netto_value) * (1 + CONVERT(FLOAT, b.vat)), 2)
	*/
	SELECT @count = COUNT(*) FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id
		WHERE NOT s.brutto_value = ROUND(CONVERT(FLOAT, s.netto_value) * (1 + CONVERT(FLOAT, b.vat)), 2)
	IF @count > 0
	BEGIN
		SET @error_notification = @error_notification + 'nieprawidlowo wyliczone brutto_value w tmp_sales_data'
		INSERT INTO ERROR_LOGS(error_description) VALUES (@error_notification)
		SET @error_id = SCOPE_IDENTITY()
		
		INSERT INTO ERROR_LOGS_DETAILS(error_log_id, error_description)
			SELECT DISTINCT @error_id,s.brutto_value FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id
				WHERE NOT s.brutto_value = ROUND(CONVERT(FLOAT, s.netto_value) * (1 + CONVERT(FLOAT, b.vat)), 2)

		RAISERROR(@error_notification, 16, 6)
		RETURN -1
	END
GO

delete from ERROR_LOGS_DETAILS
delete from ERROR_LOGS
GO

exec tmp_sales_data_check
GO

/* TRANSFER */
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'sales_data' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1) )
BEGIN -- drop table sales_data
	CREATE TABLE sales_data (
		country nvarchar(50)    NOT NULL,
		sale_month nchar(6)    NOT NULL,
		sale_date DATE NOT NULL,
		sales_id NVARCHAR(50) NOT NULL,
		client_name NVARCHAR(50) NOT NULL,
		client_nip NVARCHAR(20) NOT NULL,
		book_id NVARCHAR(50) NOT NULL,
		quantity_sold NVARCHAR(50) NOT NULL,
		unit_price DECIMAL(18, 2) NOT NULL,
		netto_value DECIMAL(18, 2) NOT NULL,
		vat DECIMAL(18, 2) NOT NULL,
		brutto_value DECIMAL(18, 2) NOT NULL,
		PRIMARY KEY (sales_id)
	);
END
GO



EXEC dbo.create_empty_proc @proc_name = 'insert_all_sales_data'
GO
ALTER PROCEDURE dbo.insert_all_sales_data
AS
    BEGIN TRY
		BEGIN TRAN MigrationTransaction;

		DELETE FROM sales_data WHERE sales_id IN (SELECT sales_id FROM tmp_sales_data)

		INSERT INTO sales_data (country, sale_month, sale_date, sales_id, client_name, client_nip, book_id, quantity_sold, unit_price, netto_value, vat, brutto_value)
			SELECT b.country, LEFT(REPLACE(sale_date, '-', ''), 6) AS sale_month, s.sale_date, s.sales_id, s.client_name, s.client_nip, s.book_id, s.quantity_sold, s.unit_price, s.netto_value, b.vat, s.brutto_value
			FROM tmp_sales_data s JOIN tmp_books_data b ON s.book_id = b.book_id

		COMMIT TRAN MigrationTransaction;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN MigrationTransaction;

		DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
		DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
		DECLARE @ErrorState INT = ERROR_STATE();

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
	END CATCH
GO

EXEC dbo.create_empty_proc @proc_name = 'generate_xml_reports'
GO
ALTER PROCEDURE dbo.generate_xml_reports
AS
	/* wszystkie dane zawarte w tabeli sales_data */
	SELECT 
		country AS Country,
		sale_month AS SaleMonth,
		sale_date AS SaleDate,
		sales_id AS SalesId,
		client_name AS ClientName,
		client_nip AS ClientNip,
		book_id AS BookId,
		quantity_sold AS QuantitySold,
		unit_price AS UnitPrice,
		netto_value AS NettoValue,
		vat AS VAT,
		brutto_value AS BruttoValue
	FROM 
		sales_data
	FOR XML PATH ('SalesData'), ROOT('SalesDataCollection')

	/* dane zawarte w tabeli sales_data podzielone na konkretnych klientow */
	SELECT 
		client_name AS '@ClientName',
		client_nip AS '@ClientNip',
		(
			SELECT 
				country AS Country,
				sale_month AS SaleMonth,
				sale_date AS SaleDate,
				sales_id AS SalesId,
				book_id AS BookId,
				quantity_sold AS QuantitySold,
				unit_price AS UnitPrice,
				netto_value AS NettoValue,
				vat AS VAT,
				brutto_value AS BruttoValue
			FROM 
				sales_data AS innerSales
			WHERE 
				innerSales.client_name = outerSales.client_name
				AND innerSales.client_nip = outerSales.client_nip
			FOR XML PATH ('Sale'), TYPE
		) AS 'Sales'
	FROM 
		(SELECT DISTINCT client_name, client_nip FROM sales_data) AS outerSales
	FOR XML PATH ('Client'), ROOT('ClientsSalesDataCollection');

	/* dane zawarte w tabeli sales_data podzielone na konkretne ksiazki */
	SELECT 
		book_id AS '@BookId',
		(
			SELECT 
				client_name AS '@ClientName',
				client_nip AS '@ClientNip',
				(
					SELECT 
						country AS Country,
						sale_month AS SaleMonth,
						sale_date AS SaleDate,
						sales_id AS SalesId,
						quantity_sold AS QuantitySold,
						unit_price AS UnitPrice,
						netto_value AS NettoValue,
						vat AS VAT,
						brutto_value AS BruttoValue
					FROM 
						sales_data AS innerSales
					WHERE 
						innerSales.book_id = outerSales.book_id
						AND innerSales.client_name = outerSales.client_name
						AND innerSales.client_nip = outerSales.client_nip
					FOR XML PATH ('Sale'), TYPE
				) AS 'Sales'
			FROM 
				(SELECT DISTINCT client_name, client_nip, book_id FROM sales_data) AS outerSales
			WHERE 
				outerSales.book_id = outerBooks.book_id
			FOR XML PATH ('Client'), TYPE
		) AS 'Clients'
	FROM 
		(SELECT DISTINCT book_id FROM sales_data) AS outerBooks
	FOR XML PATH ('Book'), ROOT('BooksSalesDataCollection');

	/* dane zawarte w tabeli sales_data podzielone na konkretne kraje */
	SELECT 
		country AS '@Country',
		(
			SELECT 
				book_id AS '@BookId',
				client_name AS '@ClientName',
				client_nip AS '@ClientNip',
				sale_month AS SaleMonth,
				sale_date AS SaleDate,
				sales_id AS SalesId,
				quantity_sold AS QuantitySold,
				unit_price AS UnitPrice,
				netto_value AS NettoValue,
				vat AS VAT,
				brutto_value AS BruttoValue
			FROM 
				sales_data AS innerSales
			WHERE 
				innerSales.country = outerSales.country
			FOR XML PATH ('Sale'), TYPE
		) AS 'Sales'
	FROM 
		(SELECT DISTINCT country FROM sales_data) AS outerSales
	FOR XML PATH ('Country'), ROOT('CountriesSalesDataCollection');

GO


EXEC dbo.insert_all_sales_data
GO
EXEC dbo.generate_xml_reports
GO

/*
SELECT * FROM tmp_books_data
SELECT * FROM tmp_sales_data
SELECT * FROM sales_data
*/

SELECT * FROM ERROR_LOGS
SELECT * FROM ERROR_LOGS_DETAILS

/*
SELECT * FROM tmp_books_data
SELECT * FROM tmp_sales_data
*/


/*
 * Tabele musza byc puste, jednak sa automatycznie czyszczone podczas
 * wykonywania pakietu SSIS
 */

/*
DELETE FROM tmp_sales_data
DELETE FROM tmp_books_data
GO
*/