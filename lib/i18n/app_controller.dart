import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;

  const AppLanguage({required this.code, required this.name});
}

class AppAccentColor {
  final String id;
  final Color color;
  final String labelKey;

  const AppAccentColor({required this.id, required this.color, required this.labelKey});
}

class AppController extends ChangeNotifier {
  AppController._();

  static final AppController instance = AppController._();
  static const systemLanguageCode = 'system';
  static const _themeKey = 'settings_theme_mode_v1';
  static const _colorKey = 'settings_accent_color_v1';
  static const _languageKey = 'settings_language_code_v1';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  int _accentColorIndex = 0;
  String _languageCode = 'en';
  Map<String, Map<String, String>> _translations = {};
  List<AppLanguage> _languages = const [];

  static const accentColors = <AppAccentColor>[
    AppAccentColor(id: 'navy', color: Color(0xFF1D2A52), labelKey: 'settings.color.navy'),
    AppAccentColor(id: 'blue', color: Color(0xFF2563EB), labelKey: 'settings.color.blue'),
    AppAccentColor(id: 'cyan', color: Color(0xFF0891B2), labelKey: 'settings.color.cyan'),
    AppAccentColor(id: 'teal', color: Color(0xFF0F766E), labelKey: 'settings.color.teal'),
    AppAccentColor(id: 'green', color: Color(0xFF16A34A), labelKey: 'settings.color.green'),
    AppAccentColor(id: 'lime', color: Color(0xFF65A30D), labelKey: 'settings.color.lime'),
    AppAccentColor(id: 'yellow', color: Color(0xFFCA8A04), labelKey: 'settings.color.yellow'),
    AppAccentColor(id: 'orange', color: Color(0xFFEA580C), labelKey: 'settings.color.orange'),
    AppAccentColor(id: 'red', color: Color(0xFFDC2626), labelKey: 'settings.color.red'),
    AppAccentColor(id: 'rose', color: Color(0xFFE11D48), labelKey: 'settings.color.rose'),
    AppAccentColor(id: 'pink', color: Color(0xFFDB2777), labelKey: 'settings.color.pink'),
    AppAccentColor(id: 'purple', color: Color(0xFF9333EA), labelKey: 'settings.color.purple'),
    AppAccentColor(id: 'violet', color: Color(0xFF7C3AED), labelKey: 'settings.color.violet'),
    AppAccentColor(id: 'indigo', color: Color(0xFF4F46E5), labelKey: 'settings.color.indigo'),
    AppAccentColor(id: 'slate', color: Color(0xFF475569), labelKey: 'settings.color.slate'),
    AppAccentColor(id: 'brown', color: Color(0xFF795548), labelKey: 'settings.color.brown'),
  ];

  ThemeMode get themeMode => _themeMode;
  int get accentColorIndex => _accentColorIndex;
  Color get accentColor => accentColors[_accentColorIndex].color;
  String get languageCode => _languageCode;
  List<AppLanguage> get languages {
    final map = <String, AppLanguage>{
      'en': const AppLanguage(code: 'en', name: 'English'),
      'uk': const AppLanguage(code: 'uk', name: 'Українська'),
    };
    for (final language in _languages) {
      if (language.code != systemLanguageCode) {
        map[language.code] = language;
      }
    }
    final result = <AppLanguage>[];
    if (map.containsKey('en')) result.add(map.remove('en')!);
    if (map.containsKey('uk')) result.add(map.remove('uk')!);
    result.addAll(map.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    return result;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromString(_prefs?.getString(_themeKey));
    _accentColorIndex = (_prefs?.getInt(_colorKey) ?? 0).clamp(0, accentColors.length - 1).toInt();
    final storedLanguage = _prefs?.getString(_languageKey);
    _languageCode = storedLanguage == null || storedLanguage == systemLanguageCode ? 'en' : storedLanguage;
    if (storedLanguage == systemLanguageCode) {
      await _prefs?.setString(_languageKey, 'en');
    }
    await reloadTranslations();
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_themeKey, _themeModeToString(mode));
    notifyListeners();
  }

  Future<void> setAccentColorIndex(int index) async {
    _accentColorIndex = index.clamp(0, accentColors.length - 1).toInt();
    await _prefs?.setInt(_colorKey, _accentColorIndex);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    final next = code == systemLanguageCode ? 'en' : code;
    if (_languageCode == next) return;
    _languageCode = next;
    await _prefs?.setString(_languageKey, next);
    notifyListeners();
  }

  Future<void> reloadTranslations() async {
    final loaded = <String, Map<String, String>>{};
    final files = <String>{};

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      files.addAll(
        manifest.listAssets().where((path) => path.startsWith('assets/i18n/') && path.endsWith('.json')),
      );
    } catch (_) {}

    if (files.isEmpty) {
      try {
        final manifestRaw = await rootBundle.loadString('AssetManifest.json');
        final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
        files.addAll(manifest.keys.where((path) => path.startsWith('assets/i18n/') && path.endsWith('.json')));
      } catch (_) {}
    }

    for (final path in files.toList()..sort()) {
      try {
        final code = path.split('/').last.replaceAll('.json', '');
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final data = decoded.map<String, String>(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
        loaded[code] = data;
      } catch (_) {}
    }

    loaded['en'] = {..._fallbackEn, ...?loaded['en']};
    loaded['uk'] = {..._fallbackUk, ...?loaded['uk']};

    _translations = loaded;
    _languages = loaded.entries
        .where((entry) => entry.key != systemLanguageCode)
        .map((entry) => AppLanguage(
              code: entry.key,
              name: entry.value['com.lastofend.plannig.name'] ?? entry.key,
            ))
        .toList();

    if (_languageCode == systemLanguageCode || (!loaded.containsKey(_languageCode) && _languageCode != 'en' && _languageCode != 'uk')) {
      _languageCode = 'en';
      await _prefs?.setString(_languageKey, _languageCode);
    }
  }

  String get effectiveLanguageCode {
    if (_languageCode == 'uk') return 'uk';
    if (_languageCode == 'en' || _languageCode == systemLanguageCode) return 'en';
    if (_translations.containsKey(_languageCode)) return _languageCode;
    return 'en';
  }

  String t(String key, [Map<String, Object?> values = const {}]) {
    final code = effectiveLanguageCode;
    final hardFallback = code == 'uk' ? _fallbackUk : _fallbackEn;
    final effective = _translations[code] ?? hardFallback;
    final english = _translations['en'] ?? _fallbackEn;
    var value = effective[key] ?? english[key] ?? _fallbackUk[key] ?? key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String weekdayShort(int weekday) => t('weekday.short.$weekday');

  String durationText(int minutes) {
    if (minutes <= 0) return t('duration.minutes', {'count': 0});
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return t('duration.minutes', {'count': m});
    if (m == 0) return t('duration.hours', {'count': h});
    return t('duration.hoursMinutes', {'hours': h, 'minutes': m});
  }

  static const _fallbackEn = <String, String>{
    "alarm.dismiss": "Dismiss",
    "alarm.eventTime": "Event time",
    "alarm.mathActive": "Interactive dismiss is active",
    "alarm.snooze5": "Snooze 5 min",
    "alarm.solveExamples": "Solve examples",
    "alarm.solveSubtitle": "The dismiss button becomes active only after correct answers.",
    "alarm.solveTitle": "Solve 3 examples",
    "alarm.turnOff": "Turn off",
    "app.title": "Smart Alarm Planner",
    "auth.reason": "Please confirm your identity",
    "backup.exportCanceled": "Export canceled",
    "backup.exportError": "Export error: {error}",
    "backup.exportTitle": "Save backup as…",
    "backup.importError": "Import error: {error}",
    "backup.importTitle": "Choose backup file (.json)",
    "backup.imported": "Imported events: {count}",
    "backup.invalidFormat": "Invalid file format",
    "backup.saved": "Backup saved:\n{path}",
    "com.lastofend.plannig.name": "English",
    "common.actions": "Actions",
    "common.cancel": "Cancel",
    "common.delete": "Delete",
    "common.done": "Done",
    "common.edit": "Edit",
    "common.editForbidden": "Editing is disabled",
    "common.enabled": "Enabled",
    "common.error": "Error",
    "common.pick": "Pick",
    "common.reload": "Refresh",
    "common.system": "System",
    "common.today": "Today",
    "constructor.otherTime": "Other time…",
    "constructor.pickTimeBetween": "Pick time between {start} and {end}",
    "constructor.title": "Constructor (week)",
    "diagnostics.notificationSettings": "Notification settings",
    "diagnostics.refresh": "Refresh pending()",
    "diagnostics.title": "Diagnostics",
    "diagnostics.trace": "test 10s (trace)",
    "duration.hours": "{count} h",
    "duration.hoursMinutes": "{hours} h {minutes} min",
    "duration.minutes": "{count} min",
    "event.callBefore5": "Call 5 min before",
    "event.chooseOneOffDate": "Choose a date for the one-time event",
    "event.chooseWeekday": "Choose at least one weekday",
    "event.createTitle": "Create event",
    "event.daily": "Every day",
    "event.description": "Short description",
    "event.editTitle": "Edit event",
    "event.mathDismiss": "Interactive dismiss",
    "event.mathDismissDescription": "To silence the alarm, solve 3 random examples correctly",
    "event.mathDismissShort": "3 examples",
    "event.name": "Name",
    "event.nameRequired": "Enter a name",
    "event.noDate": "No date selected",
    "event.noDateSpecified": "Date not specified",
    "event.noEvents": "No events",
    "event.once": "One-time",
    "event.oneOff": "Specific date",
    "event.pickDate": "Pick date",
    "event.priority": "Priority",
    "event.save": "Save",
    "event.saveChanges": "Save changes",
    "event.snooze5": "Snooze 5 min",
    "event.time": "Time: {time}",
    "event.timeConflict": "Time conflict on: {days}",
    "event.weekly": "Every week",
    "home.createEvent": "Create event",
    "home.emptyToday": "No events for today",
    "home.title": "Day plan ({weekday})",
    "menu.constructor": "Constructor",
    "menu.diagnostics": "Diagnostics",
    "menu.exactAlarmPermission": "Exact alarm permission",
    "menu.export": "Export (choose location)…",
    "menu.import": "Import DB (JSON)",
    "menu.notificationSettings": "Notification settings",
    "menu.settings": "Settings",
    "menu.timeline": "My timeline",
    "menu.tooltip": "Menu",
    "notification.before5Body": "{title} starts soon",
    "notification.before5Title": "Reminder in 5 min",
    "notification.instantBody": "If you see this, notifications work",
    "notification.instantTitle": "Instant check",
    "notification.nativeTestBody": "Should ring in {seconds} sec.",
    "notification.nativeTestTitle": "Native alarm test",
    "settings.accent": "Theme color",
    "settings.appearance": "Appearance",
    "settings.color.blue": "Blue",
    "settings.color.brown": "Brown",
    "settings.color.cyan": "Cyan",
    "settings.color.green": "Green",
    "settings.color.indigo": "Indigo",
    "settings.color.lime": "Lime",
    "settings.color.navy": "Navy",
    "settings.color.orange": "Orange",
    "settings.color.pink": "Pink",
    "settings.color.purple": "Purple",
    "settings.color.red": "Red",
    "settings.color.rose": "Rose",
    "settings.color.slate": "Slate",
    "settings.color.teal": "Teal",
    "settings.color.violet": "Violet",
    "settings.color.yellow": "Yellow",
    "settings.language": "Language",
    "settings.language.addInfo": "Add a new language with a JSON file in assets/i18n. The language name is set by com.lastofend.plannig.name.",
    "settings.language.fallback": "If a translation is missing, the text falls back to English.",
    "settings.language.system": "System default",
    "settings.theme": "Theme mode",
    "settings.theme.dark": "Dark",
    "settings.theme.light": "Light",
    "settings.theme.system": "System",
    "settings.title": "Settings",
    "timeline.bar": "Day bar",
    "timeline.blocks": "Day blocks",
    "timeline.covered": "Covered",
    "timeline.empty": "No events for this day",
    "timeline.events": "Events",
    "timeline.now": "now",
    "timeline.title": "My timeline",
    "weekday.short.1": "Mon",
    "weekday.short.2": "Tue",
    "weekday.short.3": "Wed",
    "weekday.short.4": "Thu",
    "weekday.short.5": "Fri",
    "weekday.short.6": "Sat",
    "weekday.short.7": "Sun",
  };

  static const _fallbackUk = <String, String>{
    "alarm.dismiss": "Заглушити",
    "alarm.eventTime": "Час події",
    "alarm.mathActive": "Інтерактивне вимкнення активне",
    "alarm.snooze5": "Перенести 5 хв",
    "alarm.solveExamples": "Вирішити приклади",
    "alarm.solveSubtitle": "Кнопка заглушити стане активною тільки після правильних відповідей.",
    "alarm.solveTitle": "Виріши 3 приклади",
    "alarm.turnOff": "Вимкнути",
    "app.title": "Планувальник будильників",
    "auth.reason": "Підтвердіть, будь ласка, особу",
    "backup.exportCanceled": "Експорт скасовано",
    "backup.exportError": "Помилка експорту: {error}",
    "backup.exportTitle": "Зберегти бекап як…",
    "backup.importError": "Помилка імпорту: {error}",
    "backup.importTitle": "Оберіть файл бекапу (.json)",
    "backup.imported": "Імпортовано подій: {count}",
    "backup.invalidFormat": "Некоректний формат файлу",
    "backup.saved": "Бекап збережено:\n{path}",
    "com.lastofend.plannig.name": "Українська",
    "common.actions": "Дії",
    "common.cancel": "Скасувати",
    "common.delete": "Видалити",
    "common.done": "Готово",
    "common.edit": "Редагувати",
    "common.editForbidden": "Редагування заборонено",
    "common.enabled": "Увімкнено",
    "common.error": "Помилка",
    "common.pick": "Обрати",
    "common.reload": "Оновити",
    "common.system": "Системна",
    "common.today": "Сьогодні",
    "constructor.otherTime": "Інший час…",
    "constructor.pickTimeBetween": "Обрати час між {start} і {end}",
    "constructor.title": "Конструктор (тиждень)",
    "diagnostics.notificationSettings": "Налашт. сповіщень",
    "diagnostics.refresh": "Refresh pending()",
    "diagnostics.title": "Діагностика",
    "diagnostics.trace": "test 10s (trace)",
    "duration.hours": "{count} год",
    "duration.hoursMinutes": "{hours} год {minutes} хв",
    "duration.minutes": "{count} хв",
    "event.callBefore5": "Подзвонити за 5 хв",
    "event.chooseOneOffDate": "Оберіть дату для разової події",
    "event.chooseWeekday": "Оберіть хоча б один день тижня",
    "event.createTitle": "Створити подію",
    "event.daily": "Кожен день",
    "event.description": "Короткий опис",
    "event.editTitle": "Редагувати подію",
    "event.mathDismiss": "Інтерактивне вимкнення",
    "event.mathDismissDescription": "Щоб заглушити будильник, треба правильно вирішити 3 випадкові приклади",
    "event.mathDismissShort": "3 приклади",
    "event.name": "Назва",
    "event.nameRequired": "Вкажіть назву",
    "event.noDate": "Дата не вибрана",
    "event.noDateSpecified": "Дата не вказана",
    "event.noEvents": "Немає подій",
    "event.once": "Разово",
    "event.oneOff": "На конкретну дату",
    "event.pickDate": "Обрати дату",
    "event.priority": "Пріоритет",
    "event.save": "Зберегти",
    "event.saveChanges": "Зберегти зміни",
    "event.snooze5": "Відкласти на 5 хв",
    "event.time": "Час: {time}",
    "event.timeConflict": "Конфлікт часу у днях: {days}",
    "event.weekly": "Кожен тиждень",
    "home.createEvent": "Створити подію",
    "home.emptyToday": "На сьогодні подій немає",
    "home.title": "План на день ({weekday})",
    "menu.constructor": "Конструктор",
    "menu.diagnostics": "Діагностика",
    "menu.exactAlarmPermission": "Дозвіл точних будильників",
    "menu.export": "Експорт (обрати місце)…",
    "menu.import": "Імпорт БД (JSON)",
    "menu.notificationSettings": "Налаштування сповіщень",
    "menu.settings": "Налаштування",
    "menu.timeline": "Мій таймлайн",
    "menu.tooltip": "Меню",
    "notification.before5Body": "{title} — скоро початок",
    "notification.before5Title": "Нагадування за 5 хв",
    "notification.instantBody": "Якщо ти це бачиш — нотифікації працюють",
    "notification.instantTitle": "Миттєва перевірка",
    "notification.nativeTestBody": "Має спрацьовати через {seconds} сек.",
    "notification.nativeTestTitle": "Тест нативного будильника",
    "settings.accent": "Колір теми",
    "settings.appearance": "Оформлення",
    "settings.color.blue": "Синій",
    "settings.color.brown": "Коричневий",
    "settings.color.cyan": "Блакитний",
    "settings.color.green": "Зелений",
    "settings.color.indigo": "Індиго",
    "settings.color.lime": "Лаймовий",
    "settings.color.navy": "Темно-синій",
    "settings.color.orange": "Помаранчевий",
    "settings.color.pink": "Пінк",
    "settings.color.purple": "Фіолетовий",
    "settings.color.red": "Червоний",
    "settings.color.rose": "Рожевий",
    "settings.color.slate": "Сірий",
    "settings.color.teal": "Бірюзовий",
    "settings.color.violet": "Вайолет",
    "settings.color.yellow": "Жовтий",
    "settings.language": "Мова",
    "settings.language.addInfo": "Нову мову можна додати JSON-файлом у assets/i18n. Назву мови задає ключ com.lastofend.plannig.name.",
    "settings.language.fallback": "Якщо перекладу немає, текст буде братися з англійської мови.",
    "settings.language.system": "Система за замовчуванням",
    "settings.theme": "Вибір теми",
    "settings.theme.dark": "Темна",
    "settings.theme.light": "Світла",
    "settings.theme.system": "Системна",
    "settings.title": "Налаштування",
    "timeline.bar": "Полоска дня",
    "timeline.blocks": "Блоки дня",
    "timeline.covered": "Покрито",
    "timeline.empty": "Для цього дня немає подій",
    "timeline.events": "Подій",
    "timeline.now": "зараз",
    "timeline.title": "Мій таймлайн",
    "weekday.short.1": "Пн",
    "weekday.short.2": "Вт",
    "weekday.short.3": "Ср",
    "weekday.short.4": "Чт",
    "weekday.short.5": "Пт",
    "weekday.short.6": "Сб",
    "weekday.short.7": "Нд",
  };
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({Key? key, required AppController controller, required Widget child})
      : super(key: key, notifier: controller, child: child);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope?.notifier ?? AppController.instance;
  }
}

extension AppContextX on BuildContext {
  AppController get app => AppScope.of(this);
  String t(String key, [Map<String, Object?> values = const {}]) => AppScope.of(this).t(key, values);
  String weekdayShort(int weekday) => AppScope.of(this).weekdayShort(weekday);
  String durationText(int minutes) => AppScope.of(this).durationText(minutes);
}
