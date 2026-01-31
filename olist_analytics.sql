
-- Overview
select * from orders;
select count(order_id) from orders;
select count(distinct order_id) from orders;
select distinct(order_status) from orders;
select * from order_items;
select * from products;
select * from category_name_translation;
select * from customers;
select * from sellers;
select sum(oi.price) as total_revenue 
from order_items oi 
join 
orders o on o.order_id= oi.order_id 
where o.order_status ='delivered';                                           -- Total revenue

select count(distinct o.order_id) as total_orders, sum(oi.price) as total_revenue from orders o join order_items oi 
on o.order_id= oi.order_id where o.order_status='delivered';                   -- Total orders vs revenue

select date_trunc('month', o.order_purchase_timestamp) as mnth, 	
sum(oi.price) as revenue from orders o join order_items oi 
on o.order_id= oi.order_id where o.order_status='delivered' group by mnth order by mnth;           -- Revenue by month
SELECT
    COUNT(*) AS total_orders,
    SUM(
        CASE 
            WHEN order_status IN ('canceled', 'unavailable') THEN 1 
            ELSE 0 
        END
    ) AS canceled_orders,
    ROUND(
        SUM(
            CASE 
                WHEN order_status IN ('canceled', 'unavailable') THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_pct
FROM orders;


-- Revenue analysis


select date_trunc('month', o.order_purchase_timestamp) as mnth,count(distinct o.order_id) as total_orders, sum(oi.price) as revenue from orders o join order_items oi 
on o.order_id= oi.order_id where o.order_status='delivered' group by mnth order by mnth;             -- Order count by month

select date_trunc('month', o.order_purchase_timestamp) as mnth, (sum(oi.price)/count(distinct o.order_id)) as AOV from orders o join order_items oi 
on o.order_id= oi.order_id where o.order_status='delivered' group by mnth;           -- AOV by month

select (sum(oi.price)/count(distinct o.order_id)) as AOV from orders o join order_items oi 
on o.order_id=oi.order_id where o.order_status='delivered';                   -- Overall AOV

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT
    month,
    revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
        / LAG(revenue) OVER (ORDER BY month),
        2
    ) AS mom_revenue_growth_pct
FROM monthly_revenue
ORDER BY month;


WITH order_revenue AS (                    -- Revenue distribution accross orders
    SELECT
        oi.order_id,
        SUM(oi.price) AS order_revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),

ranked_orders AS (
    SELECT
        order_id,
        order_revenue,
        NTILE(10) OVER (ORDER BY order_revenue DESC) AS revenue_decile
    FROM order_revenue
),

final AS (
    SELECT
        revenue_decile,
        COUNT(*) AS order_count,
        SUM(order_revenue) AS total_revenue
    FROM ranked_orders
    GROUP BY revenue_decile
)

SELECT
    revenue_decile,
    order_count,
    total_revenue,
    ROUND(
        total_revenue * 100.0 /
        SUM(total_revenue) OVER (),
        2
    ) AS revenue_pct
FROM final
ORDER BY revenue_decile;              -- Revenue distribution (top 10 percent orders amount to 41 percent of the total revenue)



SELECT
	c.customer_unique_id,
	SUM(oi.price) AS total_revenue
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
	ORDER BY total_revenue DESC LIMIT 20;									-- Top 20 Customers
	
-- Repeat Vs new Customers revenue
WITH cust_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN order_count > 1 THEN 'repeat'
        ELSE 'new'
    END AS customer_type,
    COUNT(*) AS customers,
    SUM(revenue) AS total_revenue
FROM cust_revenue
GROUP BY customer_type;

select sum(oi.price)/count(distinct customer_unique_id) as average_revenue_per_customer
from orders o join customers c
on o.customer_id=c.customer_id
join order_items oi on o.order_id=oi.order_id
where o.order_status='delivered';				-- average revenue per customer



-- TOP Categories
select pc.product_category_name_english,count(distinct o.order_id) AS total_orders
 ,sum(oi.price) as total_revenue from products p join order_items oi
on p.product_id= oi.product_id
join orders o
on o.order_id=oi.order_id
join category_name_translation pc
on p.product_category_name=pc.product_category_name
where o.order_status= 'delivered'
and pc.product_category_name_english is not null
group by pc.product_category_name_english
order by total_revenue desc
limit 20;			-- Top 20 product caregories



-- Seller level revenue
select s.seller_id, sum(oi.price) as total_revenue from 
sellers s join order_items oi 
on s.seller_id= oi.seller_id
join orders o 
on o.order_id=oi.order_id
where o.order_status='delivered'
group by s.seller_id
order by total_revenue desc;



-- Top sellers
WITH seller_revenue AS (
    SELECT
        s.seller_id,
        SUM(oi.price) AS seller_revenue
    FROM sellers s
    JOIN order_items oi
        ON s.seller_id = oi.seller_id
    JOIN orders o
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        seller_revenue,
        NTILE(10) OVER (ORDER BY seller_revenue DESC) AS revenue_decile
    FROM seller_revenue
),
final AS (
    SELECT
        revenue_decile,
        COUNT(*) AS seller_count,
        SUM(seller_revenue) AS total_revenue
    FROM ranked_sellers
    GROUP BY revenue_decile
)
SELECT
    revenue_decile,
    seller_count,
    total_revenue,
    ROUND(
        total_revenue * 100.0 /
        SUM(total_revenue) OVER (),
        2
    ) AS revenue_pct
FROM final
ORDER BY revenue_decile;	-- Top 10 sellers contributes to almost 67 percentage of the product revenue


--REVENUE LEAKGE
select sum(price) as leaked_revenue 
from order_items 
where order_id in 
(select order_id from orders where order_status in ('unavailable','canceled'));

select pc.product_category_name_english,count(distinct o.order_id) AS total_orders
 ,sum(oi.price) as revenue_loss from products p join order_items oi
on p.product_id= oi.product_id
join orders o
on o.order_id=oi.order_id
join category_name_translation pc
on p.product_category_name=pc.product_category_name
where o.order_status in ('unavailable','canceled')
and pc.product_category_name_english is not null
group by pc.product_category_name_english
order by revenue_loss desc;				-- loss by category

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS month,
        COUNT(*) AS total_orders,
        SUM(
            CASE 
                WHEN order_status IN ('canceled', 'unavailable') THEN 1 
                ELSE 0 
            END
        ) AS canceled_orders
    FROM orders
    GROUP BY month
)
SELECT
    month,
    total_orders,
    canceled_orders,
    ROUND(
        canceled_orders * 100.0 / total_orders,
        2
    ) AS cancellation_rate_pct
FROM monthly_orders
ORDER BY month;				-- Cancellations by month

--High-value orders vs cancellation
WITH order_revenue AS (
    SELECT
        o.order_id,
        o.order_status,
        SUM(oi.price) AS order_value,
        CASE 
            WHEN o.order_status IN ('canceled', 'unavailable') THEN 1 
            ELSE 0 
        END AS is_canceled
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.order_status
), value_buckets AS (
    SELECT
        *,
        NTILE(3) OVER (ORDER BY order_value desc) AS value_bucket
    FROM order_revenue
)
SELECT
    value_bucket,
    COUNT(*) AS total_orders,
    SUM(is_canceled) AS canceled_orders,
    ROUND(
        SUM(is_canceled) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_pct
FROM value_buckets
GROUP BY value_bucket
ORDER BY value_bucket; 			-- high-value orders have a higher probability of cancellation compared to other segments.


-- Funnel X Revenue

-- 1. funnel analysis
with funnel as (
select  
sum(case when order_purchase_timestamp is not null then 1 else 0 end) as purchased,
sum(case when order_approved_at is not null then 1 else 0 end) as approved,
sum(case when order_delivered_carrier_date is not null then 1 else 0 end) as shipped,
sum(case when order_delivered_customer_date is not null then 1 else 0 end) as delivered
from orders
)
SELECT
    purchased,
    approved,
    shipped,
    delivered,

    ROUND(approved * 100.0 / purchased, 2)  AS purchase_to_approval_conversion_pct,
    ROUND(shipped  * 100.0 / approved, 2)   AS approval_to_shipping_conversion_pct,
    ROUND(delivered * 100.0 / shipped, 2)   AS shipping_to_delivery_conversion_pct,

    ROUND((purchased - approved) * 100.0 / purchased, 2) AS purchase_to_approval_dropoff_pct,
    ROUND((approved - shipped)  * 100.0 / approved, 2)  AS approval_to_shipping_dropoff_pct,
    ROUND((shipped - delivered) * 100.0 / shipped, 2)   AS shipping_to_delivery_dropoff_pct
FROM funnel;

WITH order_revenue AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        COALESCE(SUM(oi.price), 0) AS order_revenue
    FROM orders o
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY
        o.order_id,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date
)
SELECT
    COUNT(order_id) AS purchased_orders,
    SUM(order_revenue) AS revenue_purchased,

    COUNT(CASE WHEN order_approved_at IS NOT NULL THEN order_id END) AS approved_orders,
    SUM(CASE WHEN order_approved_at IS NOT NULL THEN order_revenue END) AS revenue_approved,

    COUNT(CASE WHEN order_delivered_carrier_date IS NOT NULL THEN order_id END) AS shipped_orders,
    SUM(CASE WHEN order_delivered_carrier_date IS NOT NULL THEN order_revenue END) AS revenue_shipped,

    COUNT(CASE WHEN order_delivered_customer_date IS NOT NULL THEN order_id END) AS delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN order_revenue END) AS revenue_delivered
FROM order_revenue;

-- RFM Analysis
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_values AS (
    SELECT
        customer_unique_id,
        frequency,
        monetary,
        (
            (SELECT MAX(order_purchase_timestamp)::date FROM orders)
            - last_purchase_date::date
        ) AS recency
    FROM rfm_base
),
scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC)   AS r_score,   -- lower recency = higher score
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)  AS m_score
    FROM rfm_values
),
scored_rfm as (SELECT
    customer_unique_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS customer_segment
FROM scored
)
SELECT
    customer_segment,
    COUNT(*) AS customers,
    SUM(monetary) AS total_revenue,
    ROUND(SUM(monetary)*100.0/SUM(SUM(monetary)) OVER (),2) AS revenue_pct
FROM scored_rfm
GROUP BY customer_segment
ORDER BY total_revenue DESC;


