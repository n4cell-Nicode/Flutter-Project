<?php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Prefer JSON body (POST); fallback to query string (DELETE)
$id = null;
$input = json_decode(file_get_contents('php://input'), true);
if (is_array($input) && isset($input['id'])) {
    $id = $input['id'];
}
if ($id === null) {
    $id = $_GET['id'] ?? null;
}

if (empty($id)) {
    http_response_code(400);
    echo json_encode(['error' => 'Product id required']);
    exit();
}

try {
    $stmt = $pdo->prepare("DELETE FROM inventory WHERE id = ?");
    $stmt->execute([$id]);
    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Product not found']);
        exit();
    }
    http_response_code(200);
    echo json_encode(['success' => true]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to delete product: ' . $e->getMessage()]);
}
