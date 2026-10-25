import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';

/// One page of LibreDB Platform's directory search: up to [pageSize] users, the [page] number from 1, and the [total]
/// of users matching the search on every page.
///
/// [total] comes from a separate Keycloak count, so it can disagree with the pages.
final class DirectoryPage extends Equatable {
  const DirectoryPage({required this.users, required this.page, required this.total});

  /// The users on one page (libredb-platform `DIRECTORY_PAGE_SIZE`).
  static const pageSize = 20;

  /// The last page Platform accepts (libredb-platform `MAX_DIRECTORY_PAGE`).
  static const maxPage = 100000;

  final List<DirectoryUser> users;
  final int page;
  final int total;

  @override
  List<Object?> get props => [users, page, total];

  @override
  String toString() => 'DirectoryPage(users: ${users.length}, page: $page, total: $total)';
}
