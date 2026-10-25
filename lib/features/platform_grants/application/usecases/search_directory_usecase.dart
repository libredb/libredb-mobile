import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_directory_repository.dart';

class SearchDirectoryUseCase {
  const SearchDirectoryUseCase(this._repository);

  final IPlatformDirectoryRepository _repository;

  Future<Result<DirectoryPage>> call({required String query, required int page}) =>
      _repository.search(query: query, page: page);
}
