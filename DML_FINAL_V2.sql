-- DML and Query Source Code
SET search_path TO PP2;
-- ## SAMPLE INSERT
INSERT INTO Location (zip, city, state) VALUES
(75001, 'Addison', 'TX'),
(10001, 'New York', 'NY'),
(94105, 'San Francisco', 'CA'),
(13202, 'Syracuse', 'NY'),
(30301, 'Atlanta', 'GA');

INSERT INTO Customer (cust_name, cust_email, cust_phone, cust_addr, zip) VALUES
('Alice Johnson', 'alice@example.com', '1234567890', '123 Main St, Apt 4', 75001),
('Bob Smith', 'bob@example.com', '2345678901', '456 Elm St', 10001),
('Charlie Davis', 'charlie@example.com', '3456789012', '789 Oak Ave', 94105),
('Dana Lee', 'dana@example.com', '4567890123', '101 Pine Blvd', 13202),
('Eli Patel', 'eli@example.com', '5678901234', '202 Maple Ln', 30301);

INSERT INTO Product (prod_name, prod_image, prod_desc, prod_price, prod_stock, prod_sku) VALUES
('Wireless Mouse', 'mouse.jpg', 'Ergonomic wireless mouse', 25.99, 100, 'SKU001'),
('Laptop Stand', 'stand.jpg', 'Adjustable aluminum stand', 45.50, 80, 'SKU002'),
('USB-C Hub', 'hub.jpg', '7-in-1 USB-C hub', 39.99, 50, 'SKU003'),
('Bluetooth Keyboard', 'keyboard.jpg', 'Compact mechanical keyboard', 59.95, 70, 'SKU004'),
('Noise Cancelling Headphones', 'headphones.jpg', 'Over-ear wireless headphones', 120.00, 30, 'SKU005');

INSERT INTO Cart (cust_id, cart_date, cart_status, cart_tracking_id) VALUES
(1, DEFAULT, 'P', 'TRACK001'),
(2, DEFAULT, 'P', 'TRACK002'),
(3, DEFAULT, 'P', 'TRACK003'),
(4, DEFAULT, 'P', 'TRACK004'),
(5, DEFAULT, 'P', 'TRACK005');

INSERT INTO Cart_Item (cart_id, customer_id, prod_id, cart_item_qty, cart_item_notes) VALUES
(1, 1, 1, 1, 'For office use'),
(2, 2, 2, 8, NULL),
(3, 3, 3, 1, 'Include USB cable'),
(5, 5, 5, 2, NULL),
(5, 5, 5, 1, NULL),
(5, 5, 1, 3, NULL);

INSERT INTO Cart_Item (cart_id, customer_id, prod_id, cart_item_notes) 
VALUES (4, 4, 4, 'Gift wrap please');

INSERT INTO Payment (cart_id, cust_id, zip, pay_mode, pay_status, pay_date, pay_receipt) VALUES
(1, 1, 75001, 'CR', 'P', '2025-05-01', 'RCP001'),
(2, 2, 10001, 'DE', 'P', '2025-05-01', 'RCP002'),
(3, 3, 94105, 'WA', 'P', '2025-05-01', 'RCP003'),
(4, 4, 13202, 'CA', 'P', NULL, 'RCP004'),
(5, 5, 30301, 'CR', 'U', '2025-05-01', 'RCP005');

