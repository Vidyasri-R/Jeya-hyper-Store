import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'payment_outcome.dart';

/// Razorpay Checkout.js (loaded on first use from checkout.razorpay.com).
@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

/// Browser: Razorpay's Checkout.js popup. Opens Razorpay Checkout once and completes with the outcome.
class RazorpayPayment {
  Completer<PaymentOutcome>? _pending;
  static Future<void>? _script;

  void _finish(PaymentOutcome outcome) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete(outcome);
  }

  /// Adds checkout.js to the page once; resolves when `window.Razorpay` exists.
  static Future<void> _load() => _script ??= () async {
        if (globalContext.has('Razorpay')) return;
        final done = Completer<void>();
        final document = globalContext['document'] as JSObject;
        final script = document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
        script['src'] = 'https://checkout.razorpay.com/v1/checkout.js'.toJS;
        script['async'] = true.toJS;
        script['onload'] = (() => done.complete()).toJS;
        script['onerror'] = (() {
          _script = null;
          if (!done.isCompleted) done.completeError(StateError('Razorpay could not load'));
        }).toJS;
        (document['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, script);
        return done.future.timeout(const Duration(seconds: 20));
      }();

  Future<PaymentOutcome> open(PaymentInit init, {String? email}) async {
    final completer = _pending = Completer<PaymentOutcome>();
    try {
      await _load();
    } catch (_) {
      _finish(PaymentFailed('Could not open the payment page. Check your internet and try again.'));
      return completer.future;
    }
    final options = <String, Object?>{
      'key': init.keyId,
      'order_id': init.razorpayOrderId,
      'amount': init.amountPaise,
      'currency': 'INR',
      'name': init.name,
      'description': init.description,
      'prefill': {'contact': init.contact, 'email': ?email, 'name': ?init.customerName},
      'theme': {'color': brandHex()},
      'retry': {'enabled': true, 'max_count': 2},
    }.jsify()! as JSObject;
    options['handler'] = ((JSObject r) {
      String field(String k) => (r[k] as JSString?)?.toDart ?? '';
      _finish(PaymentSucceeded(paymentId: field('razorpay_payment_id'), orderId: field('razorpay_order_id'), signature: field('razorpay_signature')));
    }).toJS;
    final modal = JSObject();
    modal['ondismiss'] = (() => _finish(PaymentFailed('Payment cancelled', cancelled: true))).toJS;
    options['modal'] = modal;

    final rzp = _Razorpay(options);
    rzp.on(
      'payment.failed',
      ((JSObject r) {
        final error = r['error'] as JSObject?;
        final description = (error?['description'] as JSString?)?.toDart;
        _finish(PaymentFailed(description?.isNotEmpty == true ? description! : 'Payment failed'));
      }).toJS,
    );
    rzp.open();
    return completer.future;
  }

  void dispose() {}
}
