/// Version information shown in Settings. CI supplies the build's version and number so every
/// Android package can replace the preceding one; the defaults keep local and test builds useful.
abstract final class AppVersion {
  static const name = String.fromEnvironment('APP_VERSION', defaultValue: '1.14.1');
  static const build = String.fromEnvironment('APP_BUILD', defaultValue: '2000');

  /// Release notes kept with the app so Settings can explain what changed in each upgrade.
  static const history = <({String version, String title, List<String> changes})>[
    (
      version: '1.14.1',
      title: 'Latent Image Android improvements',
      changes: [
        'Video files can be selected from the system picker and imported.',
        'Exports show their destination and progress, can use a configurable folder, and can be shared.',
        'Search fields and the Save Preset dialog remain visible above the keyboard.',
        'The app identity is Latent Image and this Settings page records the release changes.',
      ],
    ),
  ];
}
