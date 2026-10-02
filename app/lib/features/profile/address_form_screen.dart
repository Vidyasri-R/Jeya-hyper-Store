import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Jeya Hyper Store, Trichy (store's Google Maps pin) — map starts here.
const _store = LatLng(10.8127737, 78.6358536);

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});
  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController(text: 'Tiruchirappalli');
  final _pincode = TextEditingController();
  String _label = 'Home';
  bool _isDefault = false;
  LatLng _pin = _store;
  Timer? _debounce;
  Map<String, dynamic>? _estimate;
  bool _saving = false;
  bool _locating = false;
  Address? _existing;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth is SignedIn) {
      _name.text = auth.user.name ?? '';
      _phone.text = auth.user.phone.length == 12
          ? auth.user.phone.substring(2)
          : auth.user.phone;
    }
    final list = ref.read(addressesProvider).valueOrNull ?? const [];
    if (widget.addressId != null) {
      _existing = list.where((a) => a.id == widget.addressId).firstOrNull;
      final a = _existing;
      if (a != null) {
        _label = a.label ?? 'Home';
        _name.text = a.recipientName;
        _phone.text = a.phone.length == 12 ? a.phone.substring(2) : a.phone;
        _line1.text = a.line1;
        _line2.text = a.line2 ?? '';
        _landmark.text = a.landmark ?? '';
        _city.text = a.city;
        _pincode.text = a.pincode;
        _isDefault = a.isDefault;
        if (a.latitude != null && a.longitude != null) {
          _pin = LatLng(a.latitude!, a.longitude!);
        }
      }
    } else {
      _isDefault = list.isEmpty;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useCurrentLocation(silent: true),
      );
    }
    _scheduleEstimate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _name,
      _phone,
      _line1,
      _line2,
      _landmark,
      _city,
      _pincode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final e = await ref
            .read(repositoryProvider)
            .deliveryEstimate(_pin.latitude, _pin.longitude);
        if (mounted) setState(() => _estimate = e);
      } catch (_) {
        // Estimate is advisory; checkout re-validates.
      }
    });
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Turn on location services to use your current location';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = here);
      _map.move(here, 17);
      _scheduleEstimate();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'label': _label,
      'recipientName': _name.text.trim(),
      'phone': _phone.text.trim(),
      'pincode': _pincode.text.trim(),
      'line1': _line1.text.trim(),
      'line2': _line2.text.trim(),
      'landmark': _landmark.text.trim(),
      'city': _city.text.trim(),
      'latitude': double.parse(_pin.latitude.toStringAsFixed(6)),
      'longitude': double.parse(_pin.longitude.toStringAsFixed(6)),
    };
    try {
      final repo = ref.read(repositoryProvider);
      final saved = _existing == null
          ? await repo.createAddress({...body, 'isDefault': _isDefault})
          : await repo.updateAddress(_existing!.id, {
              ...body,
              if (_isDefault && !_existing!.isDefault) 'isDefault': true,
            });
      ref.invalidate(addressesProvider);
      ref.read(selectedAddressIdProvider.notifier).state = saved.id;
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = _estimate;
    final serviceable = e?['serviceable'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Add Address' : 'Edit Address'),
      ),
      body: Form(
        key: _form,
        // Map is a fixed header, NOT inside the scroll view: inside a ListView, vertical
        // drags on the map scroll the page instead of moving the pin.
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // Shrink while typing so the focused field stays visible above the keyboard.
              height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 140 : 260,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _pin,
                      initialZoom: 16,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onPositionChanged: (camera, hasGesture) {
                        if (!hasGesture) return;
                        _pin = camera.center;
                        _scheduleEstimate();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.jeyahyperstore.app',
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 36),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 44,
                          color: AppColors.green700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: _locating ? null : () => _useCurrentLocation(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.green700,
                        elevation: 2,
                      ),
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use my location'),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: e == null
                    ? AppColors.bg
                    : (serviceable
                          ? AppColors.green50
                          : AppColors.offerRedSoft),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    serviceable
                        ? Icons.local_shipping_outlined
                        : Icons.info_outline_rounded,
                    color: serviceable
                        ? AppColors.green700
                        : AppColors.offerRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e == null
                          ? 'Move the map to place the pin at your door'
                          : serviceable
                          ? '${e['distanceKm']} km from store · Delivery ${toPaise(e['deliveryFee'] as String) == 0 ? 'FREE' : formatRupees(e['deliveryFee'] as String)} (free above ${formatRupees(e['freeDeliveryAbove'] as String? ?? '999')})'
                          : "Sorry, we don't deliver here yet (${e['distanceKm']} km away, we deliver within ${e['maxDistanceKm']} km)",
                      style: text.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text('Save as', style: text.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final l in const ['Home', 'Work', 'Other'])
                        ChoiceChip(
                          label: Text(l),
                          selected: _label == l,
                          onSelected: (_) => setState(() => _label = l),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(_line1, 'House / Flat no., Street', required: true),
                  _field(_line2, 'Area / Locality'),
                  _field(_landmark, 'Landmark (optional)'),
                  Row(
                    children: [
                      Expanded(child: _field(_city, 'City', required: true)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          _pincode,
                          'Pincode',
                          keyboard: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) =>
                              RegExp(r'^[1-9]\d{5}$').hasMatch(v ?? '')
                              ? null
                              : 'Enter 6-digit pincode',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Contact for delivery', style: text.titleSmall),
                  const SizedBox(height: 8),
                  _field(_name, 'Recipient name', required: true),
                  _field(
                    _phone,
                    'Mobile number',
                    keyboard: TextInputType.phone,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                        ? null
                        : 'Enter a valid 10-digit mobile',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    activeThumbColor: AppColors.green700,
                    onChanged: _existing?.isDefault == true
                        ? null
                        : (v) => setState(() => _isDefault = v),
                    title: const Text('Make this my default address'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Address'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: keyboard == null
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    ),
  );
}
