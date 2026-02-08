<?php
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Get all inventory items
    try {
        $stmt = $pdo->query("SELECT id, name, price, stock, category, image_path AS imagePath FROM inventory ORDER BY name");
        $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        http_response_code(200);
        echo json_encode($products);
    } catch(PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to load inventory: ' . $e->getMessage()]);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON body']);
        exit();
    }

    // Delete first: body has id but missing any add field (so not a valid Add request)
    $hasAllAddFields = isset($data['id']) && isset($data['name']) && isset($data['price']) && isset($data['stock']) && isset($data['category']);
    if (isset($data['id']) && !$hasAllAddFields) {
        $id = $data['id'] ?? null;
        if ($id !== null && $id !== '') {
            try {
                $stmt = $pdo->prepare("DELETE FROM inventory WHERE id = ?");
                $stmt->execute([$id]);
                if ($stmt->rowCount() > 0) {
                    http_response_code(200);
                    echo json_encode(['success' => true]);
                } else {
                    http_response_code(404);
                    echo json_encode(['error' => 'Product not found']);
                }
            } catch (PDOException $e) {
                http_response_code(500);
                echo json_encode(['error' => 'Failed to delete: ' . $e->getMessage()]);
            }
            exit();
        }
    }

    // Add: POST with id, name, price, stock, category (all required)
    if (!$hasAllAddFields) {
        http_response_code(400);
        echo json_encode(['error' => 'id, name, price, stock, category required']);
        exit();
    }
    $id = $data['id'];
    $name = $data['name'];
    $price = intval($data['price']);
    $stock = intval($data['stock']);
    $category = $data['category'];
    $imagePath = $data['imagePath'] ?? $data['image_path'] ?? null;
    try {
        $stmt = $pdo->prepare("INSERT INTO inventory (id, name, price, stock, category, image_path) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$id, $name, $price, $stock, $category, $imagePath]);
        http_response_code(201);
        echo json_encode(['success' => true, 'id' => $id]);
    } catch (PDOException $e) {
        if ($e->getCode() == 23000) {
            http_response_code(409);
            echo json_encode(['error' => 'Product ID already exists']);
        } else {
            http_response_code(500);
            echo json_encode(['error' => 'Failed to add product: ' . $e->getMessage()]);
        }
    }
    exit();
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
?>
