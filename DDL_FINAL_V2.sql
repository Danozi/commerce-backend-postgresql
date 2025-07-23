-- Create new schema and set it as active
CREATE SCHEMA IF NOT EXISTS PP2;
SET search_path TO PP2;

---------------------------------------------------------
-- DROP TABLES
DROP TABLE IF EXISTS Cart_Item CASCADE;
DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Cart CASCADE;
DROP TABLE IF EXISTS Product CASCADE;
DROP TABLE IF EXISTS Customer CASCADE;
DROP TABLE IF EXISTS Location CASCADE;

----------------------------------------------------------
-- DROP VIEWS
DROP VIEW IF EXISTS ProductStock CASCADE;

----------------------------------------------------------
-- DROP TRIGGERS
DROP TRIGGER IF EXISTS trg_check_product_stock on Cart_Item;
DROP TRIGGER IF EXISTS trg_reduce_product_stock on Cart_Item;
DROP TRIGGER IF EXISTS trg_restore_stock on Cart_Item;
DROP TRIGGER IF EXISTS trg_update_cart_amount on Cart_Item;
DROP TRIGGER IF EXISTS trg_validate_pay_date on Payment;
DROP TRIGGER IF EXISTS trg_update_cart_item_price on Cart_Item;
DROP TRIGGER IF EXISTS trg_update_final_price on Cart_Item;
DROP TRIGGER IF EXISTS trg_update_final_price_payment on Payment;

----------------------------------------------------------
-- CREATE TABLES
-- Location table
CREATE TABLE Location (
    zip INTEGER PRIMARY KEY,
    city VARCHAR(30) NOT NULL,
    state VARCHAR(2) NOT NULL -- contains only state code
);

-- Customer table
CREATE TABLE Customer 
(	
	cust_id SERIAL PRIMARY KEY,
    cust_name VARCHAR(100) NOT NULL,
    cust_email VARCHAR(100) UNIQUE NOT NULL, -- same email cannot be used by multiple users / used for login
    cust_phone VARCHAR(12) NOT NULL, -- same mobile cannot be used by multiple users
    cust_addr TEXT NOT NULL, 
    zip INTEGER NOT NULL REFERENCES Location(zip)
);

-- Product table
CREATE TABLE Product 
(
    prod_id SERIAL PRIMARY KEY,
    prod_name VARCHAR(200) NOT NULL,
    prod_image TEXT NOT NULL,
    prod_desc TEXT NOT NULL,
    prod_price NUMERIC(10,2) NOT NULL CHECK (prod_price >= 0), -- price cannot be negative
    prod_stock INTEGER CHECK (prod_stock >= 0), -- stock can be null. However, if defined it cannot be -ve
    prod_sku VARCHAR(50)NOT NULL UNIQUE -- No 2 products can have same SKU
);

-- Cart table
CREATE TABLE Cart 
(
    cart_id SERIAL PRIMARY KEY,
    cust_id INTEGER NOT NULL REFERENCES Customer(cust_id) ON DELETE CASCADE, -- on delete cascade ensures that the cart entry is deleted if the customer is deleted
    cart_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cart_amount >= 0),
    cart_date DATE DEFAULT CURRENT_DATE, -- set date as current date by default if no date is provided during row creation
    cart_status VARCHAR(1) NOT NULL CHECK (cart_status IN('P', 'S', 'C')), -- [P]:Pending [S]:Shipped [C]:Cancelled
    cart_tracking_id VARCHAR(50) UNIQUE
);

-- Payment Table
CREATE TABLE Payment (
    pay_id SERIAL PRIMARY KEY,
    cart_id INTEGER NOT NULL REFERENCES Cart(cart_id) ON DELETE CASCADE,
    cust_id INTEGER NOT NULL REFERENCES Customer(cust_id) ON DELETE CASCADE,
    zip INTEGER NOT NULL REFERENCES Location(zip) ON DELETE CASCADE,
    pay_mode VARCHAR(2) NOT NULL CHECK (pay_mode IN('CR', 'DE', 'WA', 'CA')),
    pay_status VARCHAR(1) NOT NULL CHECK (pay_status IN('U', 'P')),
    pay_date DATE,
    pay_tax NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (pay_tax >= 0),
    pay_final NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (pay_final >= 0),
    pay_receipt TEXT UNIQUE
);

-- Cart_Item table
CREATE TABLE Cart_Item 
(
    cart_item_id SERIAL PRIMARY KEY,
    cart_id INTEGER NOT NULL REFERENCES Cart(cart_id) ON DELETE CASCADE,
	customer_id INTEGER NOT NULL REFERENCES Customer(cust_id) ON DELETE CASCADE,
    prod_id INTEGER NOT NULL REFERENCES Product(prod_id) ON DELETE CASCADE,
    cart_item_qty INTEGER NOT NULL DEFAULT 1 CHECK (cart_item_qty > 0),
    cart_item_notes TEXT,
    cart_item_date_added DATE DEFAULT CURRENT_DATE,
    cart_item_final_price NUMERIC(10,2) DEFAULT 0 CHECK (cart_item_final_price >= 0)
);

----------------------------------------------------------
-- CREATE VIEWS
-- ProductStock
-- The ProductStock view will be used to quickly access information on inventory and pricing 
CREATE OR REPLACE VIEW ProductStock AS
SELECT prod_id, prod_name, prod_stock, prod_price
FROM Product;

----------------------------------------------------------------------------------------------
-- ## FUNCTIONS & TRIGGERS
-- 1. Prevent adding cart item if stock is insufficient
CREATE OR REPLACE FUNCTION check_product_stock()
RETURNS TRIGGER AS $$
DECLARE
    current_stock INTEGER;
	name TEXT;
BEGIN
	SELECT prod_stock INTO current_stock FROM Product WHERE prod_id = NEW.prod_id;
	SELECT prod_name INTO name FROM product WHERE prod_id = NEW.prod_id;
	
    -- Restores product stock in case of update before check --	
	IF TG_OP = 'UPDATE' THEN
		current_stock = current_stock + OLD.cart_item_qty;
	END IF;
	
    IF current_stock IS NULL OR current_stock < NEW.cart_item_qty THEN
        RAISE EXCEPTION 'Insufficient stock for % (Product ID: %), available: %, requested: %',
            name, NEW.prod_id, current_stock, NEW.cart_item_qty;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cart_item table --
CREATE TRIGGER trg_check_product_stock
BEFORE INSERT OR UPDATE ON Cart_Item
FOR EACH ROW
EXECUTE FUNCTION check_product_stock();


-- 2. Subtract stock when item is added to cart
CREATE OR REPLACE FUNCTION reduce_product_stock()
RETURNS TRIGGER AS $$
DECLARE
	current_stock INTEGER;
BEGIN
	SELECT prod_stock INTO current_stock FROM Product WHERE prod_id = NEW.prod_id;

	-- Sets stock if updating an order --
	IF TG_OP = 'UPDATE' THEN
		current_stock = current_stock + OLD.cart_item_qty;
	END IF;
	
    UPDATE product
    SET prod_stock = current_stock - NEW.cart_item_qty
    WHERE prod_id = NEW.prod_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cart_item table --
CREATE TRIGGER trg_reduce_product_stock
AFTER INSERT OR UPDATE ON Cart_Item
FOR EACH ROW
EXECUTE FUNCTION reduce_product_stock();


-- 3. Restore stock when cart item is deleted
CREATE OR REPLACE FUNCTION restore_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE product
    SET prod_stock = prod_stock + OLD.cart_item_qty
    WHERE prod_id = OLD.prod_id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cart_item table --
CREATE TRIGGER trg_restore_stock
AFTER DELETE ON Cart_Item
FOR EACH ROW
EXECUTE FUNCTION restore_stock();



-- 4. Update cart total when items are added/updated/removed
CREATE OR REPLACE FUNCTION update_cart_amount()
RETURNS TRIGGER AS $$
DECLARE
	target_cart INTEGER;
BEGIN
	-- Use OLD.cart_id for deletions --
	IF TG_OP =  'DELETE' THEN 
		target_cart := OLD.cart_id;
	ELSE
		target_cart := NEW.cart_id;
	END IF;
	
    UPDATE Cart
    SET cart_amount = (
        SELECT 
			COALESCE(SUM(cart_item_final_price),0)
		FROM 
			cart_item
		WHERE 
			cart_id = target_cart
	)
	WHERE cart_id = target_cart;
	
	IF TG_OP = 'DELETE' THEN
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
  
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cart_item table --
CREATE TRIGGER trg_update_cart_amount
AFTER INSERT OR UPDATE OR DELETE ON Cart_Item
FOR EACH ROW
EXECUTE FUNCTION update_cart_amount();


-- 5. Validate pay_date logic based on pay_mode
CREATE OR REPLACE FUNCTION validate_pay_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pay_mode = 'CA' AND NEW.pay_date IS NOT NULL THEN
        RAISE EXCEPTION 'Cash payments should not have a payment date';
    ELSIF NEW.pay_mode <> 'CA' AND NEW.pay_date IS NULL THEN
        RAISE EXCEPTION 'Non-cash payments must have a payment date';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to payment table --
CREATE TRIGGER trg_validate_pay_date
BEFORE INSERT OR UPDATE ON Payment
FOR EACH ROW
EXECUTE FUNCTION validate_pay_date();



-- 6. Sets the cart_item_final_price to the value of the quantity multiplied by the unit price
CREATE OR REPLACE FUNCTION update_cart_item_price()
RETURNS TRIGGER AS $$
BEGIN
   NEW.cart_item_final_price := NEW.cart_item_qty * 
		(SELECT prod_price FROM product WHERE prod_id = NEW.prod_id);
  
  RETURN NEW;  
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to cart_item table --
CREATE TRIGGER trg_update_cart_item_price
BEFORE INSERT OR UPDATE ON Cart_Item
FOR EACH ROW
EXECUTE FUNCTION update_cart_item_price();


-- 7. Updates final price to reflect the current items in the cart --
CREATE OR REPLACE FUNCTION update_final_price()
RETURNS TRIGGER AS $$
DECLARE
    target_cart_id INTEGER;
    cart_amt NUMERIC := 0;
    tax NUMERIC := 0;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_cart_id := OLD.cart_id;
    ELSE
        target_cart_id := NEW.cart_id;
    END IF;

    SELECT COALESCE(cart_amount, 0) INTO cart_amt
    FROM cart WHERE cart_id = target_cart_id;

    tax := ROUND(cart_amt * 0.0825, 2);

    UPDATE payment
    SET 
        pay_tax = ROUND(tax, 2),
        pay_final = cart_amt + tax
    WHERE cart_id = target_cart_id;

    
    RETURN NEW;
  
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to Cart_Item table --
CREATE TRIGGER trg_update_final_price
AFTER INSERT OR UPDATE OR DELETE ON Cart_Item 
FOR EACH ROW
EXECUTE FUNCTION update_final_price();

-- Apply trigger to Payment table --
CREATE TRIGGER trg_update_final_price_payment
AFTER INSERT ON Payment
FOR EACH ROW
EXECUTE FUNCTION update_final_price();

