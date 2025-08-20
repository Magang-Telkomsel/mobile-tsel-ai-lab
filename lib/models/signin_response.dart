class SigninResponse {
  String message;
  bool? success;
  dynamic data;
  String? error;

  SigninResponse({required this.message, this.success, this.data, this.error});

  factory SigninResponse.fromJson(Map<String, dynamic> json) {
    return SigninResponse(
      message: json['message'] ?? '',
      success: json['success'],
      data: json['data'],
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'success': success,
      'data': data,
      'error': error,
    };
  }

  @override
  String toString() {
    return 'SigninResponse(message: $message, success: $success, data: $data, error: $error)';
  }
}
