import 'dart:convert';
import 'dart:io';

import 'order.dart';

/// Chuỗi JSON ban đầu theo đề bài
const String initialJson =
    '[{"Item": "A1000","ItemName": "Iphone 15","Price": 1200,"Currency": "USD","Quantity":1},'
    '{"Item": "A1001","ItemName": "Iphone 16","Price": 1500,"Currency": "USD","Quantity":1}]';

/// Đọc chuỗi JSON -> List<Order>
List<Order> parseOrders(String jsonString) {
  final List<dynamic> data = jsonDecode(jsonString);
  return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
}

/// Quản lý danh sách orders và file order.json
class OrderRepository {
  final File file;
  List<Order> orders = [];

  OrderRepository(String path) : file = File(path);

  /// Nếu order.json chưa có thì tạo từ chuỗi đề bài, sau đó đọc vào list
  Future<void> load() async {
    if (!await file.exists()) {
      orders = parseOrders(initialJson);
      await save();
    } else {
      final content = await file.readAsString();
      orders = content.trim().isEmpty ? [] : parseOrders(content);
    }
  }

  /// Ghi toàn bộ list orders ra order.json
  Future<void> save() async {
    const encoder = JsonEncoder.withIndent('  ');
    await file.create(recursive: true);
    await file.writeAsString(
        encoder.convert(orders.map((o) => o.toJson()).toList()));
  }

  /// Thêm 1 order (mã Item không được trùng)
  Future<void> insert(Order order) async {
    if (orders.any((o) => o.item.toLowerCase() == order.item.toLowerCase())) {
      throw ArgumentError('Item "${order.item}" đã tồn tại');
    }
    orders.add(order);
    await save();
  }

  /// Xoá order theo mã Item
  Future<void> delete(String item) async {
    orders.removeWhere((o) => o.item == item);
    await save();
  }

  /// Tìm order theo ItemName (không phân biệt hoa thường, chứa chuỗi)
  List<Order> searchByItemName(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return orders;
    return orders.where((o) => o.itemName.toLowerCase().contains(k)).toList();
  }
}
