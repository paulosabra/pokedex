import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

/// The application-scoped [Connectivity] platform channel. `keepAlive: true`
/// so the platform stream survives provider rebuilds; reopening it on every
/// rebuild would silently drop subscribers.
@Riverpod(keepAlive: true)
Connectivity connectivity(Ref ref) => Connectivity();
