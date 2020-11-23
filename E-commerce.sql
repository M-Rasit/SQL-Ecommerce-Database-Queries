CREATE DATABASE [E-commerce]

UPDATE [dbo].[shipping_dimen]
SET [Ship_Date] = CONVERT(DATE, RIGHT([Ship_Date],4)+SUBSTRING([Ship_Date],4,2)+LEFT([Ship_Date],2))

UPDATE [dbo].[orders_dimen]
SET [Order_Date] = CONVERT(DATE, RIGHT([Order_Date],4)+SUBSTRING([Order_Date],4,2)+LEFT([Order_Date],2))


UPDATE [dbo].[prod_dimen]
SET Prod_id = 'Prod_16' WHERE Product_Sub_Category =  'SCISSORS'

UPDATE [dbo].[shipping_dimen]
SET [Order_ID] = 'Ord_' + [Order_ID]


/*Joining all the tables and create a new table with all of the columns, 
called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen,
shipping_dimen)*/


SELECT m.Ord_id, m.Prod_id, m.Ship_id, m.Cust_id, m.Sales, m.Discount, m.Order_Quantity, m.Profit, m.Shipping_Cost,
m.Product_Base_Margin, c.Customer_Name, C.Province, C.Region, C.Customer_Segment, o.Order_Date, o.Order_Priority, p.Product_Category, p.Product_Sub_Category, s.Ship_Date, s.Ship_Mode
INTO combined_table FROM market_fact m
INNER JOIN [dbo].[cust_dimen] c ON m.Cust_id = c.Cust_id
INNER JOIN [dbo].[orders_dimen] o ON m.Ord_id = o.[Ord_id]
INNER JOIN [dbo].[prod_dimen] p ON m.Prod_id = p.Prod_id
INNER JOIN [dbo].[shipping_dimen] s ON m.Ship_id = s.Ship_id

/*Finding the top 3 customers who have the maximum count of orders.*/


SELECT [Customer_Name] FROM  [dbo].[cust_dimen] c
RIGHT JOIN
(SELECT TOP 3 Cust_id
FROM [dbo].[market_fact]
GROUP BY [Cust_id]
ORDER BY COUNT(*) DESC) a
ON c.Cust_id = a.Cust_id


/*Creating a new column at combined_table as DaysTakenForDelivery that
contains the date difference of Order_Date and Ship_Date*/


ALTER TABLE [dbo].[combined_table] ADD DaysTakenForDelivery AS DATEDIFF(DAY,[Order_Date], [Ship_Date])


/*Finding the customer whose order took the maximum time to get delivered.*/


SELECT Customer_Name FROM [dbo].[cust_dimen]
WHERE Cust_id = (SELECT TOP 1 Cust_id FROM [dbo].[combined_table]
					WHERE DaysTakenForDelivery = (SELECT  MAX(DaysTakenForDelivery) 
					FROM [dbo].[combined_table]))


/*Retrieving total sales made by each product from the data (Window function)*/


ALTER TABLE [dbo].[market_fact]
ALTER COLUMN [Sales] FLOAT

SELECT DISTINCT(Prod_id), SUM(Sales) OVER(PARTITION BY Prod_id ORDER BY Prod_id) [total_sales]
FROM market_fact
ORDER BY total_sales DESC


/*Retrieving total profit made from each product from the data (Window function)*/


ALTER TABLE [dbo].[market_fact]
ALTER COLUMN [Profit] FLOAT

SELECT DISTINCT(Prod_id), SUM(Profit) OVER(PARTITION BY Prod_id ORDER BY Prod_id) [total_profit]
FROM [dbo].[market_fact]
ORDER BY total_profit DESC



/*Counting the total number of unique customers in January and how many of them
came back every month over the entire year in 2011*/


CREATE VIEW jan_2011 AS
SELECT DISTINCT(Cust_id) FROM [dbo].[market_fact] m
				  INNER JOIN [dbo].[orders_dimen] o ON m.Ord_id = o.Ord_id
				  WHERE MONTH(Order_Date) = '01' AND YEAR(Order_Date) = '2011'


SELECT COUNT(DISTINCT(Cust_id)) cust_january_2011_count FROM [dbo].[market_fact] m
				  INNER JOIN [dbo].[orders_dimen] o ON m.Ord_id = o.Ord_id
				  WHERE MONTH(Order_Date) = '01' AND YEAR(Order_Date) = '2011'



SELECT DISTINCT m.Cust_id, COUNT(MONTH(o.Order_Date)) [month] FROM  [dbo].[market_fact] m
				  INNER JOIN [dbo].[orders_dimen] o ON m.Ord_id = o.Ord_id
				  WHERE m.Cust_id IN (SELECT * FROM jan_2011) AND YEAR(o.Order_Date) = '2011'
				  GROUP BY Cust_id
				  HAVING COUNT(MONTH(o.Order_Date)) = 12



/*Creating a view where each users visits are logged by month, allowing for the
possibility that these will have occurred over multiple years since whenever
business started operations.*/




CREATE VIEW visit_log AS
SELECT cust_id, 
	   DATEDIFF(MONTH, (SELECT MIN(Order_Date) FROM orders_dimen), Order_Date) AS visit_month
FROM market_fact m INNER JOIN orders_dimen o ON m.Ord_id = o.Ord_id




/*Identifing the time lapse between each visit. So, for each person and for each
month, we see when the next visit is.*/




CREATE VIEW Time_lapse AS
SELECT cust_id, visit_month, 
	   lead(visit_month, 1) OVER (PARTITION BY cust_id ORDER BY  visit_month) AS lead
FROM visit_log




/*Calculating the time gaps between visits*/




CREATE VIEW Time_gaps AS
SELECT cust_id, visit_month, lead, lead - visit_month AS diff
FROM time_lapse




/*Categorising the customer with time gap 1 as retained, >1 as irregular and NULL
as churned*/




CREATE VIEW categorized AS
SELECT cust_id, visit_month, 
	CASE
		WHEN diff = 1 THEN 'RETAINED'
		WHEN diff > 1 OR diff = 0 THEN 'IRREGULAR'
		WHEN diff  IS NULL THEN 'CHURNED'
	END category
FROM Time_gaps




/*Calculating the retention month wise*/




SELECT visit_month, 
	   (SELECT COUNT(cust_id) FROM categorized WHERE category='RETAINED') /count(cust_id)  [retention]
FROM categorized
GROUP BY visit_month
ORDER BY visit_month

