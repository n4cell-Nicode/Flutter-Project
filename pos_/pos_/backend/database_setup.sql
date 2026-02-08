-- Create database
CREATE DATABASE IF NOT EXISTS pos_db;
USE pos_db;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'cashier') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory table
CREATE TABLE IF NOT EXISTS inventory (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    category VARCHAR(50) NOT NULL,
    image_path VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id VARCHAR(100) PRIMARY KEY,
    date DATETIME NOT NULL,
    total INT NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    change_amount INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory changes log (Admin Change History)
CREATE TABLE IF NOT EXISTS inventory_changes (
    id VARCHAR(100) PRIMARY KEY,
    action VARCHAR(20) NOT NULL,
    item_id VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    details TEXT,
    date_str VARCHAR(20) NOT NULL,
    time_str VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created (created_at)
);

-- Transaction items table
CREATE TABLE IF NOT EXISTS transaction_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    price INT NOT NULL,
    subtotal INT NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES inventory(id),
    INDEX idx_transaction (transaction_id)
);

-- Insert sample users
INSERT INTO users (username, password, role) VALUES
('admin', 'admin', 'admin'),
('cashier', 'cashier', 'cashier')
ON DUPLICATE KEY UPDATE username=username;

-- Insert sample inventory (match main.dart seed so Admin and Cashier lists align)
INSERT INTO inventory (id, name, price, stock, category, image_path) VALUES
('1000000', 'Aice Mochi', 5000, 20, 'FOOD', 'mochi.png'),
('1000001', 'FT Blackcurrrant', 3000, 30, 'DRINKS', 'tea.png'),
('1000002', 'Kanzleer Original', 7000, 15, 'FOOD', 'soscis.png'),
('1000003', 'Teh Botol', 4500, 40, 'DRINKS', 'teasoro.png'),
('1000004', 'Minyak telon MB', 15000, 10, 'THINGS', 'babyoil.png'),
('1000005', 'Cussons baby powder', 15000, 10, 'THINGS', 'baby.png'),
('1000006', 'Maerina Body Lotion', 15000, 10, 'THINGS', 'bodyl.png'),
('1000007', 'Cimory Cashew', 15000, 10, 'DRINKS', 'cimory.png'),
('1000008', 'Cadbury Chocholate', 15000, 10, 'FOOD', 'dairymilk.png'),
('1000009', 'Cornetto Ice Cream', 15000, 10, 'DRINKS', 'ice.png'),
('1000010', 'Kinderjoy ', 15000, 10, 'FOOD', 'kinderjoy.png'),
('1000011', 'Pucuk harum', 15000, 10, 'DRINKS', 'pucuk.png')
ON DUPLICATE KEY UPDATE name=VALUES(name), price=VALUES(price), stock=VALUES(stock), category=VALUES(category), image_path=VALUES(image_path);
