import 'package:http/http.dart' as http;

/// Mobile sessions are deferred (Q2): no client header, so the API keeps the
/// pre-M2.12 behaviour for this build.
const String? apiClientHeader = null;

http.Client createApiClient() => http.Client();
