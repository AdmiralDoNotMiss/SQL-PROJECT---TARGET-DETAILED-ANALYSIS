-- 1. INITIAL EXPLORATORY ANALYSIS 
-- 1.a. DATA TYPE OF ALL THE COLUMNS IN CUSTOMER'S TABLE

SELECT  COLUMN_NAME,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE  TABLE_NAME = 'customers' 
;
-- 1.b. GET THE TIME RANGE BETWEEN WHICH THE ORDERS WERE PLACED.

SELECT MIN(order_purchase_timestamp) as FIRST_ORDER , MAX(order_purchase_timestamp) as LAST_ORDER
FROM target.orders
;

-- 1.c. COUNT THE CITIES AND STATES OF CUSTOMERS WHO ORDERED DURING THE GIVEN PERIOD.

SELECT COUNT(DISTINCT customer_city) AS total_cities, COUNT(DISTINCT customer_state) AS total_states
FROM target.customers
;

-- 2. INDEPTH EXPLORATION
-- WE'LL TRY TO UNDERSTAND THE TREND IN THE DATA AND SEE HOW THINGS HAVE CHANGED FOR THE DATA THAT WE HAVE OVER THE COURSE OF TIME.

-- 2.a.  IS THERE A GROWING TREND IN THE NO. OF ORDERS PLACED OVER THE PAST YEARS?

SELECT  YEAR(order_purchase_timestamp) as Year, MONTH(order_purchase_timestamp) as Month,COUNT(DISTINCT order_id) as total_orders
FROM target.orders
GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
ORDER BY YEAR(order_purchase_timestamp) , MONTH(order_purchase_timestamp)
;

-- 2.b. CAN WE SEE SOME KIND OF MONTHLY SEASONALITY IN TERMS OF THE NO. OF ORDERS BEING PLACED?

SELECT MONTH(order_purchase_timestamp) as month,COUNT(*) AS total_orders
FROM target.orders
GROUP BY MONTH(order_purchase_timestamp)
ORDER BY MONTH(order_purchase_timestamp)
;


-- 2.c. DURING WHAT TIME OF DAY, DO THE BRAZILIAN CUSTOMERS MOSTLY PLACE THEIR ORDERS? ( DAWN, MORNING, AFTERNOON OR NIGHT).

SELECT 
   CASE WHEN HOUR(order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'dawn'
         WHEN HOUR(order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'morning'
          WHEN HOUR(order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'afternoon'
           WHEN HOUR(order_purchase_timestamp) BETWEEN 19 AND 23 THEN 'night'
	END AS time_of_day,
    COUNT(*) AS total_orders
FROM target.orders
GROUP BY 1
ORDER BY 2 DESC
;
       
-- 3. EVOLUTION OF E-COMMERCE ORDERS IN BRAZIL REGION

-- Now we’ll try to understand data based on state or city level and see what variations are present 
-- and how the people in various states order and receive deliveries.

-- 3.a. GET THE MONTH ON MONTH NO. OF ORDERS PLACED IN EACH STATE 

SELECT MONTH(o.order_purchase_timestamp) as mnth, c.customer_state,
        COUNT(DISTINCT o.order_id) as total_orders
FROM target.customers as c 
INNER JOIN target.orders as o
ON c.customer_id = o.customer_id
GROUP BY MONTH(o.order_purchase_timestamp), c.customer_state
ORDER BY total_orders DESC
;


-- 3.b. HOW ARE THE CUSTOMERS DISTRIBUTED ACROSS ALL THE STATES 

SELECT customer_state, COUNT(DISTINCT customer_unique_id) as total_customers
FROM target.customers
GROUP BY customer_state
ORDER BY total_customers DESC
;


-- 4. IMPACT ON ECONOMY: 
-- Until now, we just answered questions on the E-commerce scenario considering the number of orders received.
-- We could see the volumetry by a month, day of week, time of the day and even the geolocation states.
-- Now, we will Analyze the money movement by e-commerce by looking at order prices, freight and others.


-- 4.a. GET THE % INCREASE IN THE COST OF ORDERS FROM YEAR 2017-2018( INCLUDE MONTHS BETWEEN JANUARY TO AUGUST ONLY)

WITH CTE AS(
SELECT YEAR(o.order_purchase_timestamp) as year, ROUND(SUM(p.payment_value),2) as cost
FROM target.orders as o
INNER JOIN target.payments as p
ON o.order_id = p.order_id
WHERE YEAR(o.order_purchase_timestamp) BETWEEN 2017 AND 2018
    AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8 
GROUP BY YEAR(o.order_purchase_timestamp) 
ORDER BY YEAR(o.order_purchase_timestamp) 
)

SELECT year , cost,
LAG(cost,1) OVER(ORDER BY year asc) as next_year_cost,
ROUND((100.0*(cost - LAG(cost,1) OVER(ORDER BY year asc))/ cost),2) as percent_increase
FROM CTE 
ORDER BY year
;


-- 4.b. YEAR & MONTH WISE ANALYSIS ON PRICE PER ORDER AND FREIGHT PER ORDER 

SELECT YEAR(o.order_purchase_timestamp) as year, MONTH (o.order_purchase_timestamp) as mth , 
	   SUM(oi.price)/COUNT(DISTINCT oi.order_id) as price_per_order,
       SUM(oi.freight_value)/COUNT(DISTINCT oi.order_id) as freight_per_order
FROM target.order_items as oi 
INNER JOIN target.orders as o
ON oi.order_id = o.order_id
GROUP BY YEAR(o.order_purchase_timestamp) 
	, MONTH (o.order_purchase_timestamp)
ORDER BY year DESC
;


-- 4.c. CALCULATING THE TOTAL & AVERAGE VALUE OF ORDER PRICE PER EACH STATE

WITH CTE AS(
SELECT c.customer_state, ROUND(SUM(oi.price),2) as total_price, COUNT(DISTINCT o.order_id) as num_orders
FROM target.order_items as oi
INNER JOIN target.orders as o
ON oi.order_id = o.order_id
INNER JOIN target.customers as c
ON o.customer_id = c.customer_id
GROUP BY c.customer_state
)
SELECT customer_state as state, total_price, num_orders, ROUND(total_price/num_orders,2) as avg_price
FROM CTE
ORDER BY total_price DESC
;

-- 4.c. CALCULATING THE TOTAL & AVERAGE VALUE OF ORDER FREIGHT PER EACH STATE

WITH CTE AS(
SELECT c.customer_state, ROUND(SUM(oi.freight_value),2) as total_freight, COUNT(DISTINCT o.order_id) as num_orders
FROM target.order_items as oi
INNER JOIN target.orders as o
ON oi.order_id = o.order_id
INNER JOIN target.customers as c
ON o.customer_id = c.customer_id
GROUP BY c.customer_state
)
SELECT customer_state as state, total_freight, num_orders, ROUND(total_freight/num_orders,2) as avg_freight
FROM CTE
ORDER BY total_freight DESC
;



-- 5. ANALYSIS BASED ON SALES,FREIGHT AND DELIVERY TIME.

-- 5.a FINDING THE NO. OF DAYS TAKEN TO DELIVER EACH ORDER.
-- ALSO, CALCULATING THE DIFFERENCE BETWEEN THE ESTIMATED & ACTUAL DELIVERY DATE OF AN ORDER.

SELECT order_id,
TIMESTAMPDIFF(DAY,order_purchase_timestamp,order_delivered_customer_date) as delivery_days_taken,
TIMESTAMPDIFF(DAY,order_delivered_customer_date,order_estimated_delivery_date) as differnce_estimated_del
FROM target.orders 
WHERE order_status = 'delivered'
ORDER BY delivery_days_taken 
;

-- 5.b. TOP 5 STATES WITH THE LOWEST AVERAGE DELIVERY TIME. 

SELECT c.customer_state, 
ROUND(SUM(ABS(DATEDIFF(o.order_purchase_timestamp,o.order_delivered_customer_date)))/COUNT(DISTINCT o.order_id),2) AS AVG_DEL
FROM target.customers as c 
INNER JOIN target.orders as o
ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY AVG_DEL
LIMIT 5
;

-- 5.c TOP 5 STATES WITH THE HIGHEST AVERAGE FREIGHT VALUE 

SELECT c.customer_state, ROUND(AVG(oi.freight_value),2) as avg_freight_val
FROM target.order_items as oi
INNER JOIN target.orders as o
ON oi.order_id = o.order_id
INNER JOIN target.customers as c
ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY avg_freight_val DESC
LIMIT 5
;

-- 5.d TOP 5 STATES WHERE THE DELIVERY DATE IS REALLY FAST AS COMPARED TO THE ESTIMATED DELIVERY DATE.

SELECT c.customer_state,
ROUND(SUM(ABS(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)))/COUNT(DISTINCT o.order_id)) as avg_del_time,
ROUND(SUM(ABS(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)))/COUNT(DISTINCT o.order_id)) as avg_est_del_time
FROM target.customers as c
INNER JOIN target.orders as o
ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY (avg_del_time - avg_est_del_time)
LIMIT 5
;


-- 6. ANALYSIS BASED ON THE PAYMENTS 
-- 6.a  MONTH ON MONTH NO. OF ORDERS PLACED USING DIFFERENT PAYMENT METHODS 

SELECT p.payment_type,
MONTH(o.order_purchase_timestamp) as mth, YEAR(o.order_purchase_timestamp) as yr
,COUNT(DISTINCT o.order_id) as order_count
FROM target.payments as p
INNER JOIN target.orders as o
ON p.order_id = o.order_id
GROUP BY 1,2,3
ORDER BY 3,2
;

-- 6.b NO. OF ORDERS PLACED ON THE BASIS OF THE PAYMENTS INSTALLMENTS THAT HAVE BEEN PAID

SELECT payment_installments as installments ,
COUNT(DISTINCT order_id) as total_orders
FROM target.payments 
WHERE payment_installments >= 1
GROUP BY payment_installments
ORDER BY total_orders DESC;


-- ADDITIONAL QUESTIONS 

-- 1. WHAT PERCENTAGE OF ORDERS WERE CANCELLED OR UNAVAILABLE 

SELECT  ROUND(100.0*COUNT(DISTINCT CASE WHEN order_status in ('cancelled','unavailable') THEN order_id END)/COUNT(DISTINCT order_id),2) AS cancelled_pct
FROM target.orders
;

-- 2. TOP 5 CUSTOMERS

SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) as total_orders
FROM target.customers as c
INNER JOIN target.orders as o
ON c.customer_id = o.customer_id 
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY total_orders DESC
LIMIT 5
;

-- 3. AVERAGE DELIVERY TIME IN DAYS.

SELECT ROUND(SUM(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date))/COUNT(order_id),2) avg_delivery
FROM target.orders
WHERE order_status = 'delivered'
LIMIT 1
;