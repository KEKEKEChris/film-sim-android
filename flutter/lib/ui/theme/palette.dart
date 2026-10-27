// The editor's colours and the Spectrum 2 greys its components draw with, for the light and dark
// appearances.
import 'package:flutter/widgets.dart';

class Palette {
  const Palette({
    required this.dark,
    required this.text,
    required this.page,
    required this.panel,
    required this.border,
    required this.muted,
    required this.accent,
    required this.selected,
    required this.canvas,
    required this.gray25,
    required this.gray100,
    required this.gray300,
    required this.gray700,
    required this.gray800,
    required this.fieldFill,
    required this.switchOff,
    required this.popover,
    required this.tooltip,
    required this.systemColors,
  });

  final bool dark;
  final Color text, page, panel, border, muted, accent, selected, canvas;

  /// Spectrum's greys: 25 is the lightest surface, 800 the neutral fill of a selected toggle.
  final Color gray25, gray100, gray300, gray700, gray800;
  final Color fieldFill, switchOff, popover, tooltip;

  /// The colours Fotufilm's glyphs paint their coloured parts with (`--fotu-system*`).
  final Map<String, Color> systemColors;

  /// The text and icon colour on a selected toggle.
  Color get onSelected => gray25;
  Color get hover => text.withValues(alpha: .07);
  Color get pressed => text.withValues(alpha: .12);

  static const light = Palette(
    dark: false,
    text: Color(0xFF242628),
    page: Color(0xFFE8E9EB),
    panel: Color(0xFFF4F4F5),
    border: Color(0xFFD6D7DA),
    muted: Color(0xFF73767B),
    accent: Color(0xFF326CD5),
    selected: Color(0xFFDDE7F8),
    canvas: Color(0xFFE1E2E5),
    gray25: Color(0xFFFFFFFF),
    gray100: Color(0xFFE9E9E9),
    gray300: Color(0xFFDADADA),
    gray700: Color(0xFF505050),
    gray800: Color(0xFF292929),
    fieldFill: Color(0x0D000000),
    switchOff: Color(0x24000000),
    popover: Color(0xFFFFFFFF),
    tooltip: Color(0xFF292929),
    systemColors: {
      'Red': Color(0xFFFF3B30),
      'Orange': Color(0xFFFF9500),
      'Yellow': Color(0xFFFFCC00),
      'Green': Color(0xFF34C759),
      'Cyan': Color(0xFF32ADE6),
      'Blue': Color(0xFF007AFF),
      'Purple': Color(0xFFAF52DE),
      'Pink': Color(0xFFFF2D55),
    },
  );

  static const darkPalette = Palette(
    dark: true,
    text: Color(0xFFE2E3E6),
    page: Color(0xFF202124),
    panel: Color(0xFF292A2D),
    border: Color(0xFF3D3F43),
    muted: Color(0xFFA0A3AA),
    accent: Color(0xFF8AAEFA),
    selected: Color(0xFF364761),
    canvas: Color(0xFF202124),
    gray25: Color(0xFF111111),
    gray100: Color(0xFF2C2C2C),
    gray300: Color(0xFF393939),
    gray700: Color(0xFFAFAFAF),
    gray800: Color(0xFFDBDBDB),
    fieldFill: Color(0x14FFFFFF),
    switchOff: Color(0x33FFFFFF),
    popover: Color(0xFF2C2C2C),
    tooltip: Color(0xFFDBDBDB),
    systemColors: {
      'Red': Color(0xFFFF453A),
      'Orange': Color(0xFFFF9F0A),
      'Yellow': Color(0xFFFFD60A),
      'Green': Color(0xFF30D158),
      'Cyan': Color(0xFF64D2FF),
      'Blue': Color(0xFF0A84FF),
      'Purple': Color(0xFFBF5AF2),
      'Pink': Color(0xFFFF375F),
    },
  );

  /// The warm darkroom: the app's own appearance, and its default. A brown-black page with a
  /// soft amber accent, so the chrome reads as warm without tinting the photograph itself —
  /// `canvas` stays near black so the picture always sits on a dark mat.
  static const warm = Palette(
    dark: true,
    text: Color(0xFFF6EEE2),
    page: Color(0xFF1C1713),
    panel: Color(0xFF26201B),
    border: Color(0xFF544A3E),
    muted: Color(0xFFBFAE99),
    accent: Color(0xFFDEB27C),
    selected: Color(0xFF4A3B2A),
    canvas: Color(0xFF0C0907),
    gray25: Color(0xFF241B0F),
    gray100: Color(0xFF302A23),
    gray300: Color(0xFF4B4035),
    gray700: Color(0xFFBFAE99),
    gray800: Color(0xFFDEB27C),
    fieldFill: Color(0x14FFFFFF),
    switchOff: Color(0x33FFFFFF),
    popover: Color(0xFF302A23),
    tooltip: Color(0xFF3B332C),
    systemColors: {
      'Red': Color(0xFFFF453A),
      'Orange': Color(0xFFFF9F0A),
      'Yellow': Color(0xFFFFD60A),
      'Green': Color(0xFF30D158),
      'Cyan': Color(0xFF64D2FF),
      'Blue': Color(0xFF0A84FF),
      'Purple': Color(0xFFBF5AF2),
      'Pink': Color(0xFFFF375F),
    },
  );

  /// Pure black with an electric blue accent: no warmth at all, for judging colour without any
  /// cast in the surrounding chrome.
  static const pure = Palette(
    dark: true,
    text: Color(0xFFFFFFFF),
    page: Color(0xFF000000),
    panel: Color(0xFF0B0B0E),
    border: Color(0xFF35353D),
    muted: Color(0xFFA6A6AF),
    accent: Color(0xFF2F7BFF),
    selected: Color(0xFF1B3358),
    canvas: Color(0xFF000000),
    gray25: Color(0xFFFFFFFF),
    gray100: Color(0xFF1F1F24),
    gray300: Color(0xFF2A2A32),
    gray700: Color(0xFFA6A6AF),
    gray800: Color(0xFF2F7BFF),
    fieldFill: Color(0x14FFFFFF),
    switchOff: Color(0x33FFFFFF),
    popover: Color(0xFF151519),
    tooltip: Color(0xFF1F1F24),
    systemColors: {
      'Red': Color(0xFFFF453A),
      'Orange': Color(0xFFFF9F0A),
      'Yellow': Color(0xFFFFD60A),
      'Green': Color(0xFF30D158),
      'Cyan': Color(0xFF64D2FF),
      'Blue': Color(0xFF0A84FF),
      'Purple': Color(0xFFBF5AF2),
      'Pink': Color(0xFFFF375F),
    },
  );

  /// The appearances the Settings page offers, in its order: (id, name).
  static const appearances = <(String, String)>[
    ('warm', 'Warm darkroom'),
    ('pure', 'Pure'),
    ('system', 'Follow the system'),
  ];

  /// The appearance `id` names, the system's when it is unknown or asks for the system.
  static Palette named(String? id, {bool systemDark = true}) => switch (id) {
        'pure' => pure,
        'light' => light,
        'system' => systemDark ? darkPalette : light,
        _ => warm,
      };

  static Palette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ?? warm;
}

class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});
  final Palette palette;

  @override
  bool updateShouldNotify(PaletteScope oldWidget) => oldWidget.palette != palette;
}
