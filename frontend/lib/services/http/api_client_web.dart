import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Sent as `X-DevLink-Client` on every API request: the API then keeps the refresh
/// token in an HttpOnly cookie (M2_AUTH_DESIGN §4.1).
// Nullable to match the io version, which sends no header.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? apiClientHeader = 'web';

/// `withCredentials` lets the browser store the HttpOnly refresh cookie that login
/// sets and send it to `session/refresh` and `session/logout` (the cookie's path
/// limits it to those). The app never reads the cookie.
http.Client createApiClient() => BrowserClient()..withCredentials = true;
