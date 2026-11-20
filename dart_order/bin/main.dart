import 'dart:convert';
import 'dart:io';

import 'package:dart_order/order.dart';
import 'package:dart_order/order_repository.dart';

final repo = OrderRepository('data/order.json');

Future<void> main() async {
  await repo.load();
  print('Đã đọc ${repo.orders.length} orders:');
  repo.orders.forEach(print);

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('Server chạy tại http://localhost:${server.port}');

  await for (final request in server) {
    try {
      await handle(request);
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Lỗi: $e');
      await request.response.close();
    }
  }
}

Future<void> handle(HttpRequest req) async {
  final path = req.uri.path;

  if (req.method == 'GET' && path == '/') {
    final keyword = req.uri.queryParameters['q'] ?? '';
    final error = req.uri.queryParameters['error'];
    final list = repo.searchByItemName(keyword);
    req.response.headers.contentType = ContentType.html;
    req.response.write(renderPage(list, keyword, error));
    await req.response.close();
    return;
  }

  if (req.method == 'POST' && path == '/add') {
    final form = await readForm(req);
    try {
      final order = Order(
        item: requireText(form['item'], 'Item'),
        itemName: requireText(form['itemName'], 'Item Name'),
        price: positiveNum(form['price'], 'Price'),
        quantity: positiveNum(form['quantity'], 'Quantity', isInt: true).toInt(),
        currency: (form['currency'] ?? '').trim().isEmpty
            ? 'USD'
            : form['currency']!.trim().toUpperCase(),
      );
      await repo.insert(order);
      redirect(req, '/');
    } on ArgumentError catch (e) {
      redirect(req, Uri(path: '/', queryParameters: {'error': '${e.message}'}).toString());
    }
    return;
  }

  if (req.method == 'POST' && path == '/delete') {
    final form = await readForm(req);
    await repo.delete(form['item'] ?? '');
    redirect(req, '/');
    return;
  }

  req.response
    ..statusCode = HttpStatus.notFound
    ..write('404 Not Found');
  await req.response.close();
}

// ----------------- Helpers -----------------

Future<Map<String, String>> readForm(HttpRequest req) async {
  final body = await utf8.decoder.bind(req).join();
  return Uri.splitQueryString(body);
}

void redirect(HttpRequest req, String location) {
  req.response
    ..statusCode = HttpStatus.seeOther
    ..headers.set(HttpHeaders.locationHeader, location)
    ..close();
}

String requireText(String? value, String field) {
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('$field không được để trống');
  }
  return value.trim();
}

num positiveNum(String? value, String field, {bool isInt = false}) {
  final n = isInt ? int.tryParse(value?.trim() ?? '') : num.tryParse(value?.trim() ?? '');
  if (n == null || n <= 0) {
    throw ArgumentError('$field phải là số ${isInt ? 'nguyên ' : ''}lớn hơn 0');
  }
  return n;
}

/// 1200 -> "1.200"
String formatPrice(num p) {
  final parts = p.toStringAsFixed(p == p.roundToDouble() ? 0 : 2).split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return parts.length > 1 ? '$buf,${parts[1]}' : buf.toString();
}

String esc(String s) => const HtmlEscape().convert(s);

// ----------------- Giao diện -----------------

const trashIcon =
    '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#5b8fd6" '
    'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M4 7h16M10 11v6M14 11v6M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2l1-12M9 7V4h6v3"/></svg>';

String renderPage(List<Order> list, String keyword, String? error) {
  final rows = StringBuffer();
  for (var i = 0; i < list.length; i++) {
    final o = list[i];
    rows.write('''
      <tr>
        <td>${i + 1}</td>
        <td>${esc(o.item)}</td>
        <td>${esc(o.itemName)}</td>
        <td>${o.quantity}</td>
        <td>${formatPrice(o.price)}</td>
        <td>${esc(o.currency)}</td>
        <td class="act">
          <form method="post" action="/delete" onsubmit="return confirm('Xoá ${esc(o.item)}?')">
            <input type="hidden" name="item" value="${esc(o.item)}">
            <button class="trash" title="Xoá">$trashIcon</button>
          </form>
        </td>
      </tr>''');
  }
  if (list.isEmpty) {
    rows.write('<tr><td colspan="7" class="empty">Không tìm thấy order nào</td></tr>');
  }

  return '''
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>My Order</title>
<style>$css</style>
</head>
<body>
<div class="wrap">
  <h1>My Order</h1>

  ${error != null ? '<div class="error">${esc(error)}</div>' : ''}

  <form method="post" action="/add" class="add">
    <div class="row">
      <label>Item<input name="item" placeholder="Item" required></label>
      <label class="wide">Item Name<input name="itemName" placeholder="Item" required></label>
    </div>
    <div class="row">
      <label>Price<input name="price" type="number" min="0.01" step="any" placeholder="Price" required></label>
      <label>Quantity<input name="quantity" type="number" min="1" step="1" placeholder="Quantity" required></label>
      <label class="small">Currency<input name="currency" value="USD"></label>
    </div>
    <div class="btns"><button class="btn">Add Item to Cart</button></div>
  </form>

  <form method="get" action="/" class="search">
    <input name="q" value="${esc(keyword)}" placeholder="Search by Item Name...">
    <button class="btn">Search</button>
    ${keyword.isNotEmpty ? '<a href="/">Clear</a>' : ''}
  </form>

  <table>
    <thead>
      <tr><th>Id</th><th>Item</th><th>Item Name</th><th>Quantity</th><th>Price</th><th>Currency</th><th></th></tr>
    </thead>
    <tbody>$rows</tbody>
  </table>

  <footer>Số 8, Tôn Thất Thuyết, Cầu giấy, Hà Nội</footer>
</div>
</body>
</html>''';
}

const css = r'''
* { box-sizing: border-box; }
body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; color: #333; background: #fff; }
.wrap { max-width: 860px; margin: 0 auto; padding: 24px 16px; }
h1 { text-align: center; color: #d9a12b; font-size: 34px; margin: 0 0 20px; }
.add { padding: 0 24px; }
.row { display: flex; gap: 32px; margin-bottom: 14px; }
.row label { flex: 1; display: flex; flex-direction: column; font-size: 13px; color: #666; gap: 8px; }
.row label.wide { flex: 1.3; }
.row label.small { flex: 0.6; }
input { border: 1.5px solid #555; border-radius: 4px; padding: 9px 10px; font-size: 14px; }
input:focus { outline: none; border-color: #c96a55; }
.btns { text-align: right; }
.btn { background: #c96a55; color: #fff; border: 0; border-radius: 4px; padding: 6px 14px; cursor: pointer; font-size: 13px; }
.btn:hover { background: #b25843; }
.search { display: flex; gap: 8px; align-items: center; margin: 22px 0 12px; }
.search input { flex: 1; }
.search a { color: #c96a55; font-size: 13px; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
thead tr { background: #c96a55; color: #fff; box-shadow: 0 3px 6px rgba(0,0,0,.2); }
th { text-align: left; padding: 10px 8px; font-weight: 500; }
td { padding: 16px 8px; }
tbody tr:hover { background: #fbf1ee; }
.act { text-align: right; }
.act form { margin: 0; }
.trash { background: none; border: 0; cursor: pointer; padding: 2px; }
.empty { text-align: center; color: #999; }
.error { background: #fde8e4; color: #a33; padding: 8px 12px; border-radius: 4px; margin-bottom: 12px; }
footer { margin-top: 40px; background: #c96a55; color: #fff; font-weight: 600; font-size: 13px; padding: 10px 14px; border-radius: 6px; }
''';
