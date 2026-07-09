import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppController _app = AppController.instance;

  Future<void> _setThemeMode(ThemeMode mode) async {
    await _app.setThemeMode(mode);
    if (mounted) setState(() {});
  }

  Future<void> _setAccentColor(int index) async {
    await _app.setAccentColorIndex(index);
    if (mounted) setState(() {});
  }

  Future<void> _setLanguage(String code) async {
    await _app.setLanguageCode(code);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final languages = _app.languages;
        final selectedLanguage = languages.any((language) => language.code == _app.languageCode) ? _app.languageCode : 'en';

        return Scaffold(
          appBar: AppBar(title: Text(_app.t('settings.title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withOpacity(0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _app.t('settings.appearance'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _app.t('settings.theme'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeModeTile(
                              title: _app.t('settings.theme.system'),
                              icon: Icons.settings_suggest_outlined,
                              selected: _app.themeMode == ThemeMode.system,
                              onTap: () => _setThemeMode(ThemeMode.system),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeModeTile(
                              title: _app.t('settings.theme.light'),
                              icon: Icons.light_mode_outlined,
                              selected: _app.themeMode == ThemeMode.light,
                              onTap: () => _setThemeMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeModeTile(
                              title: _app.t('settings.theme.dark'),
                              icon: Icons.dark_mode_outlined,
                              selected: _app.themeMode == ThemeMode.dark,
                              onTap: () => _setThemeMode(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _app.t('settings.accent'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(AppController.accentColors.length, (index) {
                          final item = AppController.accentColors[index];
                          final selected = index == _app.accentColorIndex;
                          return Tooltip(
                            message: _app.t(item.labelKey),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _setAccentColor(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.color,
                                  border: Border.all(
                                    color: selected ? scheme.onSurface : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: item.color.withOpacity(0.36),
                                            blurRadius: 14,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withOpacity(0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _app.t('settings.language'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedLanguage,
                        decoration: InputDecoration(labelText: _app.t('settings.language')),
                        items: languages
                            .map(
                              (language) => DropdownMenuItem(
                                value: language.code,
                                child: Text(language.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _setLanguage(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _app.t('settings.language.fallback'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _app.t('settings.language.addInfo'),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? scheme.primaryContainer : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
