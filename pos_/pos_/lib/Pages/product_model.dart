class Product {
  final String id;
  final String name;
  final int price;
  final int stock;
  final String category;
  final String? imagePath;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.imagePath,
  });

  // Converts API JSON into a Product object
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'],
      price: json['price'],
      stock: json['stock'],
      category: json['category'],
      imagePath: json['imagePath'] ?? json['image_path']?.toString(),
    );
  }

  // Converts Product object back to JSON (useful for updates)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }
}