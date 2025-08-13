import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/globals.dart';

class LeaderboardPage extends StatefulWidget {
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool showHighestStreak = true;

  Future<List<Map<String, dynamic>>> _fetchLeaderboard() async {
    final orderByField = showHighestStreak ? 'highestStreak' : 'consistencyStreak';
    final snapshot = await FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy(orderByField, descending: true)
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

    final orderByField = showHighestStreak ? 'highestStreak' : 'consistencyStreak';
    final snap = await FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy(orderByField, descending: true)
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
            child: Column(
              children: [
                SizedBox(height: 10),
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [showHighestStreak, !showHighestStreak],
                  onPressed: (index) {
                    setState(() {
                      showHighestStreak = index == 0;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Highest Streak', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Consistency Streak', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Expanded(
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
                          'consistencyStreak': null,
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
                                _buildTopThree(top3, textColor, showHighestStreak),
                              SizedBox(height: 10),
                              _buildRemainingUsers(remaining),
                              SizedBox(height: 10),
                              _buildSelfRank(myRank, myData, selfRankColor, textColor, showHighestStreak),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopThree(List<Map<String, dynamic>> topThree, Color textColor, bool showHighestStreak) {
    final reordered = [
      if (topThree.length > 1) topThree[1], // 2nd
      if (topThree.isNotEmpty) topThree[0], // 1st
      if (topThree.length > 2) topThree[2], // 3rd
    ];
    final heights = [60.0, 90.0, 50.0]; // bigger heights
    final colors = [
      Colors.blueGrey[200] ?? Colors.blueGrey,
      Colors.amber[600] ?? Colors.amber,
      Colors.brown[300] ?? Colors.brown,
    ];
    final medals = [2, 1, 3];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(reordered.length, (i) {
        final user = reordered[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),
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
              SizedBox(height: 6),
              Text(
                user['displayName'] ?? '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                showHighestStreak
                    ? (user['highestStreak'] != null ? '${user['highestStreak']}d' : '---')
                    : (user['consistencyStreak'] != null ? '${user['consistencyStreak']}d' : '---'),
                style: TextStyle(fontSize: 14, color: textColor),
              ),
              SizedBox(height: 15),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRemainingUsers(List<Map<String, dynamic>> users) {
    return Column(
      children: List.generate(users.length, (index) {
        final user = users[index];
        final rank = index + 4;
        return Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(width: 24, child: Text(rank.toString(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600))),
                  SizedBox(width: 8),
                  Text(user['displayName']?.toString().isNotEmpty == true ? user['displayName'] : "---",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              Text(
                showHighestStreak
                    ? (user['highestStreak'] != null ? "${user['highestStreak']}d" : "---")
                    : (user['consistencyStreak'] != null ? "${user['consistencyStreak']}d" : "---"),
                style: TextStyle(color: Colors.grey[700]),
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSelfRank(int? rank, Map<String, dynamic>? data, Color cardColor, Color textColor, bool showHighestStreak) {
    if (rank == null) return SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Card(
        color: cardColor,
        elevation: 1,
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.orange,
            child: Text('$rank', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
          title: Text('${data?['displayName']} (You)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          trailing: Text(
            showHighestStreak
                ? '${data?['highestStreak'] ?? '---'}d'
                : '${data?['consistencyStreak'] ?? '---'}d',
            style: TextStyle(fontSize: 10, color: textColor),
          ),
        ),
      ),
    );
  }
}