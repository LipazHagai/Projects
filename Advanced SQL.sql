USE WideWorldImporters
/*********** 1 ***************/

GO

WITH Income
AS 
(
SELECT
	 YEAR(o.OrderDate) AS 'Year'
	,SUM(ol.PickedQuantity*ol.UnitPrice) AS IncomePerYear -- quantitypicked not taxed
	,COUNT(DISTINCT MONTH(o.OrderDate)) AS NumOfDisstinctMonhes
	,SUM(ol.PickedQuantity*ol.UnitPrice) / COUNT(DISTINCT MONTH(o.OrderDate)) * 12 AS YearlyLinearIncome -- Profit so far divide by num of months * 12 to predict whats coming
	,LAG(SUM(ol.PickedQuantity*ol.UnitPrice) / COUNT(DISTINCT MONTH(o.OrderDate)) * 12,1)OVER(ORDER BY YEAR(o.OrderDate)) AS ProfLastYear -- what is prof from last year
	FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID

GROUP BY YEAR(o.OrderDate)
)
SELECT 
	 Income.Year
	,Income.IncomePerYear
	,Income.NumOfDisstinctMonhes 
	,FORMAT(Income.YearlyLinearIncome,'#.00') AS YearlyLinearIncome
	,FORMAT( (YearlyLinearIncome - ProfLastYear) / ProfLastYear * 100, '#0.00')  AS GrowthRate
	FROM Income
ORDER BY Year


/************ 2 *****************/
GO

WITH Top5CusQ
AS
(
SELECT
	 YEAR(o.OrderDate) AS TheYear
	,DATEPART(qq,o.OrderDate) AS TheQuarter
	,o.CustomerID
	,SUM(ol.PickedQuantity*ol.UnitPrice) AS IncomePerYear -- quantitypicked not taxed
	,DENSE_RANK()OVER(PARTITION BY YEAR(o.OrderDate),DATEPART(qq,o.OrderDate) ORDER BY SUM(ol.PickedQuantity*ol.UnitPrice) DESC) AS DNR
	FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
GROUP BY YEAR(o.OrderDate), DATEPART(qq,o.OrderDate),o.CustomerID
)
SELECT 
	 TheYear
	,TheQuarter
	,c.CustomerName
	,IncomePerYear
	,DNR
	FROM Top5CusQ
JOIN Sales.Customers c
	ON c.CustomerID = Top5CusQ.CustomerID
WHERE DNR BETWEEN 1 AND 5
ORDER BY TheYear,TheQuarter,DNR

/*********** 3 **************/
GO

SELECT TOP 10
	 IL.StockItemID
	,IL.Description AS StockItemName
	,SUM(IL.ExtendedPrice-IL.TaxAmount) AS TotalProfit
	FROM Sales.InvoiceLines IL
GROUP BY IL.StockItemID,IL.Description
ORDER BY TotalProfit DESC

/************ 4 ************/
GO

SELECT 
	 ROW_NUMBER()OVER(ORDER BY Si.UnitPrice DESC) AS RN
	,Si.StockItemID
	,Si.StockItemName
	,Si.UnitPrice
	,Si.RecommendedRetailPrice
	,Si.RecommendedRetailPrice - UnitPrice AS NominalProductProfit
	,DENSE_RANK()OVER(ORDER BY Si.UnitPrice DESC) AS DNR
	FROM Warehouse.StockItems Si

/************ 5 ***********/
GO

WITH SupDet
AS
(
SELECT
	 CONCAT(s.SupplierID, '  -  ', s.SupplierName) AS SupplierDetails
	,STUFF(	(SELECT 
				CONCAT('/,',si.StockItemID,' ',Si.StockItemName)
				FROM Warehouse.StockItems Si
			 WHERE s.SupplierID = si.SupplierID
			FOR XML PATH('')	),1,2,'')	ProductDetails
FROM Purchasing.Suppliers s
)
SELECT *
	FROM SupDet
WHERE ProductDetails IS NOT NULL

/********** 6 **************/
GO


WITH Top5Cus
AS
(
SELECT TOP 5
	 cus.CustomerID
	,cit.CityName
	,con.CountryName
	,con.Continent
	,con.Region
	,SUM(IL.ExtendedPrice) AS TotalExtendedPrice
	FROM Sales.InvoiceLines IL
JOIN Sales.Invoices I
	ON I.InvoiceID = IL.InvoiceID
JOIN Sales.Customers cus
	ON cus.CustomerID = I.CustomerID
JOIN Application.Cities cit
	ON cit.CityID = cus.PostalCityID
JOIN Application.StateProvinces sp
	ON sp.StateProvinceID = cit.StateProvinceID
JOIN Application.Countries con
	ON con.CountryID = sp.CountryID

GROUP BY cus.CustomerID,cit.CityName,con.CountryName,con.Continent,con.Region
ORDER BY TotalExtendedPrice DESC
)

SELECT 
	 CustomerID
	,CityName
	,CountryName
	,Continent
	,Region
	,FORMAT(TotalExtendedPrice, '#,#.00') AS TotalExtendedPrice
	FROM Top5Cus



/******** 7 *************/
-- need fixing (order by)

GO
WITH T1
AS
(
SELECT 
	 YEAR(o.OrderDate) AS OrderYear
	,MONTH(o.OrderDate) AS OrderMonth1
	,SUM(ol.PickedQuantity*ol.UnitPrice) AS MonthlyTotal
	
	FROM Sales.OrderLines ol
JOIN Sales.Orders o
	ON o.OrderID = ol.OrderID
GROUP BY YEAR(o.OrderDate),MONTH(o.OrderDate)
)
,T2
AS
(
SELECT 
	 YEAR(o.OrderDate) AS OrderYear
	,SUM(ol.PickedQuantity*ol.UnitPrice) AS YearlyTotal
	FROM Sales.OrderLines ol
JOIN Sales.Orders o
	ON o.OrderID = ol.OrderID
GROUP BY YEAR(o.OrderDate)
),
T3
AS
(
SELECT 
	 T1.OrderYear
	,CAST(T1.OrderMonth1 AS VARCHAR) OrderMonth
	,T1.MonthlyTotal
	,OrderMonth1
FROM T1

UNION

SELECT 
	 T2.OrderYear
	 ,'Grand Total'  
	 ,T2.YearlyTotal
	 ,13
FROM T2
)
-- Main Query
SELECT
	  OrderYear
	 ,OrderMonth
	 ,FORMAT(MonthlyTotal,'#,#.00') AS MonthlyTotal
	-- ,FORMAT(SUM(MonthlyTotal)OVER(PARTITION BY OrderYear ORDER BY OrderMonth1),'#,#.00') AS CumulativeTotal
	-- ,MAX(MonthlyTotal)OVER(PARTITION BY OrderYear ORDER BY OrderMonth1)
	 ,CASE
		WHEN ISNUMERIC(OrderMonth)=1-- LIKE '%[1-12]%'
			THEN  FORMAT(SUM(MonthlyTotal)OVER(PARTITION BY OrderYear ORDER BY OrderMonth1),'#,#.00')
		ELSE FORMAT(MAX(MonthlyTotal)OVER(PARTITION BY OrderYear ORDER BY OrderMonth1), '#,#.00') 
	 END CumulativeTotal

FROM T3
ORDER BY OrderYear,OrderMonth1

/*************** 8****************/
GO

WITH ord
AS
(
SELECT 
	 YEAR(o.OrderDate) AS OrderYear
	,MONTH(o.OrderDate) AS OrderMonth
	,o.OrderID
	FROM Sales.Orders o
)

SELECT *
	FROM ord
PIVOT(COUNT(ord.OrderID) FOR ord.OrderYear IN([2013],[2014],[2015],[2016])) pv

ORDER BY OrderMonth

/********* 9 **********/
GO

GO
WITH NumDay
AS
(
SELECT 
	 o.CustomerID
	,c.CustomerName
	,o.OrderDate
	,LAG(o.OrderDate)OVER(PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PrevOrder
	,DATEDIFF(dd,ISNULL(LAG(o.OrderDate,1)OVER(PARTITION BY o.CustomerID ORDER BY o.OrderDate),
		 o.OrderDate),o.OrderDate) AS DaySinceCUSTLastOrder
	,DATEDIFF(dd,MAX(o.OrderDate)OVER(PARTITION BY o.CustomerID),MAX(o.OrderDate)OVER()) AS DaySinceLastOrder
	FROM Sales.Orders o
JOIN Sales.Customers c
	ON c.CustomerID = o.CustomerID
),
t2
AS
(
SELECT
	 CustomerID
	,CustomerName
	,OrderDate
	,PrevOrder
	,DaySinceLastOrder
	,SUM(DaySinceCUSTLastOrder)OVER(PARTITION BY CustomerID) / COUNT(DaySinceCUSTLastOrder)OVER(PARTITION BY CustomerID) AS AvgDaysBetOrders
	FROM NumDay
)
SELECT
	 CustomerID
	,CustomerName
	,OrderDate
	,PrevOrder
	,DaySinceLastOrder
	,AvgDaysBetOrders
	,CASE
		WHEN DaySinceLastOrder > AvgDaysBetOrders*2
			THEN 'Potential Churn'
		WHEN DaySinceLastOrder <= AvgDaysBetOrders*2
			THEN  'Active'
	 END 'Customer Status'
	FROM t2


/*********** 10 ***************/
GO

WITH NewC
AS
(
SELECT 
	 c.CustomerID
	,CASE 
		WHEN c.CustomerName LIKE '%Wingtip%' THEN 'Wingtip Customers'
		WHEN c.CustomerName LIKE '%Tailspin%' THEN 'Tailspin Customers'
		ELSE c.CustomerName
		END  CustomerName
	,c.CustomerCategoryID
	,cc.CustomerCategoryName
	FROM Sales.Customers c
JOIN Sales.CustomerCategories cc
	ON cc.CustomerCategoryID = c.CustomerCategoryID
),
DisCus
AS
(
SELECT 
	 CustomerCategoryName
	,COUNT(DISTINCT CustomerName) AS CustomerCOUNT
	FROM NewC
GROUP BY CustomerCategoryName
)

SELECT 
	 CustomerCategoryName
	,CustomerCOUNT
	,SUM(CustomerCOUNT)OVER() AS TotalCustCount
	,FORMAT(CAST(CustomerCOUNT AS FLOAT)/SUM(CustomerCOUNT)OVER(), '#.00%') AS DistributionFactor
	FROM DisCus

ORDER BY CustomerCategoryName
