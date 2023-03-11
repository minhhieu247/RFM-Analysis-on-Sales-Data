-- Overview: xem tổng quan bảng sale, để nhìn nhận data
 Select *
 From sales_data_sample;
 -- SELECT DISTINCT status FROM sales_data_sample: Xem các giá trị duy nhất 
SELECT DISTINCT YEAR_ID FROM sales_data_sample
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample
SELECT DISTINCT COUNTRY FROM sales_data_sample
SELECT DISTINCT DEALSIZE FROM sales_data_sample
SELECT DISTINCT TERRITORY FROM sales_data_sample
-- Analysis: Phân tích

-- Sales by product
Select 
		PRODUCTLINE,
		round(sum(SALES),2) as Revenue

From sales_data_sample
Group By PRODUCTLINE
Order by Revenue DESC

--Sales by Year
SELECT 
	YEAR_ID,
	ROUND(SUM(sales),2) AS Revenue
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY Revenue DESC

--Sales by Month 2005
SELECT 
	MONTH_ID,
	ROUND(SUM(sales),2) AS Revenue
FROM sales_data_sample
WHERE YEAR_ID='2005'
GROUP BY MONTH_ID
ORDER BY Revenue DESC

--Revenue by Deal Size
SELECT 
	DEALSIZE,
	ROUND(SUM(sales),2) AS Revenue
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY Revenue DESC

-- Revenue by month/ VIEW YEAR 2005 REVENUE DESC 
SELECT 
		MONTH_ID,
		ROUND(SUM(SALES),2) AS REVENUE
FROM sales_data_sample
WHERE YEAR_ID ='2005'
GROUP BY MONTH_ID 
ORDER BY REVENUE DESC

-- BEST MONTH FOR SALES BY YEAR/Sales and order frequency by year, month and product line
SELECT
		YEAR_ID,
		MONTH_ID, 
		PRODUCTLINE,
		COUNT(ORDERNUMBER) AS FREQUENCY, 
		ROUND(SUM(SALES),2) AS REVENUE
FROM sales_data_sample
GROUP BY 
		YEAR_ID,
		MONTH_ID, 
		PRODUCTLINE
ORDER BY REVENUE DESC

--Best Customers Using RFM Analysis
--Use DATEDIFF() to calculate recency (time between customer last order and most recent date in table)
 SELECT 
		CUSTOMERNAME,
		ROUND(SUM(SALES),2) AS MONETARYVALUE,
		ROUND(AVG(SALES),2) AS AVGVALUE,
		COUNT(ORDERNUMBER) AS FREQUENCE,
		DATEDIFF(dd, max(ORDERDATE), (SELECT max(ORDERDATE) FROM sales_data_sample)) AS Recency,
		--datediff(day,max(OrderDate),GETDATE()) AS RECENCY,
		CONVERT (DATETIME ,MAX(ORDERDATE)) AS LAST_ORDERDATE
 FROM sales_data_sample
 GROUP BY  CUSTOMERNAME
 ORDER BY  MONETARYVALUE DESC

 --RESULT #FRM/ Phần chính
 
 WITH rfm AS (
SELECT 
	CUSTOMERNAME,
	ROUND(SUM(sales),2) AS MonetaryValue,
	ROUND(AVG(sales),2) AS AvgValue,
	COUNT(ORDERNUMBER) AS Frequency,
	MAX(ORDERDATE) AS last_order_date,
	DATEDIFF(dd, max(ORDERDATE), (SELECT max(ORDERDATE) FROM sales_data_sample)) AS Recency
FROM sales_data_sample
GROUP BY CUSTOMERNAME
) , -- các chỉ số RFM quen thuộc/ datediff, count, sum

rfm_calc AS
(
--retrieve all columns from rfm CTE then split rfm_ values into 4 buckets
SELECT 
	r.*,
	NTILE(4) OVER (ORDER BY Recency DESC) AS rfm_recency,
	NTILE(4) OVER (ORDER BY Frequency) AS rfm_frequency,
	NTILE(4) OVER (ORDER BY MonetaryValue) AS rfm_monetary
	-- sử dụng windowfuntion chia ra theo 4 nhóm khách hàng khác nhau
FROM rfm AS r
)

SELECT c.*, 
	   rfm_recency + rfm_frequency + rfm_monetary AS rfm_cell,
	   CAST(rfm_recency AS varchar) + CAST(rfm_frequency AS varchar)+CAST(rfm_monetary AS varchar) AS rfm_cell_string
	   -- cộng chuỗi các rfm để được thêm 1 khía cạnh tổng hợp
--pass CTEs into temp table/ bảng tạm
INTO ##rfm 
FROM rfm_calc AS c
 

 SELECT * FROM ##rfm

 --segment by customer groups
 SELECT 
		CUSTOMERNAME,
		rfm_recency,
		rfm_frequency,
		rfm_monetary,
		rfm_cell_string,
		--các trường hợp phân chia 
		CASE 
	WHEN rfm_cell_string IN (111,112,121,122,123,132,211,212,114,141) THEN 'lost_customers' --lost customers
	WHEN rfm_cell_string IN (133,134,143,244,334,343,344,144) THEN 'slipping away, cannot lose' --(big spenders that havent purchased lately)
	WHEN rfm_cell_string IN (311,411,331) THEN 'new_customers'
	WHEN rfm_cell_string IN (222,223,233,322) THEN 'potential_customers'
	WHEN rfm_cell_string IN (323,333,321,422,332,432) THEN 'active'--customers that buy often at lower price points
	WHEN rfm_cell_string IN (433,434,443,444) THEN 'loyal'
	
	END rfm_segment
 FROM ##rfm

-- BASKET ANALYSIS / Products Sold Together/ Phân tích rổ
-- Gives the Number of products per order.
SELECT
	[ORDERNUMBER],
	COUNT(*) AS rn
FROM sales_data_sample
WHERE status ='Shipped'
GROUP BY ORDERNUMBER;
-- đầu tiên đếm số đơn hàng theo từng ordernumeber

--Filter for ordernumber 10411 to verify there are 9 products in it
--check
SELECT
	*
FROM sales_data_sample
WHERE ORDERNUMBER = 10411;

--Build a subquery that gives us the order numbers when two products are ordered together(rn=2)

SELECT ORDERNUMBER
FROM (
SELECT
	[ORDERNUMBER],
	COUNT(*) AS rn
FROM sales_data_sample
WHERE status ='Shipped'
GROUP BY ORDERNUMBER
) AS m
WHERE rn=2;

--Building a 2nd subquery where we will utilize our first subquery "m" 
--Leverage STRING_AGG() allowing for an order containing two product codes to be represented in the same record.

SELECT 
	 ORDERNUMBER, 
	 STRING_AGG(PRODUCTCODE,',') AS Products
FROM sales_data_sample AS p
WHERE ORDERNUMBER IN (
SELECT ORDERNUMBER
FROM (
SELECT
	[ORDERNUMBER],
	COUNT(*) AS rn
FROM sales_data_sample
WHERE status ='Shipped'
GROUP BY ORDERNUMBER
) AS m
WHERE rn=2
)
GROUP BY ORDERNUMBER
ORDER BY Products;
