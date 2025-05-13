import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rag_flutter_app/widgets/settings_button.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '/services/globals.dart';
import '/pages/leaderboard_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  _ProgressPageState createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // Add ValueNotifiers to manage the visibility of the charts
  final ValueNotifier<bool> _isCaloriesChartVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isExerciseChartVisible = ValueNotifier<bool>(false);

  //From Firestore database
  String _weight = '';
  String _height = '';
  int _consistencyStreak = 0;
  int _highestStreak = 0;
  List<FlSpot> _caloriesConsumedSpots = [];
  List<double> _exerciseCompletionPercentages = List.filled(7, 0.0);

  //From HealthKit
  String _caloriesBurnt = '';
  String _steps = '';
  double _mostCaloriesBurnt = 0.0;
  Map<DateTime, double> dailyCaloriesBurnt = {};
  List<FlSpot> _caloriesBurntSpots = [];

  final List<String> motivationalQuotes = [
    'Push yourself: "Push yourself because no one else is going to do it for you."',
    'Believe in yourself: "Believe you can and you’re halfway there."',
    'Stay positive: "Your limitation—it’s only your imagination."',
    'Work hard: "Hard work beats talent when talent doesn’t work hard."',
    'Never give up: "The harder you work for something, the greater you’ll feel when you achieve it."',
    'Stay focused: "Don’t stop when you’re tired. Stop when you’re done."',
    'Be consistent: "Success doesn’t come from what you do occasionally, it comes from what you do consistently."',
  ];

  // Initialize HealthFactory for accessing health data
  final health = Health();

  @override
  void initState() {
    super.initState();
    // Configure the health service and fetch initial data
    health.configure();
    _getBiometricData();
  }

  @override
  void dispose() {
    // Dispose the ValueNotifiers to avoid memory leaks
    _isCaloriesChartVisible.dispose();
    _isExerciseChartVisible.dispose();
    super.dispose();
  }

  Future<void> _getBiometricData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'No user is logged in';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _weight = userDoc.data()?['weight']?.toString() ?? 'N/A';
          _height = userDoc.data()?['height']?.toString() ?? 'N/A';
          _consistencyStreak = userDoc.data()?['consistencyStreak'] ?? 0;
          _highestStreak = userDoc.data()?['highestStreak'] ?? 0;
        });
      } else {
        setState(() {
          _weight = 'N/A';
          _height = 'N/A';
          _consistencyStreak = 0;
          _highestStreak = 0;
        });
      }

      // Calculate the start date for the last 7 days
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day - 6);

      // Fetch calories consumed data for the last 7 days from Firestore
      final startTimestamp = Timestamp.fromDate(startDate);
      final caloriesConsumedData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('calories_consumed')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .orderBy('date', descending: false)
          .get();

      Map<DateTime, double> caloriesConsumedMap = {};
      for (var doc in caloriesConsumedData.docs) {
        DateTime date = (doc.data()['date'] as Timestamp).toDate();
        date = DateTime(date.year, date.month, date.day); // Normalize to midnight
        double calories = doc.data()['calories_consumed'].toDouble();
        caloriesConsumedMap[date] = calories; // Assumes one entry per day; sum if multiple
      }

      // Fetch health data for the last 7 days
      await _fetchHealthData(startDate, now);

      // Generate spots for the last 7 days
      List<FlSpot> caloriesConsumedSpots = [];
      List<FlSpot> caloriesBurntSpots = [];
      for (int i = 0; i < 7; i++) {
        DateTime day = startDate.add(Duration(days: i));
        double consumed = caloriesConsumedMap[day] ?? 0.0; // 0 if no data
        double burnt = dailyCaloriesBurnt[day] ?? 0.0; // 0 if no data
        caloriesConsumedSpots.add(FlSpot(i.toDouble(), consumed));
        caloriesBurntSpots.add(FlSpot(i.toDouble(), burnt));
      }

      // Fetch exercise completion data
      List<double> exerciseCompletionPercentages = await _fetchExerciseCompletionData(startDate, now);

      setState(() {
        _caloriesConsumedSpots = caloriesConsumedSpots;
        _caloriesBurntSpots = caloriesBurntSpots;
        _exerciseCompletionPercentages = exerciseCompletionPercentages;
      });
    } catch (e) {
      setState(() {
        _weight = 'Error';
        _height = 'Error';
        _caloriesBurnt = 'Error';
        _steps = 'Error';
        _consistencyStreak = 0;
        _highestStreak = 0;
      });
      debugPrint('Error fetching biometric data: $e');
    }
  }

  Future<void> _fetchHealthData(DateTime startDate, DateTime now) async {
    try {
      // Request activity recognition permission on Android
      if (Platform.isAndroid) {
        await Permission.activityRecognition.request();
      }

      // Define health data types and permissions
      List<HealthDataType> types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
      List<HealthDataAccess> permissions =
          types.map((e) => HealthDataAccess.READ).toList();

      // Check if permissions are granted; request if not
      bool? hasPermissions =
          await health.hasPermissions(types, permissions: permissions);
      if (hasPermissions == null || !hasPermissions) {
        bool authorized =
            await health.requestAuthorization(types, permissions: permissions);
        if (!authorized) {
          setState(() {
            _caloriesBurnt = 'Permission denied';
            _steps = 'Permission denied';
          });
          return;
        }
      }

      // Fetch total steps today
      final midnight = DateTime(now.year, now.month, now.day);
      int? steps = await health.getTotalStepsInInterval(midnight, now);

      // Fetch calories burnt for the last 7 days
      List<HealthDataPoint> energyData = await health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      Map<DateTime, double> dailyCaloriesBurntTemp = {};
      for (var point in energyData) {
        if (point.value is NumericHealthValue) {
          DateTime date = DateTime(
              point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
          double calories = (point.value as NumericHealthValue).numericValue.toDouble();
          dailyCaloriesBurntTemp[date] =
              (dailyCaloriesBurntTemp[date] ?? 0) + calories;
        }
      }

      // Calculate most calories burnt in the last 7 days
      double mostCaloriesBurnt = 0.0;
      dailyCaloriesBurntTemp.forEach((date, calories) {
        if (calories > mostCaloriesBurnt) {
          mostCaloriesBurnt = calories;
        }
      });

      // Update state with fetched data
      setState(() {
        _steps = steps?.toString() ?? '0';
        _caloriesBurnt = (dailyCaloriesBurntTemp[midnight] ?? 0).toStringAsFixed(0);
        _mostCaloriesBurnt = mostCaloriesBurnt;
        dailyCaloriesBurnt = dailyCaloriesBurntTemp; // Store for chart use
      });
    } catch (e) {
      setState(() {
        _caloriesBurnt = 'Error';
        _steps = 'Error';
      });
      debugPrint('Error fetching health data: $e');
    }
  }

  Future<List<double>> _fetchExerciseCompletionData(DateTime startDate, DateTime now) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'No user is logged in';
      }

      final exerciseCompletionData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('exercise_completions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: false)
          .get();

      Map<DateTime, double> completionMap = {};
      for (var doc in exerciseCompletionData.docs) {
        DateTime date = (doc.data()['date'] as Timestamp).toDate();
        date = DateTime(date.year, date.month, date.day); // Normalize to midnight
        Map<String, dynamic> completedExercises = doc.data()['completed_exercises'] ?? {};
        int totalExercises = completedExercises.length;
        int completedCount = completedExercises.values.where((v) => v == true).length;
        double completionPercentage = totalExercises > 0 ? (completedCount / totalExercises) * 100 : 0.0;
        completionMap[date] = completionPercentage;
      }

      List<double> completionPercentages = [];
      for (int i = 0; i < 7; i++) {
        DateTime day = startDate.add(Duration(days: i));
        completionPercentages.add(completionMap[day] ?? 0.0); // Default to 0% if no data
      }

      return completionPercentages;
    } catch (e) {
      debugPrint('Error fetching exercise completion data: $e');
      return List.filled(7, 0.0); // Return 0% for all days in case of error
    }
  }

  int _dayOfYear(DateTime date) {
    return int.parse(DateFormat("D").format(date));
  }

  String getDailyQuote() {
    int dayOfYear = _dayOfYear(DateTime.now());
    return motivationalQuotes[dayOfYear % motivationalQuotes.length];
  }

  Widget _buildUserCurrentDataSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDarkMode.value ? Colors.grey[800] : Colors.teal[50],
        borderRadius: BorderRadius.circular(13.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Weight: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '$_weight kg',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Height: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '$_height cm',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 15.0),
          Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.red),
              SizedBox(width: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Calories Burnt Today: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '$_caloriesBurnt kcal',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.0),
          Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.lightGreen),
              SizedBox(width: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Calories Consumed Today: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '${_caloriesConsumedSpots.isNotEmpty ? _caloriesConsumedSpots.last.y.toStringAsFixed(0) : 'err'}  kcal',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.0),
          Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.blue),
              SizedBox(width: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Total Steps Today: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '$_steps steps',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.0),
          Row(
            children: [
              Icon(Icons.fitness_center, color: Colors.orange),
              SizedBox(width: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Current Consistency Streak: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode.value ? Colors.white : Colors.black)),
                    TextSpan(
                        text: '$_consistencyStreak days',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode.value ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
          decoration: BoxDecoration(
            color: Colors.redAccent[100],
            borderRadius: BorderRadius.circular(13.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Achievements',
                style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Most Calories Burnt: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                    TextSpan(
                        text: '${_mostCaloriesBurnt.toInt()} kcal',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: Colors.black)),
                  ],
                ),
              ),
              SizedBox(height: 10.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'Highest Streak: ',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    TextSpan(
                        text: '$_highestStreak days',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/achievements.png',
          width: 90.0,
          height: 90.0,
        ),
      ],
    );
  }

  Widget _buildLeaderboardButton() {
    return SizedBox(
      width: double.infinity, // Match the width of the userCurrentDataSection
      child: InkWell(
        onTap: () {
          // Navigate to the LeaderboardPage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LeaderboardPage()),
          );
        },
        borderRadius: BorderRadius.circular(100.0), // Match the button's border radius
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15.0), // Vertical padding
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)], // Gold to dark orange
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(100.0), // Rounded corners
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 13.0),
                Text(
                  'See how you rank',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white, // Text color
                  ),
                ),
                SizedBox(width: 13.0),
                Icon(
                  Icons.line_axis_rounded,
                  color: Colors.white, // Icon color
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMotivationalQuoteSection() {
    String dailyQuote = getDailyQuote();
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDarkMode.value ? Colors.grey[800] : Colors.yellow[50],
        borderRadius: BorderRadius.circular(13.0),
      ),
      child: Text(
        dailyQuote,
        style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: isDarkMode.value ? Colors.white : Colors.black),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.deepOrangeAccent, 'Calories Consumed'),
          SizedBox(width: 20),
          _buildLegendItem(Colors.blueAccent, 'Calories Burnt'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: isDarkMode.value ? Colors.grey : Colors.blueGrey),
        ),
      ],
    );
  }

  Widget _buildCaloriesOverviewChart() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Card(
            elevation: 0,
            color: isDarkMode.value ? Colors.grey[900] : Colors.white,
            child: Padding(
              padding: const EdgeInsets.only(left: 5.0, right: 15.0),
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    _buildCaloriesConsumedLineChartBarData(),
                    _buildCaloriesBurntLineChartBarData(),
                  ],
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 100,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.blueGrey[100],
                        strokeWidth: 0.5,
                        dashArray: [5],
                      );
                    },
                  ),
                  titlesData: _buildTitlesData(),
                ),
              ),
            ),
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  LineChartBarData _buildCaloriesConsumedLineChartBarData() {
    return LineChartBarData(
        spots: _caloriesConsumedSpots,
        isCurved: true,
        color: Colors.deepOrangeAccent,
        barWidth: 4,
        belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(colors: [
              Colors.deepOrangeAccent.withOpacity(0.5),
              Colors.deepOrangeAccent.withOpacity(0.1),
            ])));
  }

  LineChartBarData _buildCaloriesBurntLineChartBarData() {
    return LineChartBarData(
        spots: _caloriesBurntSpots,
        isCurved: true,
        color: Colors.blueAccent,
        barWidth: 4,
        belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(colors: [
              Colors.blueAccent.withOpacity(0.5),
              Colors.blueAccent.withOpacity(0.1),
            ])));
  }

  FlTitlesData _buildTitlesData() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - 6);

    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            if (index >= 0 && index < 7) {
              DateTime day = startDate.add(Duration(days: index));
              String weekday;
              switch (day.weekday) {
                case 1:
                  weekday = 'Mon';
                  break;
                case 2:
                  weekday = 'Tue';
                  break;
                case 3:
                  weekday = 'Wed';
                  break;
                case 4:
                  weekday = 'Thu';
                  break;
                case 5:
                  weekday = 'Fri';
                  break;
                case 6:
                  weekday = 'Sat';
                  break;
                case 7:
                  weekday = 'Sun';
                  break;
                default:
                  weekday = ''; // Shouldn’t happen
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  weekday,
                  style: TextStyle(fontSize: 10, color: isDarkMode.value ? Colors.grey : Colors.red),
                ),
              );
            }
            return Text('');
          },
          reservedSize: 30,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 100,
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 8.0, color: Colors.blueGrey),
            );
          },
          reservedSize: 30,
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  Widget _buildExerciseCompletionChart() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Card(
            elevation: 0,
            color: isDarkMode.value ? Colors.grey[900] : Colors.white,
            child: Padding(
              padding: const EdgeInsets.only(left: 5.0, right: 15.0),
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(7, (index) {
                    double percentage = index < _exerciseCompletionPercentages.length
                        ? _exerciseCompletionPercentages[index]
                        : 0.0; // Fallback to 0.0 if index is out of range
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: percentage,
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.lightGreen],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 15,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ],
                    );
                  }),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.blueGrey[100],
                        strokeWidth: 0.5,
                        dashArray: [5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < 7) {
                            DateTime day = DateTime.now().subtract(Duration(days: 6 - index));
                            return Text(
                              DateFormat.E().format(day),
                              style: TextStyle(fontSize: 10, color: isDarkMode.value ? Colors.grey : Colors.black),
                            );
                          }
                          return Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(fontSize: 8.0, color: Colors.blueGrey),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String todayDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    double screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return Scaffold(
          backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
          appBar: AppBar(
            backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                todayDate,
                style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                    color: darkMode ? Colors.white : Colors.black),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 25.0, bottom: 5.0),
                child: SettingsButton(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _getBiometricData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                child: Column(
                  children: [
                    _buildUserCurrentDataSection(),
                    SizedBox(height: 13.0),
                    _buildAchievementSection(),
                    SizedBox(height: 13.0),
                    _buildLeaderboardButton(),
                    SizedBox(height: 13.0),
                    _buildMotivationalQuoteSection(),
                    SizedBox(height: 13.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: 10.0),
                        Text(
                          "Calories Overview",
                          style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w600,
                              color: darkMode ? Colors.white : Colors.black),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            _isCaloriesChartVisible.value = !_isCaloriesChartVisible.value;
                          },
                          icon: ValueListenableBuilder<bool>(
                            valueListenable: _isCaloriesChartVisible,
                            builder: (context, isVisible, child) {
                              return Icon(
                                isVisible ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: darkMode ? Colors.white70 : Colors.blue[200],
                                size: screenWidth * 0.07,
                              );
                            },
                          ),
                          tooltip: 'Toggle Chart Visibility',
                        ),
                      ],
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isCaloriesChartVisible,
                      builder: (context, isVisible, child) {
                        return isVisible ? Column(
                          children: [
                            SizedBox(height: 15.0),
                            _buildCaloriesOverviewChart(),
                          ],
                        ) : SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: 20.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: 10.0),
                        Text(
                          "Exercise Completion Overview",
                          style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w600,
                              color: darkMode ? Colors.white : Colors.black),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            _isExerciseChartVisible.value = !_isExerciseChartVisible.value;
                          },
                          icon: ValueListenableBuilder<bool>(
                            valueListenable: _isExerciseChartVisible,
                            builder: (context, isVisible, child) {
                              return Icon(
                                isVisible ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: darkMode ? Colors.white70 : Colors.blue[200],
                                size: screenWidth * 0.07,
                              );
                            },
                          ),
                          tooltip: 'Toggle Chart Visibility',
                        ),
                      ],
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isExerciseChartVisible,
                      builder: (context, isVisible, child) {
                        return isVisible ? Column(
                          children: [
                            SizedBox(height: 15.0),
                            _buildExerciseCompletionChart(),
                          ],
                        ) : SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: 100.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}