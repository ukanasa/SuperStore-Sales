--Total number of rows: 9800
select count(*) from train;

--Total distinct order IDs: 4922
select count(distinct "Order ID") from train; 

--Total Unique Customers: 793
select count(distinct "Customer ID") from train; 

--What is the average number of distinct orders for all customers: 6  
with subset as
(select "Customer Name", count(distinct "Order ID") as distinct_orders from train
group by "Customer Name")
select round(avg(distinct_orders)) from subset; 

--What is the average number of items ordered by all customers: 12  
with subset as 
(select "Customer Name", count("Product Name") as product_orders from train 
group by "Customer Name")
select round(avg(product_orders)) from subset;

--What is the most number of items ordered by a customer: 35 
with subset as 
(select "Customer Name", count("Product Name") as product_orders from train 
group by "Customer Name"
order by product_orders desc)
select "Customer Name", product_orders from subset
where product_orders = (select max(product_orders) from subset); 

--Top 10 Consumers with the highest purchase total 
with subset as 
(select 
dense_rank() over (order by round(sum(sales)) desc) as sales_rank,
"Customer Name",  
round(sum(sales)) as total_sales
from train 
where segment = 'Consumer'
group by "Customer Name")
select * from subset 
where sales_rank <= 10; 

--Top 10 Cities with the highest purchase total  
with subset as 
(select 
dense_rank() over (order by round(sum(sales)) desc) as sales_rank,
"city", 
round(sum(sales)) as total_sales
from train 
group by "city")
select * from subset 
where sales_rank <= 10; 

--What about the Top 10 Postal Codes? 
with subset as 
(select 
dense_rank() over (order by round(sum(sales)) desc) as sales_rank,
"city",
"Postal Code",
round(sum(sales)) as total_sales
from train 
group by "city", "Postal Code")
select * from subset 
where sales_rank <= 10; 

--Top Selling Categories?
with subset as 
(select 
dense_rank() over (order by round(sum(sales)) desc) as sales_rank,
"Sub-Category",
round(sum(sales)) as total_sales
from train 
group by "Sub-Category")
select * from subset 
where sales_rank <= 10; 

--Top 10 Underperforming Products?
with subset as 
(select 
dense_rank() over (order by round(sum(sales)) asc) as sales_rank,
"Product Name",
round(sum(sales)) as total_sales
from train 
group by "Product Name")
select * from subset 
where sales_rank <= 10; 

--Changing Ship Date and Order Date data types from varchar to timestamp 
update train 
set "Ship Date" = to_timestamp("Ship Date",'dd/mm/yyyy');
alter table train 
alter column "Ship Date" 
type TIMESTAMP without time zone
using "Ship Date"::timestamp without time zone;
update train 
set "Order Date" = to_timestamp("Order Date",'dd/mm/yyyy');
alter table train 
alter column "Order Date" 
type TIMESTAMP without time zone
using "Order Date"::timestamp without time zone;


--What is the average time to ship for all orders: 3.96 days  
with subset as (
	select max("Ship Date" - "Order Date") as ship_time 
	from train 
	group by "Order ID"
)
select round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset; 

--What about for each shipping mode? 
with subset as (
	select "Ship Mode",
	max("Ship Date" - "Order Date") as ship_time
	from train 
	group by "Order ID", "Ship Mode"
)
select "Ship Mode",
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset
group by "Ship Mode"
order by avg_ship_days asc;

--What is the minimum and maximum time to ship for each shipping mode?
select "Ship Mode",
min("Ship Date" - "Order Date") as min_ship_time,
max("Ship Date" - "Order Date") as max_ship_time
from train 
group by "Ship Mode"
order by min_ship_time, max_ship_time asc;  

--What is the breakdown of the use of shipping methods by segments: Standard Class is used the most, while Same Day is used the least  
with subset as (
	select segment, 
	"Ship Mode"
	from train
	group by segment, "Ship Mode","Order ID"
	order by segment, "Ship Mode" asc
) 
select segment, 
"Ship Mode",
count(*) as ship_mode_count,
round(100*count(*)/(sum(count(*)) over (partition by segment))) as percentage
from subset
group by segment, "Ship Mode";

--Does the order size affect shipping time? Yes
with subset as (
	select max("Ship Date" - "Order Date") as ship_time,
	count("Product ID") as order_size
	from train 
	group by "Order ID"
)
select order_size,
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset
group by order_size
order by order_size desc; 

--Does the category of a product affect shipping time: No 
with subset as (
	select max("Ship Date" - "Order Date") as ship_time,
	category,
	"Sub-Category"
	from train 
	group by "Order ID",category, "Sub-Category"
	order by category, "Sub-Category"
)
select category,
"Sub-Category",
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset
group by category, "Sub-Category"; 

--What about a breakdown of average shipping time to states?
with subset as (
	select max("Ship Date" - "Order Date") as ship_time,
	state
	from train 
	group by "Order ID", state
)
select state,
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset
group by state
order by avg_ship_days desc; 

--What about cities? Average shipping time is affected by state and city 
with subset as (
	select max("Ship Date" - "Order Date") as ship_time,
	state,
	city
	from train 
	group by "Order ID", state, city
)
select state,
city,
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days 
from subset
group by state, city
order by state, avg_ship_days desc; 

--What is the number of orders by month: September-December have the highest volume of the year 
with subset as (
	select to_char("Order Date", 'Month') as order_month
	from train 
	group by "Order ID", order_month
)
select order_month, 
count(*) 
from subset
group by order_month
order by to_date(order_month, 'Month') asc; 

--What is the average order time by month: Average days to ship is consistent year round no matter the volume! 
with subset as (
	select to_char("Order Date", 'Month') as order_month,
	max("Ship Date" - "Order Date") as ship_time
	from train 
	group by "Order ID", order_month
)
select order_month,
round(extract(epoch from avg(ship_time))/86400,2) as avg_ship_days
from subset 
group by order_month
order by to_date(order_month, 'Month') asc, avg_ship_days desc; 

--What does the average order size look like over the year: The order size is also consistent throughout the year 
with subset as (
	select to_char("Order Date", 'Month') as order_month,
	count(*) as count
	from train 
	group by "Order ID", order_month 
)
select order_month, round(avg(count),2) from subset 
group by order_month 
order by to_date(order_month, 'Month') asc























