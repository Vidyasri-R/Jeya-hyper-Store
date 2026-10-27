import '../data/repository.dart';
import 'order_alerts/order_alerts_io.dart' if (dart.library.js_interop) 'order_alerts/shop_audio_web.dart' as impl;

export 'order_alerts/order_alerts_io.dart' if (dart.library.js_interop) 'order_alerts/shop_audio_web.dart' show ShopAudioInfo;

/// The shop phone plays the ad sound at the shop TV's ad breaks and pauses the owner's music app.
abstract final class ShopAudio {
  static Future<impl.ShopAudioInfo> status() => impl.shopAudioStatus();
  static Future<void> enable(StaffRepository repo) => impl.enableShopAudio(repo);
  static Future<void> disable(StaffRepository repo) => impl.disableShopAudio(repo);
  static void test() => impl.testShopAudio();
}
