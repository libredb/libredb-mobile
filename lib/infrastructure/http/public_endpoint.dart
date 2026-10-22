import 'package:dio/dio.dart';

/// An API endpoint, by HTTP method and by the path the `ApiClient` method is called with, before any path parameters.
typedef PublicEndpoint = ({String method, String path});

/// The API endpoints that serve requests without a session: the app config, and Studio's liveness and readiness.
///
/// The lifecycle checks read the app config, and the Studio status check Studio's liveness, when the app starts and
/// when it comes back to the foreground, so before sign-in as well. Studio serves `/api/health` and `/api/ready`
/// without a session (libredb-studio `src/proxy.ts`). The sign-in and the token refresh go to the identity provider,
/// never to the API.
///
/// `AuthInterceptor` sends no token to them, `TokenRefreshInterceptor` passes a 401 from them on without a refresh, and
/// `MockInterceptor` answers them without a token. Any other method on the same path is not public. The app's own
/// routes are not API endpoints and do not belong here.
const publicEndpoints = <PublicEndpoint>{
  (method: 'GET', path: '/app/config'),
  (method: 'GET', path: '/health'),
  (method: 'GET', path: '/ready'),
};

/// Whether [options] targets one of the [publicEndpoints].
bool isPublicEndpoint(RequestOptions options) =>
    publicEndpoints.contains((method: options.method, path: options.extra['_basePath'] as String? ?? options.path));
