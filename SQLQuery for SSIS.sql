-- Custromer Dimension:
--WHERE p.PersonType IN ('IN', 'SC', 'VC')

	SELECT 
		c.CustomerID,
		ISNULL(p.FirstName, 'No Name') AS [FirstName],
		ISNULL(p.LastName, 'No Name') AS [LastName],
		ISNULL(p.PersonType, 'No Type') AS [PersonType]
	FROM Sales.Customer c
	LEFT OUTER JOIN Person.Person p
		ON c.PersonID = p.BusinessEntityID

-- Sale Order Dimension

-- ActualCost per SalesOrderID from the TransactionHistory table
SELECT
    sod.SalesOrderDetailID,
	sod.SalesOrderID,
	sod.ProductID,
    SUM(th.ActualCost) AS TotalActualCost
FROM Sales.SalesOrderDetail sod
LEFT JOIN Production.TransactionHistory th
    ON sod.SalesOrderID = th.ReferenceOrderID 
GROUP BY 
    sod.SalesOrderDetailID, sod.SalesOrderID, sod.ProductID

SELECT
  soh.SalesOrderID,
  sod.SalesOrderDetailID,
  soh.OrderDate,
  sod.LineTotal,
  --th.ActualCost,
  ISNULL(sr.Name, 'No Reason') AS [ReasonName],
  ISNULL(sr.ReasonType, 'No Reason') AS [ReasonType]
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod
  ON soh.SalesOrderID = sod.SalesOrderID
--JOIN Production.TransactionHistory th
  --ON sod.SalesOrderID = th.ReferenceOrderID  
JOIN Sales.SalesOrderHeaderSalesReason sohsr
  ON soh.SalesOrderID = sohsr.SalesOrderID
JOIN Sales.SalesReason sr
  ON sohsr.SalesReasonID = sr.SalesReasonID

-- Product Dimension
SELECT 
  p.ProductID,
  ISNULL(CAST(psc.ProductCategoryID AS varchar(10)), 'No ID') AS [ProductCategoryID],
  ISNULL(CAST(pc.Name AS varchar(10)), 'No Name') AS [ProductCategory],
  ISNULL(CAST(psc.Name AS varchar(10)), 'No Name') AS ProductSubcategory
FROM Production.Product p
LEFT OUTER JOIN Production.ProductSubcategory psc 
  ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT OUTER JOIN Production.ProductCategory pc 
  ON psc.ProductCategoryID = pc.ProductCategoryID

-- Location Dimension
SELECT
  a.AddressID,
  cr.Name AS RegionCountry, 
  sp.Name AS StateProvince,
  a.City
FROM Person.Address a
JOIN Person.StateProvince sp 
  ON a.StateProvinceID = sp.StateProvinceID
JOIN Person.CountryRegion cr
  ON sp.CountryRegionCode = cr.CountryRegionCode

-- Time Dimension

-- Sales Fact
SELECT
  c.CustomerID,
  p.PersonType,
  soh.SalesOrderID,
  sod.SalesOrderDetailID,
  sod.ProductID,
  psc.ProductCategoryID,
  psc.ProductSubcategoryID,
  a.AddressID,
  soh.TotalDue,
  sod.LineTotal,
  --th.ActualCost,
  t.FullDateAlternateKey AS DateKey,
  sod.LineTotal - th.ActualCost AS OrderDetailProfit
FROM Sales.Customer c
LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID  
LEFT JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
LEFT JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
--JOIN Production.TransactionHistory th ON sod.SalesOrderID = th.ReferenceOrderID
LEFT JOIN Production.Product prod ON sod.ProductID = prod.ProductID
LEFT JOIN Production.ProductSubcategory psc ON prod.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Person.Address a ON soh.BillToAddressID = a.AddressID
LEFT JOIN AdventureworksTime t ON soh.OrderDate = t.FullDateAlternateKey  
LEFT JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
LEFT JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode

CREATE TABLE Fact_Sales (
  CustomerID int, 
  PersonType nchar(2),
  SalesOrderID int,
  ProductID int,
  ProductCategoryID int,
  ProductSubcategoryID int, 
  AddressID int,
  DateKey date, 
  SalesAmt money
);

-- CTE to Calculate Recency, Frequency, and Monetary for Each Customer
WITH CustomerRFM AS (
    SELECT 
        CustomerID,
        MAX(OrderDate) AS LastPurchaseDate,
        COUNT(SalesOrderID) AS Frequency,
        SUM(TotalDue) AS Monetary
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID)
SELECT 
    c.CustomerID,
    p.PersonType,
    soh.SalesOrderID,
    sod.ProductID,
    soh.OrderDate,
    DATEDIFF(DAY, cr.LastPurchaseDate, soh.OrderDate) AS Recency,
    cr.Frequency,
    cr.Monetary,
    soh.TotalDue AS SalesAmt
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
LEFT JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
LEFT JOIN CustomerRFM cr ON soh.CustomerID = cr.CustomerID;

FROM Sales.Customer c
LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID  
LEFT JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
LEFT JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
--JOIN Production.TransactionHistory th ON sod.SalesOrderID = th.ReferenceOrderID
LEFT JOIN Production.Product prod ON sod.ProductID = prod.ProductID
LEFT JOIN Production.ProductSubcategory psc ON prod.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Person.Address a ON soh.BillToAddressID = a.AddressID
LEFT JOIN AdventureworksTime t ON soh.OrderDate = t.FullDateAlternateKey  
LEFT JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
LEFT JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode

-- Main query to select CustomerID and TotalStandardCost
WITH CostData AS (
    SELECT 
        ProductID,
        MAX(EndDate) AS LatestCostDate,
        MAX(StandardCost) AS LatestStandardCost
    FROM Production.ProductCostHistory
    GROUP BY ProductID)

SELECT
  sod.SalesOrderDetailID,
  sod.SalesOrderID,
  ISNULL(cd.LatestStandardCost * sod.OrderQty, 0) AS TotalStandardCost
FROM Sales.SalesOrderDetail sod
LEFT JOIN CostData cd ON sod.ProductID = cd.ProductID;

