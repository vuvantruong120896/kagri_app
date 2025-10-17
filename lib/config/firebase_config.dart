/// Firebase Configuration
/// Database URL and authentication settings for Realtime Database
class FirebaseConfig {
  // Firebase Realtime Database URL
  // This URL is used by the gateway firmware to store sensor data
  static const String databaseUrl =
      'https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Firebase Database Secret (for REST API authentication)
  // Note: In production, use Firebase Auth instead of database secrets
  // This secret is shared with the gateway firmware
  static const String authSecret = '0kMDkyCxejcJB350HrFlgBmb3Y5PsOiR90ZXf1MV';

  // Project ID
  static const String projectId = 'kagri-iot';

  // Region
  static const String region = 'asia-southeast1';

  // Whether to use mock data (for testing without Firebase)
  // Set to false to use real Firebase data from gateway
  static const bool useMockData = false;

  // Data retention period (days)
  // Old sensor data will be cleaned up after this period
  static const int dataRetentionDays = 30;

  // Real-time update interval (milliseconds)
  // How often to check for new data from Firebase
  static const int updateIntervalMs = 5000;
}
