<?php
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Return all transactions with items (for receipt history after app restart)
    try {
        $stmt = $pdo->query("
            SELECT id, date, total, payment_method, change_amount 
            FROM transactions ORDER BY date DESC
        ");
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $result = [];
        foreach ($rows as $row) {
            $id = $row['id'];
            $itemStmt = $pdo->prepare("
                SELECT ti.product_id AS id, i.name, ti.quantity AS qty, ti.price, ti.subtotal 
                FROM transaction_items ti 
                LEFT JOIN inventory i ON i.id = ti.product_id 
                WHERE ti.transaction_id = ?
            ");
            $itemStmt->execute([$id]);
            $items = $itemStmt->fetchAll(PDO::FETCH_ASSOC);
            $result[] = [
                'id' => $row['id'],
                'date' => (string) $row['date'],
                'total' => (int) $row['total'],
                'paymentMethod' => $row['payment_method'],
                'change' => (int) ($row['change_amount'] ?? 0),
                'items' => $items,
            ];
        }
        http_response_code(200);
        echo json_encode($result);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to load transactions: ' . $e->getMessage()]);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Save a new transaction
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['id']) || !isset($data['items']) || !isset($data['total'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Transaction ID, items, and total required']);
        exit();
    }
    
    $transactionId = $data['id'];
    $date = isset($data['date']) ? $data['date'] : date('Y-m-d H:i:s');
    $total = $data['total'];
    $paymentMethod = isset($data['paymentMethod']) ? $data['paymentMethod'] : 'Cash';
    $change = isset($data['change']) ? $data['change'] : 0;
    $items = $data['items'];
    
    try {
        // Start transaction
        $pdo->beginTransaction();
        
        // Insert transaction
        $stmt = $pdo->prepare("
            INSERT INTO transactions (id, date, total, payment_method, change_amount) 
            VALUES (?, ?, ?, ?, ?)
        ");
        $stmt->execute([$transactionId, $date, $total, $paymentMethod, $change]);
        
        // Insert transaction items
        $itemStmt = $pdo->prepare("
            INSERT INTO transaction_items (transaction_id, product_id, quantity, price, subtotal) 
            VALUES (?, ?, ?, ?, ?)
        ");
        
        foreach ($items as $item) {
            $itemStmt->execute([
                $transactionId,
                $item['id'],
                $item['qty'],
                $item['price'],
                $item['subtotal'] ?? ($item['price'] * $item['qty'])
            ]);
            
            // Update inventory stock (decrease by quantity sold)
            $updateStock = $pdo->prepare("UPDATE inventory SET stock = stock - ? WHERE id = ?");
            $updateStock->execute([$item['qty'], $item['id']]);
        }
        
        $pdo->commit();
        
        http_response_code(201);
        echo json_encode(['success' => true, 'message' => 'Transaction saved']);
    } catch(PDOException $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['error' => 'Failed to save transaction: ' . $e->getMessage()]);
    }
} else {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
}
?>
