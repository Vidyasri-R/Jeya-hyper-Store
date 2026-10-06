// Razorpay Checkout: the native SDK on phones, Checkout.js in the browser (same API and outcomes).
export 'payment_outcome.dart';
export 'razorpay_payment_mobile.dart' if (dart.library.js_interop) 'razorpay_payment_web.dart';
