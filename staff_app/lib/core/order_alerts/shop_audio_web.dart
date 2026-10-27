import '../../data/repository.dart';
import '../order_alerts.dart';

/// Browsers can't pause another app's music: Shop audio is for the shop's Android phone.
typedef ShopAudioInfo = ({bool supported, bool on, Map<String, dynamic>? status});

Future<ShopAudioInfo> shopAudioStatus() async => (supported: false, on: false, status: null);

Future<void> enableShopAudio(StaffRepository repo) async => throw const AlertException('Shop audio works in the Android app on the shop phone.');

Future<void> disableShopAudio(StaffRepository repo) async {}

void testShopAudio() {}
