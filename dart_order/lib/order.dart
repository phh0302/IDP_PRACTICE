/// Class Order - đại diện cho 1 đơn hàng trong order.json
class Order {
  String item; // Mã hàng, vd: A1000
  String itemName; // Tên hàng, vd: Iphone 15
  num price; // Giá
  String currency; // Đơn vị tiền tệ, vd: USD
  int quantity; // Số lượng

  Order({
    required this.item,
    required this.itemName,
    required this.price,
    required this.currency,
    required this.quantity,
  });

  /// Tạo Order từ 1 Map JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      item: json['Item'].toString(),
      itemName: json['ItemName'].toString(),
      price: json['Price'] as num,
      currency: json['Currency'].toString(),
      quantity: (json['Quantity'] as num).toInt(),
    );
  }

  /// Chuyển Order thành Map để ghi ra JSON (giữ đúng tên key như đề bài)
  Map<String, dynamic> toJson() => {
        'Item': item,
        'ItemName': itemName,
        'Price': price,
        'Currency': currency,
        'Quantity': quantity,
      };

  @override
  String toString() =>
      'Order($item, $itemName, $price $currency, x$quantity)';
}
