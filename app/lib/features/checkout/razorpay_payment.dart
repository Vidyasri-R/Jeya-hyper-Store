import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../data/models.dart';

sealed class PaymentOutcome {}

class PaymentSucceeded extends PaymentOutcome {
  PaymentSucceeded({required this.paymentId, required this.orderId, required this.signature});
  final String paymentId;
  final String orderId;
  final String signature;
}

class PaymentFailed extends PaymentOutcome {
  PaymentFailed(this.message, {this.cancelled = false});
  final String message;
  final bool cancelled;
}

/// Opens Razorpay Checkout once and completes with the outcome.
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
      'theme': {'color': '#1B7A3E'},
      'retry': {'enabled': true, 'max_count': 2},
      'send_sms_hash': true,
    });
    return completer.future;
  }

  void dispose() => _razorpay.clear();
}
