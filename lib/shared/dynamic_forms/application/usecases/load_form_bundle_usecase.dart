import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/dynamic_forms/domain/entities/form_bundle_entity.dart';
import 'package:libredb_mobile/shared/dynamic_forms/domain/repositories/dynamic_form_repository.dart';

class LoadFormBundleUseCase {
  const LoadFormBundleUseCase(this._repository);

  final IDynamicFormRepository _repository;

  Future<Result<FormBundleEntity>> call(String basePath, {String? pathParams}) =>
      _repository.fetchBundle(basePath, pathParams: pathParams);
}
