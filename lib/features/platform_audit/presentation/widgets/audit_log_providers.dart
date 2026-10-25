import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/application/audit_log_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/application/usecases/list_audit_events_usecase.dart';
import 'package:libredb_mobile/features/platform_audit/domain/repositories/platform_audit_repository.dart';

/// An [AuditLogBloc] of its own for [child], which starts reading the first page at once.
///
/// Leaving the Audit tab disposes it, and its filters with it.
class AuditLogProviders extends StatelessWidget {
  const AuditLogProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        AuditLogBloc(listAuditEventsUseCase: ListAuditEventsUseCase(context.read<IPlatformAuditRepository>()))
          ..add(const AuditLogRefreshed()),
    child: child,
  );
}
