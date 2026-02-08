<?php
require_once '../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data['id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Product ID required']);
    exit();
}

$id = $data['id'];
$name = $data['name'] ?? '';
$price = intval($data['price'] ?? 0);
$stock = intval($data['stock'] ?? 0);
$category = $data['category'] ?? '';
$imagePath = $data['imagePath'] ?? $data['image_path'] ?? null;

// COALESCE: when imagePath is null, keep existing image_path; otherwise set it
try {
    $stmt = $pdo->prepare("
        UPDATE inventory 
        SET name = ?, price = ?, stock = ?, category = ?, image_path = COALESCE(?, image_path)
        WHERE id = ?
    ");
    $stmt->execute([$name, $price, $stock, $category, $imagePath, $id]);

    if ($stmt->rowCount() > 0) {
        http_response_code(200);
        echo json_encode(['success' => true]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Product not found']);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to update: ' . $e->getMessage()]);
}
?>
