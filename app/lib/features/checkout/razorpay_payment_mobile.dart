import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'payment_outcome.dart';

/// Phone: the Razorpay SDK. Opens Razorpay Checkout once and completes with the outcome.
class RazorpayPayment {
  final _razorpay = Razorpay();
  Completer<PaymentOutcome>? _pending;

  RazorpayPayment() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _finish(PaymentSucceeded(paymentId: r.paymentId ?? '', orderId: r.orderId ?? '', signature: r.signature ?? ''));
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
      _finish(PaymentFailed(cancelled ? 'Payment cancelled' : (r.message?.isNotEmpty == true ? r.message! : 'Payment failed'), cancelled: cancelled));
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      _finish(PaymentFailed('Please complete payment in ${r.walletName ?? 'your wallet'} and try again'));
    });
  }

  void _finish(PaymentOutcome outcome) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete(outcome);
  }

  Future<PaymentOutcome> open(PaymentInit init, {String? email}) {
    final completer = _pending = Completer<PaymentOutcome>();
    _razorpay.open({
      'key': init.keyId,
      'order_id': init.razorpayOrderId,
      'amount': init.amountPaise,
      'currency': 'INR',
      'name': init.name,
      'description': init.description,
      'prefill': {'contact': init.contact, 'email': ?email, 'name': ?init.customerName},
      'theme': {'color': brandHex()},
      'retry': {'enabled': true, 'max_count': 2},
      'send_sms_hash': true,
    });
    return completer.future;
  }

  void dispose() => _razorpay.clear();
}
