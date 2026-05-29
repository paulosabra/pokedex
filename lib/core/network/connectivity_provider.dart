import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

/// The application-scoped [Connectivity] platform channel. `keepAlive: true`
/// so the platform stream survives provider rebuilds; reopening it on every
/// rebuild would silently drop subscribers.
@Riverpod(keepAlive: true)
Connectivity connectivity(Ref ref) => Connectivity();

/// `true` when [c] reports at least one transport other than
/// [ConnectivityResult.none]. The single source of truth for "is the device
/// online?" — repository, IndexCoordinator, and BackfillCoordinator all
/// share this rule so a future tweak (e.g. excluding `bluetooth`) lands in
/// one place.
Future<bool> isOnline(Connectivity c) async {
  final results = await c.checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
