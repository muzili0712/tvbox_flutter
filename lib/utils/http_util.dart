import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/constants/app_constants.dart';

class HttpUtil {
  static Future<T> get<T>(String url, {Map<String, String>? headers}) async {
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    ).timeout(Duration(milliseconds: AppConstants.networkTimeout));
    
    if (response.statusCode == 200) {
      if (T == String) {
        return response.body as T;
      } else if (T == Map) {
        return json.decode(response.body) as T;
      } else if (T == List) {
        return json.decode(response.body) as T;
      }
    }
    throw Exception('Request failed: ${response.statusCode}');
  }
  
  static Future<T> post<T>(String url, dynamic body, {Map<String, String>? headers}) async {
    final response = await http.post(
      Uri.parse(url),
      body: json.encode(body),
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
    ).timeout(Duration(milliseconds: AppConstants.networkTimeout));
    
    if (response.statusCode == 200) {
      if (T == String) {
        return response.body as T;
      } else if (T == Map) {
        return json.decode(response.body) as T;
      } else if (T == List) {
        return json.decode(response.body) as T;
      }
    }
    throw Exception('Request failed: ${response.statusCode}');
  }
}
