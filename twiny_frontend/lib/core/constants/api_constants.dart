class ApiConstants {
  static const Duration defaultTimeout = Duration(minutes: 2);
  static const String baseUrl = 'https://862a-2401-4900-1c0e-108f-4c5a-4d3b-de6c-2499.ngrok-free.app';
  static const String uploadEndpoint = '/api/chat/upload';
  static const String notificationReplyEndpoint = '/api/notification/reply';
  static const String deletePersonEndpoint = '/api/chat/person/';
  static const String updateMessageEndpoint = '/api/chat/update_message';
  static const String brainSyncEndpoint = '/api/notification/brain_sync';
  static const String brainSyncQuestionsEndpoint = '/api/notification/brain_sync/questions';
  static const String brainSyncFinalizeEndpoint = '/api/notification/brain_sync/finalize';

  static String get uploadUrl => '$baseUrl$uploadEndpoint';
  static String get notificationReplyUrl => '$baseUrl$notificationReplyEndpoint';
  static String get updateMessageUrl => '$baseUrl$updateMessageEndpoint';
  static String get brainSyncUrl => '$baseUrl$brainSyncEndpoint';
  static String get brainSyncQuestionsUrl => '$baseUrl$brainSyncQuestionsEndpoint';
  static String get brainSyncFinalizeUrl => '$baseUrl$brainSyncFinalizeEndpoint';
  static String deletePersonUrl(String personName) => '$baseUrl$deletePersonEndpoint$personName';
}
