import '../core/money.dart';

T? _opt<T>(Object? v) => v is T ? v : null;
String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;
List<Map<String, dynamic>> _list(Object? v) => (v as List? ?? const []).cast<Map<String, dynamic>>();

class AppUser {
  AppUser({required this.id, required this.phone, this.name, this.email, required this.profileComplete});
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final bool profileComplete;

  /// "919876543210" → "+91 98765 43210"
  String get displayPhone =>
      phone.length == 12 ? '+91 ${phone.substring(2, 7)} ${phone.substring(7)}' : phone;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _str(j['id']),
        phone: _str(j['phone']),
        name: _opt<String>(j['name']),
        email: _opt<String>(j['email']),
        profileComplete: j['profileComplete'] == true,
      );
}

enum StockStatus { inStock, lowStock, outOfStock }

class Product {
  Product({
    required this.id,
    required this.slug,
    required this.name,
    this.brand,
    this.categoryId,
    required this.mrp,
    required this.sellingPrice,
    required this.discountPercent,
    required this.unit,
    this.packSize,
    required this.isLoose,
    required this.minMilli,
    required this.stepMilli,
    required this.maxMilli,
    required this.stockStatus,
    this.imageUrl,
    this.description,
    this.gstRate,
    this.breadcrumb = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String? brand;
  final int? categoryId;
  final String mrp;
  final String sellingPrice;
  final int discountPercent;
  final String unit;
  final String? packSize;
  final bool isLoose;
  final int minMilli;
  final int stepMilli;
  final int maxMilli;
  final StockStatus stockStatus;
  final String? imageUrl;
  final String? description;
  final String? gstRate;
  final List<CategoryRef> breadcrumb;

  bool get canBuy => maxMilli > 0;
  bool get hasDiscount => discountPercent > 0;

  /// Label under the name: "500 g", "per kg", "1 pc".
  String get sizeLabel => packSize ?? (isLoose ? 'per $unit' : '1 $unit');

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        slug: _str(j['slug']),
        name: _str(j['name']),
        brand: _opt<String>(j['brand']),
        categoryId: _opt<int>(j['categoryId']),
        mrp: _str(j['mrp'], '0'),
        sellingPrice: _str(j['sellingPrice'], '0'),
        discountPercent: _opt<int>(j['discountPercent']) ?? 0,
        unit: _str(j['unit'], 'pcs'),
        packSize: _opt<String>(j['packSize']),
        isLoose: j['isLoose'] == true,
        minMilli: toMilli(_str(j['minOrderQty'], '1')),
        stepMilli: toMilli(_str(j['qtyStep'], '1')),
        maxMilli: toMilli(_str(j['maxPurchasableQty'], '0')),
        stockStatus: switch (j['stockStatus']) {
          'low_stock' => StockStatus.lowStock,
          'out_of_stock' => StockStatus.outOfStock,
          _ => StockStatus.inStock,
        },
        imageUrl: _opt<String>(j['imageUrl']),
        description: _opt<String>(j['description']),
        gstRate: _opt<String>(j['gstRate']),
        breadcrumb: _list(j['breadcrumb']).map(CategoryRef.fromJson).toList(),
      );
}

class CategoryRef {
  CategoryRef({required this.id, required this.name, required this.slug});
  final int id;
  final String name;
  final String slug;
  factory CategoryRef.fromJson(Map<String, dynamic> j) => CategoryRef(id: j['id'] as int, name: _str(j['name']), slug: _str(j['slug']));
}

class Category {
  Category({required this.id, required this.name, required this.slug, this.imageUrl, required this.productCount, required this.children});
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int productCount;
  final List<Category> children;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        name: _str(j['name']),
        slug: _str(j['slug']),
        imageUrl: _opt<String>(j['imageUrl']),
        productCount: _opt<int>(j['productCount']) ?? 0,
        children: _list(j['children']).map(Category.fromJson).toList(),
      );
}

class ProductPage {
  ProductPage({required this.items, this.nextCursor});
  final List<Product> items;
  final String? nextCursor;
  factory ProductPage.fromJson(Map<String, dynamic> j) =>
      ProductPage(items: _list(j['items']).map(Product.fromJson).toList(), nextCursor: _opt<String>(j['nextCursor']));
}

enum LineIssue { unavailable, outOfStock, exceedsStock, invalidQuantity }

class CartLine {
  CartLine({required this.product, required this.qtyMilli, required this.lineTotal, required this.lineMrpTotal, this.issue, this.suggestedMilli});
  final Product product;
  final int qtyMilli;
  final String lineTotal;
  final String lineMrpTotal;
  final LineIssue? issue;
  final int? suggestedMilli;

  String? get issueText => switch (issue) {
        LineIssue.unavailable => 'No longer available',
        LineIssue.outOfStock => 'Out of stock',
        LineIssue.exceedsStock => 'Only ${formatQty(suggestedMilli ?? 0, product.unit)} available',
        LineIssue.invalidQuantity => 'Please update the quantity',
        null => null,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        product: Product.fromJson(j['product'] as Map<String, dynamic>),
        qtyMilli: toMilli(_str(j['quantity'], '0')),
        lineTotal: _str(j['lineTotal'], '0'),
        lineMrpTotal: _str(j['lineMrpTotal'], '0'),
        issue: switch (j['issue']) {
          'unavailable' => LineIssue.unavailable,
          'out_of_stock' => LineIssue.outOfStock,
          'exceeds_stock' => LineIssue.exceedsStock,
          'invalid_quantity' => LineIssue.invalidQuantity,
          _ => null,
        },
        suggestedMilli: j['suggestedQuantity'] is String ? toMilli(j['suggestedQuantity'] as String) : null,
      );
}

class Cart {
  Cart({required this.lines, required this.itemCount, required this.subtotal, required this.mrpTotal, required this.savings, required this.hasIssues});
  final List<CartLine> lines;
  final int itemCount;
  final String subtotal;
  final String mrpTotal;
  final String savings;
  final bool hasIssues;

  static final empty = Cart(lines: const [], itemCount: 0, subtotal: '0.00', mrpTotal: '0.00', savings: '0.00', hasIssues: false);

  int qtyFor(int productId) => lines.firstWhere((l) => l.product.id == productId, orElse: () => _none).qtyMilli;
  static final _none = CartLine(product: Product.fromJson(const {'id': -1, 'minOrderQty': '1', 'qtyStep': '1', 'maxPurchasableQty': '0'}), qtyMilli: 0, lineTotal: '0', lineMrpTotal: '0');

  factory Cart.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map<String, dynamic>?) ?? const {};
    return Cart(
      lines: _list(j['items']).map(CartLine.fromJson).toList(),
      itemCount: _opt<int>(s['itemCount']) ?? 0,
      subtotal: _str(s['subtotal'], '0.00'),
      mrpTotal: _str(s['mrpTotal'], '0.00'),
      savings: _str(s['savings'], '0.00'),
      hasIssues: s['hasIssues'] == true,
    );
  }
}

class Address {
  Address({
    required this.id,
    this.label,
    required this.recipientName,
    required this.phone,
    required this.pincode,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.state,
    this.latitude,
    this.longitude,
    required this.isDefault,
    required this.serviceable,
  });

  final String id;
  final String? label;
  final String recipientName;
  final String phone;
  final String pincode;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String state;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final bool serviceable;

  String get title => label ?? 'Home';
  String get oneLine => [line1, line2, landmark, '$city – $pincode'].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: _str(j['id']),
        label: _opt<String>(j['label']),
        recipientName: _str(j['recipientName']),
        phone: _str(j['phone']),
        pincode: _str(j['pincode']),
        line1: _str(j['line1']),
        line2: _opt<String>(j['line2']),
        landmark: _opt<String>(j['landmark']),
        city: _str(j['city']),
        state: _str(j['state']),
        latitude: j['latitude'] == null ? null : double.tryParse(j['latitude'].toString()),
        longitude: j['longitude'] == null ? null : double.tryParse(j['longitude'].toString()),
        isDefault: j['isDefault'] == true,
        serviceable: j['serviceable'] == true,
      );
}

class Blocker {
  Blocker(this.reason, this.raw);
  final String reason;
  final Map<String, dynamic> raw;

  String get message => switch (reason) {
        'store_paused' => _str(raw['message'], "We're not taking orders right now. Please try again later."),
        'cart_empty' => 'Your cart is empty',
        'cart_needs_review' => 'Some items in your cart changed. Please review your cart.',
        'address_not_serviceable' => raw['why'] == 'out_of_range'
            ? 'This address is ${raw['distanceKm']} km away — we deliver within ${raw['maxDistanceKm']} km.'
            : "We don't deliver to this pincode yet.",
        'below_minimum' => 'Add ${formatRupees(_str(raw['shortBy'], '0'))} more to reach the minimum order.',
        _ => 'Please review your order.',
      };
}

class Quote {
  Quote({
    required this.subtotal,
    required this.mrpTotal,
    required this.savings,
    required this.deliveryFee,
    required this.freeDeliveryApplied,
    required this.total,
    this.distanceKm,
    this.freeDeliveryAbove,
    this.freeDeliveryShortBy,
    required this.codAvailable,
    required this.onlineAvailable,
    required this.canPlaceOrder,
    required this.blockers,
    required this.lines,
  });

  final String subtotal;
  final String mrpTotal;
  final String savings;
  final String deliveryFee;
  final bool freeDeliveryApplied;
  final String total;
  final double? distanceKm;
  final String? freeDeliveryAbove;
  final String? freeDeliveryShortBy;
  final bool codAvailable;
  final bool onlineAvailable;
  final bool canPlaceOrder;
  final List<Blocker> blockers;
  final List<CartLine> lines;

  factory Quote.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>;
    final d = j['delivery'] as Map<String, dynamic>? ?? const {};
    final m = j['paymentMethods'] as Map<String, dynamic>? ?? const {};
    return Quote(
      subtotal: _str(t['subtotal'], '0'),
      mrpTotal: _str(t['mrpTotal'], '0'),
      savings: _str(t['savings'], '0'),
      deliveryFee: _str(t['deliveryFee'], '0'),
      freeDeliveryApplied: t['freeDeliveryApplied'] == true,
      total: _str(t['total'], '0'),
      distanceKm: (d['distanceKm'] as num?)?.toDouble(),
      freeDeliveryAbove: _opt<String>(d['freeDeliveryAbove']),
      freeDeliveryShortBy: _opt<String>(j['freeDeliveryShortBy']),
      codAvailable: m['cod'] == true,
      onlineAvailable: m['online'] == true,
      canPlaceOrder: j['canPlaceOrder'] == true,
      blockers: _list(j['blockers']).map((b) => Blocker(_str(b['reason']), b)).toList(),
      lines: _list(j['items']).map(CartLine.fromJson).toList(),
    );
  }
}

class OrderItem {
  OrderItem({required this.productId, required this.name, required this.unit, required this.quantity, required this.unitPrice, required this.totalPrice, required this.mrp});
  final int productId;
  final String name;
  final String unit;
  final String quantity;
  final String unitPrice;
  final String totalPrice;
  final String mrp;
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: j['productId'] as int,
        name: _str(j['name']),
        unit: _str(j['unit'], 'pcs'),
        quantity: _str(j['quantity'], '1'),
        unitPrice: _str(j['unitPrice'], '0'),
        totalPrice: _str(j['totalPrice'], '0'),
        mrp: _str(j['mrp'], '0'),
      );
}

class StatusEvent {
  StatusEvent({required this.status, this.note, required this.at});
  final String status;
  final String? note;
  final DateTime at;
  factory StatusEvent.fromJson(Map<String, dynamic> j) =>
      StatusEvent(status: _str(j['status']), note: _opt<String>(j['note']), at: DateTime.parse(_str(j['at'])).toLocal());
}

class Order {
  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.address,
    required this.canCancel,
    required this.createdAt,
    this.reservationExpiresAt,
    this.itemCount = 0,
    this.items = const [],
    this.history = const [],
  });

  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String subtotal;
  final String deliveryFee;
  final String totalAmount;
  final Map<String, dynamic> address;
  final bool canCancel;
  final DateTime createdAt;
  final DateTime? reservationExpiresAt;
  final int itemCount;
  final List<OrderItem> items;
  final List<StatusEvent> history;

  bool get isCod => paymentMethod == 'cod';
  bool get awaitingPayment => status == 'pending_payment';
  bool get isClosed => status == 'cancelled' || status == 'payment_failed' || status == 'delivered';

  String get statusLabel => switch (status) {
        'pending_payment' => 'Awaiting payment',
        'placed' => 'Ordered',
        'confirmed' => 'Confirmed',
        'packing' => 'Packing',
        'ready_for_delivery' => 'Packed',
        'out_for_delivery' => 'Out for delivery',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        'payment_failed' => 'Payment failed',
        _ => status,
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _str(j['id']),
        orderNumber: _str(j['orderNumber']),
        status: _str(j['status']),
        paymentStatus: _str(j['paymentStatus']),
        paymentMethod: _str(j['paymentMethod']),
        subtotal: _str(j['subtotal'], '0'),
        deliveryFee: _str(j['deliveryFee'], '0'),
        totalAmount: _str(j['totalAmount'], '0'),
        address: (j['deliveryAddress'] as Map<String, dynamic>?) ?? const {},
        canCancel: j['canCancel'] == true,
        createdAt: DateTime.parse(_str(j['createdAt'])).toLocal(),
        reservationExpiresAt: j['reservationExpiresAt'] == null ? null : DateTime.parse(_str(j['reservationExpiresAt'])).toLocal(),
        itemCount: _opt<int>(j['itemCount']) ?? 0,
        items: _list(j['items']).map(OrderItem.fromJson).toList(),
        history: _list(j['statusHistory']).map(StatusEvent.fromJson).toList(),
      );
}

class PaymentInit {
  PaymentInit({required this.keyId, required this.razorpayOrderId, required this.amountPaise, required this.name, required this.description, required this.contact, this.customerName});
  final String keyId;
  final String razorpayOrderId;
  final int amountPaise;
  final String name;
  final String description;
  final String contact;
  final String? customerName;
  factory PaymentInit.fromJson(Map<String, dynamic> j) {
    final prefill = j['prefill'] as Map<String, dynamic>? ?? const {};
    return PaymentInit(
      keyId: _str(j['keyId']),
      razorpayOrderId: _str(j['razorpayOrderId']),
      amountPaise: j['amount'] as int,
      name: _str(j['name']),
      description: _str(j['description']),
      contact: _str(prefill['contact']),
      customerName: _opt<String>(prefill['name']),
    );
  }
}
