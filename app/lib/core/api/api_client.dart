import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import 'token_store.dart';

/// Server error in the API's standard shape: { error: { code, message, details: { reason, … } } }.
class ApiException implements Exception {
  ApiException({required this.status, required this.code, required this.message, this.details = const {}});

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  String? get reason => details['reason'] as String?;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;

  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final e = data['error'] as Map;
        final details = e['details'];
        return ApiException(
          status: error.response?.statusCode ?? 0,
          code: (e['code'] ?? 'ERROR').toString(),
          message: (e['message'] ?? 'Something went wrong').toString(),
          details: details is Map<String, dynamic> ? details : const {},
        );
      }
      final offline = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
      return ApiException(
        status: error.response?.statusCode ?? 0,
        code: offline ? 'NETWORK' : 'ERROR',
        message: switch (error.type) {
          DioExceptionType.connectionError => "Can't reach Jeya Hyper Store right now. Check your internet and try again.",
          DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout =>
            'The store is taking too long to respond. Please try again.',
          _ => 'Something went wrong. Please try again.',
        },
      );
    }
    return ApiException(status: 0, code: 'ERROR', message: 'Something went wrong. Please try again.');
  }
}

/// Dio wrapper: attaches the access token, refreshes it on `token_expired`
/// (single-flight — concurrent 401s share ONE refresh, because the backend rotates
/// refresh tokens and a second parallel refresh would log the user out), retries once.
class ApiClient {
  ApiClient(this._tokens, {required this.onSessionExpired}) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {'accept': 'application/json'},
    ));
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['auth'] != false) {
          final tokens = await _tokens.read();
          if (tokens != null) options.headers['authorization'] = 'Bearer ${tokens.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final data = error.response?.data;
        Object? reason;
        if (data is Map && data['error'] is Map) {
          final details = (data['error'] as Map)['details'];
          if (details is Map) reason = details['reason'];
        }
        final canRetry = error.response?.statusCode == 401 &&
            reason == 'token_expired' &&
            error.requestOptions.extra['retried'] != true;
        if (!canRetry) return handler.next(error);

        final refreshed = await _refreshOnce();
        if (!refreshed) return handler.next(error);
        try {
          final opts = error.requestOptions..extra['retried'] = true;
          final tokens = await _tokens.read();
          opts.headers['authorization'] = 'Bearer ${tokens!.accessToken}';
          handler.resolve(await _dio.fetch(opts));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ));
  }

  final TokenStore _tokens;
  final Future<void> Function() onSessionExpired;
  late final Dio _dio;
  Completer<bool>? _refreshing;

  Future<bool> _refreshOnce() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = _refreshing = Completer<bool>();
    () async {
      try {
        final tokens = await _tokens.read();
        if (tokens == null) return completer.complete(false);
        final res = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 15)))
            .post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': tokens.refreshToken});
        final body = res.data!;
        await _tokens.save(AuthTokens(accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String));
        completer.complete(true);
      } catch (_) {
        await _tokens.clear();
        await onSessionExpired();
        completer.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return completer.future;
  }

  Future<T> _send<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      // 204 No Content (logout, delete) arrives as an empty body.
      return (data is Map<String, dynamic> ? data : <String, dynamic>{}) as T;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Reads are safe to repeat: retry twice on a network blip or a "busy" answer (502/503/504)
  /// before showing an error — covers server restarts and flaky mobile data.
  Future<Map<String, dynamic>> _withRetry(Future<Map<String, dynamic>> Function() call) async {
    const delays = [Duration(milliseconds: 700), Duration(seconds: 2)];
    for (var attempt = 0; ; attempt++) {
      try {
        return await call();
      } on ApiException catch (e) {
        final transient = e.isNetwork || e.status == 502 || e.status == 503 || e.status == 504;
        if (!transient || attempt >= delays.length) rethrow;
        await Future<void>.delayed(delays[attempt]);
      }
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _withRetry(() => _send(() => _dio.get(path, queryParameters: query, options: Options(extra: {'auth': auth}))));

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) =>
      _send(() => _dio.post(path, data: body ?? const <String, dynamic>{}, options: Options(extra: {'auth': auth})));

  Future<Map<String, dynamic>> put(String path, {Object? body}) => _send(() => _dio.put(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _send(() => _dio.patch(path, data: body));

  Future<Map<String, dynamic>?> delete(String path) => _send(() => _dio.delete(path));
}
