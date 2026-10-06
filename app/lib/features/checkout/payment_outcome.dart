/// What a Razorpay Checkout attempt ended with (same on phone and web).
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
