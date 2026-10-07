import '../core/money.dart';

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
String _str(Object? value, [String fallback = '']) => value?.toString() ?? fallback;

class Staff {
  Staff.fromJson(Map<String, dynamic> j)
    : id = _str(j['id']),
      username = _str(j['username']),
      name = _str(j['name']),
      phone = j['phone'] as String?,
      role = _str(j['role'], 'staff'),
      mustChangePassword = j['mustChangePassword'] == true,
      isActive = j['isActive'] != false,
      isLocked = j['isLocked'] == true,
      lastLoginAt = _date(j['lastLoginAt']);

  final String id;
  final String username;
  final String name;
  final String? phone;
  final String role;
  final bool mustChangePassword;
  final bool isActive;
  final bool isLocked;
  final DateTime? lastLoginAt;

  bool get isAdmin => role == 'admin';

  /// Photo helper: only the products assigned to them for photos (no orders, no customers).
  bool get isPhotoHelper => role == 'photos';
}

/// Order board tabs, in display order. Keys match the API.
enum BoardTab {
  newOrders('new', 'New'),
  packing('packing', 'Packing'),
  ready('ready', 'Packed'),
  out('out', 'Out for delivery'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled'),
  unpaid('unpaid', 'Awaiting payment');

  const BoardTab(this.key, this.label);
  final String key;
  final String label;
}

class BoardSummary {
  BoardSummary.fromJson(Map<String, dynamic> j)
    : counts = {for (final e in ((j['counts'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num).toInt()},
      latestPlacedAt = _date(j['latestPlacedAt']),
      version = (j['version'] as num?)?.toInt() ?? 0,
      alertsOpen = ((j['alerts'] as Map?)?['open'] as num?)?.toInt() ?? 0,
      alertsWorst = (j['alerts'] as Map?)?['worst'] as String?;

  final Map<String, int> counts;
  final DateTime? latestPlacedAt;
  final int version;
  final int alertsOpen;
  final String? alertsWorst;

  int count(BoardTab tab) => counts[tab.key] ?? 0;
}

class OrderCard {
  OrderCard.fromJson(Map<String, dynamic> j)
    : id = _str(j['id']),
      orderNumber = _str(j['orderNumber']),
      status = _str(j['status']),
      paymentMethod = _str(j['paymentMethod']),
      paymentStatus = _str(j['paymentStatus']),
      amountDue = _str(j['amountDue'], '0.00'),
      recipientName = _str(j['recipientName']),
      phone = _str(j['phone']),
      area = _str(j['area']),
      hasNote = j['hasNote'] == true,
      itemCount = (j['itemCount'] as num?)?.toInt() ?? 0,
      placedAt = _date(j['placedAt']),
      promisedBy = _date(j['promisedBy']),
      createdAt = _date(j['createdAt']) ?? DateTime.now();

  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String amountDue;
  final String recipientName;
  final String phone;
  final String area;
  final bool hasNote;
  final int itemCount;
  final DateTime? placedAt;

  /// Delivery promised to the customer (end of that day); null on old orders.
  final DateTime? promisedBy;
  final DateTime createdAt;

  bool get isCod => paymentMethod == 'cod';
  String get shortNumber => orderNumber.split('-').last;
  bool get isOpen => !const {'delivered', 'cancelled', 'payment_failed'}.contains(status);
  bool get isLate => isOpen && promisedBy != null && DateTime.now().isAfter(promisedBy!);
}

class OrderItem {
  OrderItem.fromJson(Map<String, dynamic> j)
    : productId = (j['productId'] as num).toInt(),
      name = _str(j['name']),
      itemCode = _str(j['itemCode']),
      barcode = j['barcode'] as String?,
      unit = _str(j['unit'], 'pcs'),
      packSize = j['packSize'] as String?,
      isLoose = j['isLoose'] == true,
      imageUrl = j['imageUrl'] as String?,
      placeholderImageUrl = j['placeholderImageUrl'] as String?,
      quantity = _str(j['quantity'], '0'),
      packedQuantity = j['packedQuantity'] as String?,
      unitPrice = _str(j['unitPrice'], '0.00'),
      totalPrice = _str(j['totalPrice'], '0.00');

  final int productId;
  final String name;
  final String itemCode;
  final String? barcode;
  final String unit;
  final String? packSize;
  final bool isLoose;
  final String? imageUrl;
  /// No photo of its own yet: its category's general photo (shown labelled "Category photo").
  final String? placeholderImageUrl;
  final String quantity;
  final String? packedQuantity;
  final String unitPrice;
  final String totalPrice;

  int get quantityMilli => toMilli(quantity);
  bool get packedShort => packedQuantity != null && toMilli(packedQuantity!) < quantityMilli;
}

class HistoryEntry {
  HistoryEntry.fromJson(Map<String, dynamic> j)
    : status = _str(j['status']),
      note = j['note'] as String?,
      at = _date(j['at']) ?? DateTime.now(),
      by = _str(j['by'], 'System');

  final String status;
  final String? note;
  final DateTime at;
  final String by;
}

class NextAction {
  NextAction(this.to, this.label);
  final String to;
  final String label;
}

class OrderDetail {
  OrderDetail.fromJson(Map<String, dynamic> j)
    : id = _str(j['id']),
      orderNumber = _str(j['orderNumber']),
      status = _str(j['status']),
      paymentMethod = _str(j['paymentMethod']),
      paymentStatus = _str(j['paymentStatus']),
      subtotal = _str(j['subtotal'], '0.00'),
      deliveryFee = _str(j['deliveryFee'], '0.00'),
      totalAmount = _str(j['totalAmount'], '0.00'),
      finalAmount = j['finalAmount'] as String?,
      amountToCollect = _str(j['amountToCollect'], '0.00'),
      customerNote = j['customerNote'] as String?,
      customerName = (j['customer'] as Map?)?['name'] as String?,
      customerPhone = (j['customer'] as Map?)?['phone'] as String?,
      address = Map<String, dynamic>.from((j['deliveryAddress'] as Map?) ?? const {}),
      mapsUrl = j['mapsUrl'] as String?,
      items = [for (final i in (j['items'] as List? ?? const [])) OrderItem.fromJson(Map<String, dynamic>.from(i as Map))],
      history = [for (final h in (j['history'] as List? ?? const [])) HistoryEntry.fromJson(Map<String, dynamic>.from(h as Map))],
      refunds = [for (final r in (j['refunds'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)],
      codCollected = ((j['cod'] as Map?)?['collectedAmount']) as String?,
      cancelledReason = j['cancelledReason'] as String?,
      placedAt = _date(j['placedAt']),
      promisedBy = _date(j['promisedBy']),
      createdAt = _date(j['createdAt']) ?? DateTime.now(),
      next = (j['actions'] as Map?)?['next'] is Map
          ? NextAction(_str(((j['actions'] as Map)['next'] as Map)['to']), _str(((j['actions'] as Map)['next'] as Map)['label']))
          : null,
      canCancel = (j['actions'] as Map?)?['canCancel'] == true;

  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String subtotal;
  final String deliveryFee;
  final String totalAmount;
  final String? finalAmount;
  final String amountToCollect;
  final String? customerNote;
  final String? customerName;
  final String? customerPhone;
  final Map<String, dynamic> address;
  final String? mapsUrl;
  final List<OrderItem> items;
  final List<HistoryEntry> history;
  final List<Map<String, dynamic>> refunds;
  final String? codCollected;
  final String? cancelledReason;
  final DateTime? placedAt;
  final DateTime? promisedBy;
  final DateTime createdAt;
  final NextAction? next;
  final bool canCancel;

  bool get isCod => paymentMethod == 'cod';
  bool get isOpen => !const {'delivered', 'cancelled', 'payment_failed'}.contains(status);
  bool get isLate => isOpen && promisedBy != null && DateTime.now().isAfter(promisedBy!);
  String get billedAmount => finalAmount ?? totalAmount;
  String get recipientName => _str(address['recipientName'], customerName ?? 'Customer');
  String get phone => _str(address['phone'], customerPhone ?? '');
  String get addressText => [
    address['line1'],
    address['line2'],
    address['landmark'],
    address['city'],
    address['pincode'],
  ].where((part) => part != null && part.toString().trim().isNotEmpty).join(', ');
}

class AdminProduct {
  AdminProduct.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num).toInt(),
      name = _str(j['name']),
      nameTa = j['nameTa'] as String?,
      itemCode = _str(j['itemCode']),
      barcode = j['barcode'] as String?,
      brand = j['brand'] as String?,
      category = j['category'] as String?,
      packSize = j['packSize'] as String?,
      mrp = _str(j['mrp'], '0.00'),
      sellingPrice = _str(j['sellingPrice'], '0.00'),
      available = _str(j['available'], '0'),
      imageUrl = j['imageUrl'] as String?,
      description = j['description'] as String?,
      sortRank = (j['sortRank'] as num?)?.toInt() ?? 0,
      isActive = j['isActive'] != false;

  final int id;
  final String name;
  final String? nameTa;
  final String itemCode;
  final String? barcode;
  final String? brand;
  final String? category;
  final String? packSize;
  final String mrp;
  final String sellingPrice;
  final String available;
  final String? imageUrl;
  final String? description;
  final int sortRank;
  final bool isActive;
}

class ResultPage<T> {
  ResultPage(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
}
