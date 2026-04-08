import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class ApiService {
  Future<http.Response> uploadFile(File file, String filename) async {
    final uri = Uri.parse(ApiConstants.uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
      ));

    final streamedResponse = await request.send().timeout(ApiConstants.defaultTimeout);
    return http.Response.fromStream(streamedResponse);
  }

  Future<http.Response> getNotificationReply(String chatName, String message) async {
    final uri = Uri.parse(ApiConstants.notificationReplyUrl);
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: '{"chat_name": "$chatName", "message": "$message"}',
    ).timeout(ApiConstants.defaultTimeout);
  }

  Future<http.Response> deletePerson(String personName) async {
    final uri = Uri.parse(ApiConstants.deletePersonUrl(personName));
    return await http.delete(uri).timeout(ApiConstants.defaultTimeout);
  }

  Future<http.Response> updateMessage(String chatName, String sender, String text) async {
    final uri = Uri.parse(ApiConstants.updateMessageUrl);
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'chat_name': chatName,
        'sender': sender,
        'text': text,
      }),
    ).timeout(ApiConstants.defaultTimeout);
  }

  Future<http.Response> brainSync(String chatName, String contextData) async {
    final uri = Uri.parse(ApiConstants.brainSyncUrl);
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'chat_name': chatName,
        'context_data': contextData,
      }),
    ).timeout(ApiConstants.defaultTimeout);
  }

  Future<http.Response> getBrainSyncQuestions(String contextData) async {
    final uri = Uri.parse(ApiConstants.brainSyncQuestionsUrl);
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'context_data': contextData,
      }),
    ).timeout(ApiConstants.defaultTimeout);
  }

  Future<http.Response> finalizeBrainSync(String originalIntent, String userAnswers) async {
    final uri = Uri.parse(ApiConstants.brainSyncFinalizeUrl);
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'original_intent': originalIntent,
        'user_answers': userAnswers,
      }),
    ).timeout(ApiConstants.defaultTimeout); // 120s timeout for rule generation
  }
}
