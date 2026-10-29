import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/access_request_form_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/my_access_requests_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/create_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_my_access_requests_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_requestable_connections_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/withdraw_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/withdraw_access_request_bloc.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';

/// A [MyAccessRequestsBloc], loading the list, and a [WithdrawAccessRequestBloc] for [child].
///
/// Built in the route's page, so both die with the page and neither a sign-out nor a mode switch has anything of this
/// feature to clear.
class MyAccessRequestsProviders extends StatelessWidget {
  const MyAccessRequestsProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<IAccessRequestRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              MyAccessRequestsBloc(listMyAccessRequestsUseCase: ListMyAccessRequestsUseCase(repository))
                ..add(const MyAccessRequestsLoadRequested()),
        ),
        BlocProvider(
          create: (_) =>
              WithdrawAccessRequestBloc(withdrawAccessRequestUseCase: WithdrawAccessRequestUseCase(repository)),
        ),
      ],
      child: child,
    );
  }
}

/// An [AccessRequestFormBloc], loading the connections, for [child]; built in the route's page like the others.
class AccessRequestFormProviders extends StatelessWidget {
  const AccessRequestFormProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<IAccessRequestRepository>();
    return BlocProvider(
      create: (_) => AccessRequestFormBloc(
        listRequestableConnectionsUseCase: ListRequestableConnectionsUseCase(repository),
        createAccessRequestUseCase: CreateAccessRequestUseCase(repository),
      )..add(const AccessRequestFormLoadRequested()),
      child: child,
    );
  }
}
