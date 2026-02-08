<?php
require_once '../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data['id']) || !isset($data['stock'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Product ID and stock required']);
    exit();
}

$id = $data['id'];
$newStock = intval($data['stock']);

try {
    $stmt = $pdo->prepare("UPDATE inventory SET stock = ? WHERE id = ?");
    $stmt->execute([$newStock, $id]);
    
    if ($stmt->rowCount() > 0) {
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Stock updated']);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Product not found']);
    }
} catch(PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to update stock: ' . $e->getMessage()]);
}
?>
