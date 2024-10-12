-- pull order and customer information

SELECT 
    strftime('%Y-%m-%d', o.order_purchase_timestamp) AS order_date, -- change timestamp to date
    o.order_id,
    o.customer_id,
    o.order_status,
    c.geolocation_city AS customer_city,
    c.geolocation_state AS customer_state,
    pa.payment_type,
    pa.payment_value,
    julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp) AS delivery_eta,
    julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp) AS delivery_act,
    MAX(r.review_score) AS max_review_score,
    oi.order_value
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id
) oi ON o.order_id = oi.order_id -- Subquery to calculate order value
LEFT JOIN order_reviews r ON o.order_id = r.order_id
LEFT JOIN (
    SELECT order_id,
           MAX(payment_type) AS payment_type,
           SUM(payment_value) AS payment_value
    FROM order_payments 
    GROUP BY order_id
) pa ON o.order_id = pa.order_id
LEFT JOIN (
    SELECT c.customer_id, g.geolocation_lat, g.geolocation_lng, g.geolocation_city, g.geolocation_state, 
           ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY g.geolocation_lat) AS row_num
    FROM customers c
    LEFT JOIN geolocation g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
) c ON o.customer_id = c.customer_id AND c.row_num = 1 -- Subquery to get the customer's location details, using row number to filter the best match
WHERE o.order_id IS NOT NULL
GROUP BY order_date, o.order_id, o.customer_id, o.order_status, 
         customer_city, customer_state,
         pa.payment_type, pa.payment_value, delivery_eta, delivery_act;

-- pull product and seller information

SELECT
    oi.order_id,  
    oi.product_id,  
    p.product_category_name_english,  
    oi.seller_id,  
    s.geolocation_city AS seller_city,  
    s.geolocation_state AS seller_state,
    SUM(oi.price) AS product_price,  
    SUM(oi.freight_value) AS freight
FROM order_items oi
LEFT JOIN (
    SELECT DISTINCT p.product_id, pc.product_category_name_english
    FROM products p
    LEFT JOIN product_category pc ON p.product_category_name = pc.product_category_name
) p ON p.product_id = oi.product_id  -- Subquery to map products to their respective categories, eliminating duplicates
LEFT JOIN (
    SELECT s.seller_id, g.geolocation_lat, g.geolocation_lng, g.geolocation_city, g.geolocation_state, 
           ROW_NUMBER() OVER (PARTITION BY s.seller_id ORDER BY g.geolocation_lat) AS row_num
    FROM sellers s
    LEFT JOIN geolocation g ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
) s ON oi.seller_id = s.seller_id AND s.row_num = 1  -- Subquery to get the seller's location details, using row number to filter the best match
GROUP BY oi.order_id, oi.product_id, oi.seller_id, seller_city, seller_state, p.product_category_name_english
 