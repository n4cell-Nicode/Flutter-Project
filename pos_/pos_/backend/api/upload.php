<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['error' => 'No image file or upload error']);
    exit();
}

$file = $_FILES['image'];
$allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mime = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);
if (!in_array($mime, $allowed)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid image type']);
    exit();
}

$ext = '.jpg';
if ($mime === 'image/png') $ext = '.png';
elseif ($mime === 'image/gif') $ext = '.gif';
elseif ($mime === 'image/webp') $ext = '.webp';
$name = bin2hex(random_bytes(8)) . $ext;
$dir = __DIR__ . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'products';
if (!is_dir($dir)) {
    mkdir($dir, 0755, true);
}
$dest = $dir . DIRECTORY_SEPARATOR . $name;
if (!move_uploaded_file($file['tmp_name'], $dest)) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to save file']);
    exit();
}

$path = 'uploads/products/' . $name;
http_response_code(201);
echo json_encode(['path' => $path]);
