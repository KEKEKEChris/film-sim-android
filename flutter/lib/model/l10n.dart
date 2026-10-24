// What the editor says, and in which language it says it.
//
// The interface is written in English in the source: every string handed to a control is its
// English text, and this looks each one up as it is drawn. A string with no entry stays English,
// so a label added tomorrow reads correctly before anyone translates it — the dictionary is a
// translation of the interface, never a gate in front of it.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_strings.dart';

/// The languages the editor speaks. `system` follows the phone, which is what almost everyone
/// wants: a phone set to 繁體中文 opens in 繁體中文.
enum AppLanguage { system, simplifiedChinese, traditionalChinese, english }

class L10n {
  L10n._();

  static final L10n instance = L10n._();

  /// Bumped whenever the language changes; the app listens and redraws.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  AppLanguage _preference = AppLanguage.system;

  AppLanguage get preference => _preference;

  /// The language in use: the chosen one, or the phone's when the choice is `system`.
  AppLanguage get language =>
      _preference == AppLanguage.system ? _systemLanguage() : _preference;

  /// 繁體 when the phone is set to Taiwan, Hong Kong or Macao, or asks for the Hant script;
  /// 简体 otherwise. A phone set to plain `zh` with no region is the mainland's.
  static AppLanguage _systemLanguage() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode != 'zh') return AppLanguage.english;
    final traditional = locale.scriptCode == 'Hant' ||
        locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'MO';
    return traditional ? AppLanguage.traditionalChinese : AppLanguage.simplifiedChinese;
  }

  Future<void> load() async {
    final stored = await SharedPreferences.getInstance();
    final name = stored.getString(_key);
    _preference = AppLanguage.values
        .firstWhere((l) => l.name == name, orElse: () => AppLanguage.system);
  }

  Future<void> setPreference(AppLanguage value) async {
    if (value == _preference) return;
    _preference = value;
    revision.value++;
    final stored = await SharedPreferences.getInstance();
    await stored.setString(_key, value.name);
  }

  /// The translation of an English label, or the label itself when nothing is written yet.
  String t(String english) {
    if (english.isEmpty) return english;
    return switch (language) {
      AppLanguage.simplifiedChinese => simplifiedChinese[english] ?? english,
      AppLanguage.traditionalChinese => traditionalChinese[english] ?? english,
      AppLanguage.english || AppLanguage.system => english,
    };
  }

  /// A language's own name, for the picker that chooses it.
  String label(AppLanguage value) => switch (value) {
        AppLanguage.system => t('Follow System'),
        AppLanguage.simplifiedChinese => '简体中文',
        AppLanguage.traditionalChinese => '繁體中文（香港）',
        AppLanguage.english => 'English',
      };

  static const _key = 'language';
}

/// `t('Settings')`: what a control says, in the language in use.
String t(String english) => L10n.instance.t(english);
