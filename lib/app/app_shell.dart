import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/widgets/min_size_scroller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Sol sidebar + içerik alanı.
///
/// Sidebar geniş pencerede açık (yazılı), dar pencerede otomatik kompakt olur;
/// geniş pencerede kullanıcı üstteki düğmeyle de daraltabilir. Ayarlar,
/// doküman düzenindeki gibi menünün altında ayrı durur. Pencere çok küçülürse
/// uygulama alanı kaydırılabilir kalır ([MinSizeScroller]).
class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _extendBreakpoint = 1000.0;
  static const _compactWidth = 80.0;
  static const _extendedWidth = 256.0;
  static const _compactLabelHeight = 640.0;
  static const _minAppWidth = 900.0;
  static const _minAppHeight = 600.0;

  static const _items = <_NavItem>[
    _NavItem(
      'Dashboard',
      Icons.dashboard_outlined,
      Icons.dashboard,
      AppRoutes.dashboard,
    ),
    _NavItem(
      'Cariler',
      Icons.people_outline,
      Icons.people,
      AppRoutes.customers,
    ),
    _NavItem(
      'Finans Hareketleri',
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      AppRoutes.transactions,
    ),
    _NavItem(
      'İşlem Tipleri',
      Icons.category_outlined,
      Icons.category,
      AppRoutes.transactionTypes,
    ),
    _NavItem(
      'Raporlar',
      Icons.bar_chart_outlined,
      Icons.bar_chart,
      AppRoutes.reports,
    ),
  ];

  bool _preferExtended = true;

  bool get _onSettings => widget.location.startsWith(AppRoutes.settings);

  int? get _selectedIndex {
    if (_onSettings) return null;
    final index = _items.indexWhere((e) => widget.location.startsWith(e.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExtend = constraints.maxWidth >= _extendBreakpoint;
        final extended = canExtend && _preferExtended;
        final showCompactLabels = constraints.maxHeight >= _compactLabelHeight;

        return Scaffold(
          body: MinSizeScroller(
            minWidth: _minAppWidth,
            minHeight: _minAppHeight,
            child: Row(
              children: [
                SizedBox(
                  width: extended ? _extendedWidth : _compactWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: NavigationRail(
                          extended: extended,
                          minWidth: _compactWidth,
                          minExtendedWidth: _extendedWidth,
                          labelType: extended || !showCompactLabels
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (i) =>
                              context.go(_items[i].path),
                          leading: _SidebarHeader(
                            extended: extended,
                            canToggle: canExtend,
                            onToggle: () => setState(
                              () => _preferExtended = !_preferExtended,
                            ),
                          ),
                          destinations: [
                            for (final item in _items)
                              NavigationRailDestination(
                                icon: Tooltip(
                                  message: item.label,
                                  child: Icon(item.icon),
                                ),
                                selectedIcon: Tooltip(
                                  message: item.label,
                                  child: Icon(item.selectedIcon),
                                ),
                                label: Text(item.label),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        extended: extended,
                        selected: _onSettings,
                        onTap: () => context.go(AppRoutes.settings),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: widget.child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.extended,
    required this.canToggle,
    required this.onToggle,
  });

  final bool extended;
  final bool canToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = Icon(
      Icons.account_balance_wallet_outlined,
      color: theme.colorScheme.primary,
    );

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            logo,
            if (canToggle)
              IconButton(
                tooltip: 'Menüyü genişlet',
                icon: const Icon(Icons.menu),
                onPressed: onToggle,
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cari Takip',
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canToggle)
            IconButton(
              tooltip: 'Menüyü daralt',
              icon: const Icon(Icons.menu_open),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.extended,
    required this.selected,
    required this.onTap,
  });

  final bool extended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final icon = Icon(
      selected ? Icons.settings : Icons.settings_outlined,
      color: color,
    );

    return Material(
      color: theme.colorScheme.surface,
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: const Key('nav-settings'),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: extended ? 16 : 0,
            ),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.secondaryContainer : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: extended
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Text(
                        'Ayarlar',
                        style:
                            theme.textTheme.labelLarge?.copyWith(color: color),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      icon,
                      const SizedBox(height: 4),
                      Text(
                        'Ayarlar',
                        style:
                            theme.textTheme.labelMedium?.copyWith(color: color),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
