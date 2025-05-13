import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/globals.dart';

class LeaderboardPage extends StatelessWidget {
  Future<List<Map<String, dynamic>>> _fetchLeaderboard() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy('highestStreak', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> _findMyRankAndData() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy('highestStreak', descending: true)
        .get();

    for (var i = 0; i < snap.docs.length; i++) {
      if (snap.docs[i].id == me) {
        final data = snap.docs[i].data();
        data['uid'] = snap.docs[i].id;
        return {'rank': i + 1, 'data': data};
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        final backgroundColor = darkMode ? Colors.grey[900] ?? Colors.black : Colors.white;
        final textColor = darkMode ? Colors.white : Colors.black;
        final cardColor = darkMode ? Colors.grey[800] ?? Colors.grey : Colors.teal[50] ?? Colors.teal;
        final borderColor = darkMode ? Colors.grey[700] ?? Colors.grey : Colors.teal[300] ?? Colors.teal;
        final selfRankColor = darkMode ? Colors.orange[800] ?? Colors.orange : Colors.orange[50] ?? Colors.orange;

        return Scaffold(
          appBar: AppBar(
            title: Text('Leaderboard', style: TextStyle(color: textColor)),
            backgroundColor: darkMode ? Colors.grey[900] : Colors.transparent,
            iconTheme: IconThemeData(color: darkMode ? Colors.grey : Colors.black),
          ),
          backgroundColor: backgroundColor,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchLeaderboard(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                final top3 = list.take(3).toList();
                final List<Map<String, dynamic>> remaining = list.length > 3
                    ? list.sublist(3)
                    : <Map<String, dynamic>>[];

                while (remaining.length < 7) {
                  remaining.add({
                    'uid': '',
                    'displayName': '',
                    'highestStreak': null,
                  });
                }

                return FutureBuilder<Map<String, dynamic>?>(
                  future: _findMyRankAndData(),
                  builder: (c, rs) {
                    final result = rs.data;
                    final myRank = result?['rank'] as int?;
                    final myData = result?['data'] as Map<String, dynamic>?;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (top3.length == 3)
                          _buildTopThree(top3, textColor),
                        SizedBox(height: 10),
                        _buildRemainingUsers(
                            remaining, FirebaseAuth.instance.currentUser?.uid, cardColor, borderColor, textColor),
                        SizedBox(height: 10),
                        _buildSelfRank(myRank, myData, selfRankColor, textColor),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopThree(List<Map<String, dynamic>> topThree, Color textColor) {
    final reordered = [
      if (topThree.length > 1) topThree[1], // 2nd
      if (topThree.isNotEmpty) topThree[0], // 1st
      if (topThree.length > 2) topThree[2], // 3rd
    ];
    final heights = [60.0, 100.0, 50.0];
    final colors = [
      Colors.blueGrey[200] ?? Colors.blueGrey, // 2nd (silver-like)
      Colors.amber[600] ?? Colors.amber,       // 1st (gold)
      Colors.brown[300] ?? Colors.brown,       // 3rd (bronze)
    ];
    final medals = [2, 1, 3];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(reordered.length, (i) {
        final user = reordered[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors[i],
                backgroundImage: user['photoURL'] != null
                    ? AssetImage(user['photoURL'])
                    : null,
                child: user['photoURL'] == null
                    ? Icon(Icons.person, size: 24, color: textColor)
                    : null,
              ),
              SizedBox(height: 4),
              Text(
                user['displayName'] ?? '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Container(
                height: heights[i],
                width: 50,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  medals[i].toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                user['highestStreak'] != null
                    ? '${user['highestStreak']} d'
                    : '---',
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRemainingUsers(List<Map<String, dynamic>> remaining, String? me, Color cardColor, Color borderColor, Color textColor) {
    const rowCount = 7;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 2, color: borderColor),
      ),
      child: Column(
        children: List.generate(rowCount, (idx) {
          final bool hasData = idx < remaining.length;
          final user = hasData ? remaining[idx] : null;
          final rank = idx + 4;
          final isMe = hasData && user!['uid'] == me;

          return Card(
            color: isMe ? Colors.teal[100] : cardColor,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
            elevation: 0,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: hasData ? Colors.teal : Colors.grey,
                child: Text(
                  '$rank',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(
                (hasData && (user!['displayName']?.toString().trim().isNotEmpty ?? false))
                    ? '${user['displayName']}'
                    : '---',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              trailing: Text(
                hasData && user!['highestStreak'] != null ? '${user['highestStreak']}d' : '---',
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelfRank(int? rank, Map<String, dynamic>? data, Color cardColor, Color textColor) {
    if (rank == null) return SizedBox(); // Only hide if rank is null
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Card(
        color: cardColor,
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 7),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.orange,
            child: Text('$rank', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          title: Text('${data?['displayName']} (You)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          trailing: Text('${data?['highestStreak'] ?? '---'}d', style: TextStyle(fontSize: 12, color: textColor)),
        ),
      ),
    );
  }
}
