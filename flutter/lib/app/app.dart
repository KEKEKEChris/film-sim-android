// The app: the editor's palette for the chosen appearance, around the workspace, drawn larger
// on a phone.
import 'package:flutter/material.dart' show MaterialApp, ThemeData;
import 'package:flutter/widgets.dart';

import '../model/editor.dart';
import '../model/l10n.dart';
import '../ui/theme/theme.dart';
import 'environment.dart';
import 'touch_scale.dart';
import 'workspace.dart';

class FotufilmApp extends StatelessWidget {
  const FotufilmApp({super.key, required this.editor});
  final EditorModel editor;

  /// The appearance the editor draws with: Settings › General › Appearance, the system's own
  /// when it is set to follow it. FOTUFILM_APPEARANCE=light|dark still overrides both, for
  /// screenshots and scripted checks.
  Palette _palette(BuildContext context) {
    final forced = environment('FOTUFILM_APPEARANCE');
    if (forced == 'light') return Palette.light;
    if (forced == 'dark') return Palette.darkPalette;
    return Palette.named(editor.settings.get<String>('appearance'),
        systemDark: MediaQuery.platformBrightnessOf(context) == Brightness.dark);
  }

  @override
  Widget build(BuildContext context) {
    // A language or appearance change redraws everything below: every label is looked up as it
    // is drawn, so nothing else has to know which language or appearance is in use.
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.instance.revision, editor.settings]),
      builder: (context, _) => MaterialApp(
        title: 'Latent Image',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: editorFont, useMaterial3: true),
        // A phone draws everything larger, the menus and dialogs too (touch_scale.dart).
        builder: (context, child) => TouchScale(child: child!),
        home: PaletteScope(
          palette: _palette(context),
          child: Workspace(editor: editor),
        ),
      ),
    );
  }
}
