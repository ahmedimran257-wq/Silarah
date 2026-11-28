/// Home's bottom tabs, identified by name (docs/voice_calling_spec.md 12.5).
///
/// Links name the tab, never its position: the Calls tab is shown only while
/// calling is switched on, so positions move. Older links and stored
/// notifications carry numbers from the four-tab layout (0 Discover,
/// 1 Interests, 2 Chats, 3 Profile); they keep that meaning.
enum HomeTab {
  discover,
  interests,
  chats,
  calls,
  profile;

  /// The route that opens Home on this tab.
  String get path => '/home?tab=$name';

  static const _legacy = {
    '0': HomeTab.discover,
    '1': HomeTab.interests,
    '2': HomeTab.chats,
    '3': HomeTab.profile,
  };

  /// A tab name, or a number from an older link. Null for anything else.
  static HomeTab? parse(String? value) {
    final key = value?.trim();
    if (key == null || key.isEmpty) return null;
    return _legacy[key] ?? HomeTab.values.where((tab) => tab.name == key).firstOrNull;
  }
}
