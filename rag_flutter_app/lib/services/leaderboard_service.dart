import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  static Future<void> updateLeaderboard({
    required String userId,
    required String displayName,
    required String? photoURL,
    required int highestStreak,
  }) async {
    final db = FirebaseFirestore.instance;

    // Only update the current user's entry in the leaderboard
    await db.collection('leaderboard').doc(userId).set({
      'userId': userId,
      'displayName': displayName,
      'photoURL': photoURL,
      'highestStreak': highestStreak,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
