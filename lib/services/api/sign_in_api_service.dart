import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../../models/signin_response.dart';

class SignInApiService {
  final String apiUrl = dotenv.env['API_URL'].toString();

  Future<SigninResponse> signIn(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    try {
      print('📤 Registering user: $firstName $lastName');
      print('📧 Email: $email');
      print('🌐 API URL: $apiUrl/auth-api/post/register');

      final response = await http.post(
        Uri.parse('$apiUrl/auth-api/post/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "nama_depan": firstName,
          "nama_belakang": lastName,
          "email": email,
          "password": password,
        }),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Registration successful');

        return SigninResponse(
          message: responseData['message'] ?? 'Registration successful',
          success: true,
          data: responseData['data'] ?? responseData,
        );
      } else {
        print('❌ Registration failed: ${response.statusCode}');
        final errorData = jsonDecode(response.body);

        return SigninResponse(
          message: errorData['message'] ?? 'Registration failed',
          success: false,
          error: errorData['error'] ?? 'Server error',
          data: errorData,
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');

      return SigninResponse(
        message: 'Network error or server not available',
        success: false,
        error: e.toString(),
      );
    }
  }
}
