<?php
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Return all inventory change logs (for Admin Change History / Reports)
    try {
        $stmt = $pdo->query("
            SELECT id, action, item_id AS itemId, item_name AS itemName, details, date_str AS date, time_str AS time, created_at
            FROM inventory_changes ORDER BY created_at DESC
        ");
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as &$row) {
            $row['itemId'] = $row['itemId'] ?? $row['item_id'] ?? '';
            $row['itemName'] = $row['itemName'] ?? $row['item_name'] ?? '';
            $row['date'] = $row['date'] ?? $row['date_str'] ?? '';
            $row['time'] = $row['time'] ?? $row['time_str'] ?? '';
        }
        http_response_code(200);
        echo json_encode($rows);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to load inventory changes: ' . $e->getMessage()]);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Save a new inventory change log entry
    $data = json_decode(file_get_contents('php://input'), true);

    if (!isset($data['action']) || !isset($data['itemId']) || !isset($data['itemName'])) {
        http_response_code(400);
        echo json_encode(['error' => 'action, itemId, and itemName required']);
        exit();
    }

    $id = isset($data['id']) ? $data['id'] : uniqid('log_', true);
    $action = $data['action'];
    $itemId = $data['itemId'];
    $itemName = $data['itemName'];
    $details = isset($data['details']) ? $data['details'] : '';
    $dateStr = isset($data['date']) ? $data['date'] : date('d M Y');
    $timeStr = isset($data['time']) ? $data['time'] : date('H:i:s');

    try {
        $stmt = $pdo->prepare("
            INSERT INTO inventory_changes (id, action, item_id, item_name, details, date_str, time_str)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([$id, $action, $itemId, $itemName, $details, $dateStr, $timeStr]);
        http_response_code(201);
        echo json_encode(['success' => true, 'id' => $id]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to save inventory change: ' . $e->getMessage()]);
    }
    exit();
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
?>
