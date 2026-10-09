import 'package:flutter/widgets.dart';

/// Köke yerleştirilir. [restart] çağrıldığında [builder] yeniden çalışır ve
/// yeni bir `ProviderScope` kurulur; böylece tüm provider'lar, repository'ler
/// ve router sıfırdan oluşur (ör. yedekten geri yüklemeden sonra).
class AppRestartScope extends StatefulWidget {
  const AppRestartScope({required this.builder, super.key});

  /// Her (yeniden) başlatmada çağrılır. Verilen `key`, döndürülen
  /// `ProviderScope`'a mutlaka verilmelidir; eski scope bu sayede atılır.
  final Widget Function(Key key) builder;

  /// Üstte bir [AppRestartScope] yoksa hiçbir şey yapmaz.
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartScopeState>()?.restart();
  }

  @override
  State<AppRestartScope> createState() => _AppRestartScopeState();
}

class _AppRestartScopeState extends State<AppRestartScope> {
  int _generation = 0;

  void restart() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) => widget.builder(ValueKey(_generation));
}
