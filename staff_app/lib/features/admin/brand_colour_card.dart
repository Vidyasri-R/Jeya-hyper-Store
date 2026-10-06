import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';

/// Admin → Store settings → Brand colour (public config `app.brand` = `{color: '#RRGGBB'}`).
/// The customer app derives every shade from this one colour; [brandShades] mirrors its
/// `Palettes.fromColor` (app/lib/core/theme.dart) so the preview matches what customers see.
class BrandColourCard extends StatefulWidget {
  const BrandColourCard({super.key, required this.value, required this.onSave});
  final Map<String, dynamic> value;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<BrandColourCard> createState() => _BrandColourCardState();
}

const brandPresets = <(String, int)>[
  ('Jeya green', 0xFF1B7A3E),
  ('Logo blue', 0xFF1E4FA8),
  ('Maroon', 0xFF8E1B2E),
  ('Teal', 0xFF00796B),
  ('Purple', 0xFF6A1B9A),
  ('Orange', 0xFFC2410C),
];

/// (button, dark, header start, header end, soft panel) for a chosen colour.
({Color button, Color dark, Color headerStart, Color headerEnd, Color soft}) brandShades(Color seed) {
  if (seed.toARGB32() == 0xFF1B7A3E) {
    return (button: seed, dark: const Color(0xFF0F4D2A), headerStart: const Color(0xFF14612F), headerEnd: const Color(0xFF23934B), soft: const Color(0xFFEFF8F1));
  }
  final hsl = HSLColor.fromColor(seed);
  final s = hsl.saturation.clamp(0.25, 0.9);
  var b700 = hsl.withSaturation(s);
  while (b700.lightness > 0.08 && b700.toColor().computeLuminance() > 0.18) {
    b700 = b700.withLightness(b700.lightness - 0.01);
  }
  if (b700.lightness < 0.18) b700 = b700.withLightness(0.18);
  final l = b700.lightness;
  Color at(double lightness, [double sat = 1]) => b700.withLightness(lightness.clamp(0.0, 1.0)).withSaturation((s * sat).clamp(0.0, 1.0)).toColor();
  return (button: b700.toColor(), dark: at(l * 0.58), headerStart: at(l * 0.8), headerEnd: at(l + 0.07), soft: at(0.95, 0.5));
}

String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? parseHex(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF$hex', radix: 16));
}

class _BrandColourCardState extends State<BrandColourCard> {
  late Color _saved = parseHex(widget.value['color'] as String? ?? '') ?? const Color(0xFF1B7A3E);
  late Color _color = _saved;
  late final _hex = TextEditingController(text: hexOf(_color));
  bool _saving = false;

  void _pick(Color c, {bool fromField = false}) {
    setState(() => _color = c);
    if (!fromField) _hex.text = hexOf(c);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave({'color': hexOf(_color)});
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _saved = _color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shades = brandShades(_color);
    final adjusted = shades.button.toARGB32() != _color.toARGB32();
    final hue = HSLColor.fromColor(_color).hue;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Brand colour', style: text.titleMedium),
          Text('The everyday colour of the customer app — buttons, header, chips. Festival themes take over on their dates.', style: text.bodySmall),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (name, argb) in brandPresets)
              _Swatch(name: name, color: Color(argb), selected: _color.toARGB32() == argb, onTap: () => _pick(Color(argb))),
          ]),
          const SizedBox(height: 16),
          Text('Or any colour', style: text.labelLarge),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 14, thumbColor: Colors.white, overlayShape: SliderComponentShape.noOverlay),
            child: Stack(alignment: Alignment.center, children: [
              Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), 0.7, 0.4).toColor()]),
                ),
              ),
              Slider(
                value: hue,
                max: 360,
                activeColor: Colors.transparent,
                inactiveColor: Colors.transparent,
                label: 'Colour',
                semanticFormatterCallback: (v) => 'Hue ${v.round()}',
                onChanged: (h) => _pick(HSLColor.fromAHSL(1, h, 0.7, 0.36).toColor()),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hex,
            decoration: const InputDecoration(labelText: 'Colour code', hintText: '#1E4FA8', helperText: 'Paste your brand colour, e.g. from your logo or signboard'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')), LengthLimitingTextInputFormatter(7)],
            onChanged: (v) {
              final c = parseHex(v);
              if (c != null) _pick(c, fromField: true);
            },
          ),
          const SizedBox(height: 16),
          Text('Preview', style: text.labelLarge),
          const SizedBox(height: 8),
          _Preview(shades: shades),
          if (adjusted) ...[
            const SizedBox(height: 8),
            Text('This colour is light, so buttons use a deeper shade (${hexOf(shades.button)}) to keep white text readable.', style: text.bodySmall),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving || _color.toARGB32() == _saved.toARGB32() ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save brand colour'),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.selected, required this.onTap});
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : const Color(0xFFE0E0E0), width: selected ? 2.5 : 1),
          ),
          child: Column(children: [
            Container(
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
            ),
            const SizedBox(height: 6),
            Text(name, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

/// A miniature of the customer app's home header, a chip and a button in the chosen colour.
class _Preview extends StatelessWidget {
  const _Preview({required this.shades});
  final ({Color button, Color dark, Color headerStart, Color headerEnd, Color soft}) shades;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6ECE8))),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [shades.headerStart, shades.headerEnd])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Jeya Hyper Store', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('Good Morning!', style: text.bodySmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 10),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text('Search for products…', style: text.bodySmall),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: shades.soft, borderRadius: BorderRadius.circular(999)),
                child: Text('Staples', style: text.labelMedium?.copyWith(color: shades.dark, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: shades.button, borderRadius: BorderRadius.circular(12)),
                child: Text('Add', style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
