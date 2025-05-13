import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/settings_button.dart';
import '/services/globals.dart';
import '/services/api_service.dart';
import '/services/leaderboard_service.dart';
import 'dart:convert';

class WorkoutPlanPage extends StatefulWidget {
  const WorkoutPlanPage({super.key});

  @override
  _WorkoutPlanPageState createState() => _WorkoutPlanPageState();
}

class _WorkoutPlanPageState extends State<WorkoutPlanPage> {
  DateTime selectedDate = DateTime.now();
  String username = '';
  String workoutLevel = ''; // Store the workout level
  Map<String, bool> _completedExercises = {};
  ApiService apiService = ApiService();
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _fetchUserData(); // Fetch the username and workout level when the page loads
  }

  // Fetch the username and workout level from Firestore
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final fetchedWorkoutLevel =
              userDoc['workoutLevelString'] ?? 'Moderate';

          if (mounted) {
            setState(() {
              username = userDoc['name'] ?? 'User';
              workoutLevel = fetchedWorkoutLevel;
            });
          }
        }

        final exercisesDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('exercise_completions')
            .doc(DateFormat('yyyy-MM-dd').format(selectedDate))
            .get();

        if (exercisesDoc.exists) {
          setState(() {
            _completedExercises = Map<String, bool>.from(exercisesDoc['completed_exercises'] ?? {});
          });
        } else {
          setState(() {
            _completedExercises = {}; // Reset if no data exists for the selected date
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  /// Fetch workout plans for the selected date
  Stream<QuerySnapshot> getWorkoutPlansForDate(DateTime selectedDate) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.empty();

    // Define the start and end of the selected date
    final startOfDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0, 0);
    final endOfDay = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, 23, 59, 59, 999);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workout_plans')
        .where('target_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('target_date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .orderBy('target_date', descending: true)
        .limit(1)
        .snapshots();
  }

  /// Handle date selection
  void onDateSelected(DateTime date) {
    setState(() {
      selectedDate = date;
      _completedExercises = {}; // Reset the completed exercises map
    });
    _fetchUserData(); // Fetch the completed exercises for the selected date
  }

  // Build user profile and menu section
  Widget buildProfileSection(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08), // 8% of screen width
      child: Row(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircleAvatar(
                  radius: screenWidth * 0.05, // 5% of screen width
                  backgroundColor: Colors.teal[50],
                  child: CircularProgressIndicator(color: Colors.teal),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return CircleAvatar(
                  radius: screenWidth * 0.05, // 5% of screen width
                  backgroundColor: Colors.teal[50],
                  backgroundImage: AssetImage("assets/default_profile.png"),
                );
              }
              String? profileImageUrl = snapshot.data!['profileImage'];
              return CircleAvatar(
                radius: screenWidth * 0.05, // 5% of screen width
                backgroundColor: Colors.teal[50],
                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? AssetImage(profileImageUrl)
                    : AssetImage("assets/default_profile.png"),
              );
            },
          ),
          SizedBox(width: screenWidth * 0.03), // 3% of screen width
          Text(
            "Welcome back,\n$username", // Display the username here
            style: TextStyle(
              fontSize: screenWidth * 0.035, // 4% of screen width
              fontWeight: FontWeight.w600,
              color: isDarkMode.value ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          SettingsButton(),
        ],
      ),
    );
  }

  Widget buildCalendar(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate the first and last day of the current month
    DateTime now = DateTime.now();
    DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    DateTime lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0);

    // Calculate the first and last day of the next month
    DateTime firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
    DateTime lastDayOfNextMonth = DateTime(now.year, now.month + 2, 0);

    // Calculate the total number of days to display
    int totalDays = lastDayOfCurrentMonth.day + lastDayOfNextMonth.day;

    // Calculate the index of today's date
    int todayIndex = now.isBefore(firstDayOfNextMonth)
        ? now.day - 1
        : lastDayOfCurrentMonth.day + now.day - 1;

    // Calculate the initial scroll offset to center today's date
    double itemWidth = screenWidth * 0.15;
    double marginHorizontal = screenWidth * 0.01;
    double totalItemWidth = itemWidth + 2 * marginHorizontal; // 0.17 * screenWidth
    double centerPosition = todayIndex * totalItemWidth + marginHorizontal + itemWidth / 2;
    double initialOffset = centerPosition - screenWidth / 2;
    if (initialOffset < 0) initialOffset = 0; // Ensure offset is non-negative

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: SizedBox(
        height: screenHeight * 0.11,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: totalDays,
          controller: ScrollController(
            initialScrollOffset: initialOffset,
          ),
          itemBuilder: (context, index) {
            DateTime date;
            if (index < lastDayOfCurrentMonth.day) {
              date = firstDayOfCurrentMonth.add(Duration(days: index));
            } else {
              date = firstDayOfNextMonth.add(Duration(days: index - lastDayOfCurrentMonth.day));
            }

            bool isSelected = date.day == selectedDate.day && date.month == selectedDate.month && date.year == selectedDate.year;
            bool isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

            return GestureDetector(
              onTap: () => onDateSelected(date),
              child: Container(
                width: screenWidth * 0.15,
                height: screenHeight * 0.1,
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                decoration: BoxDecoration(
                  color: isSelected ? (isDarkMode.value ? Colors.white30 : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(screenWidth * 0.07),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat.MMM().format(date),
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: isSelected
                            ? (isDarkMode.value ? Colors.tealAccent : Colors.teal)
                            : (isToday ? Colors.deepOrange[300] : (isDarkMode.value ? Colors.grey : Colors.black)),
                      ),
                    ),
                    Text(
                      "${date.day}",
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDarkMode.value ? Colors.tealAccent : Colors.teal)
                            : (isToday ? Colors.deepOrange[400] : (isDarkMode.value ? Colors.grey : Colors.black)),
                      ),
                    ),
                    Text(
                      DateFormat.E().format(date),
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: isSelected
                            ? (isDarkMode.value ? Colors.tealAccent : Colors.teal)
                            : (isToday ? Colors.deepOrange[300] : (isDarkMode.value ? Colors.grey : Colors.black)),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: EdgeInsets.only(top: screenHeight * 0.005),
                        width: screenWidth * 0.015,
                        height: screenHeight * 0.015,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal[200],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Build the workout level sentence
  Widget buildWorkoutLevel() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: screenHeight * 0.005), // 2% of screen height
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dumbbell icon
          Image.asset(
            'assets/dumbell.png', // Ensure the image exists in assets folder
            width: screenWidth * 0.08, // Adjust size as needed
            height: screenHeight * 0.08, // Adjust size as needed
            color: Colors.deepOrangeAccent,
          ),
          SizedBox(width: screenWidth * 0.01), // Spacing between icon and text
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: screenWidth * 0.04, // 4% of screen width
                fontWeight: FontWeight.w600,
                color: isDarkMode.value ? Colors.white : Colors.black,
              ),
              children: [
                const TextSpan(text: "Workout level : "), // Normal text
                TextSpan(
                  text: workoutLevel, // The variable part (e.g., "Moderate")
                  style: TextStyle(
                    color: Colors.orange[400], // Set only the workout level text to orange
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Workout plan generate/update button
  Widget buildWorkoutPlanGenerateButton(buttonText, isWeekly) {
    return ElevatedButton(
      onPressed: isGenerating
          ? null // Disable button when Generating
          : () async {
              setState(() => isGenerating = true);
              try {
                // Pass the selected date as the start_date parameter
                await apiService.getResponseFromApi(
                  "Update my workout plan",
                  isWeekly,
                  startDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                );
              } finally {
                setState(() => isGenerating = false);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isDarkMode.value ? Colors.grey[850] : Colors.teal[400],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: isGenerating
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(buttonText,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              )),
    );
  }

  /// Build workout plan card with a toggleable checkmark
  Widget buildWorkoutPlanCard(Map<String, dynamic> data) {
    try {
      bool isCurrentDay = selectedDate.day == DateTime.now().day &&
                        selectedDate.month == DateTime.now().month &&
                        selectedDate.year == DateTime.now().year;
      final rawContent = data['content'];
      final content =
          rawContent is String ? jsonDecode(rawContent) : rawContent;
      final double screenWidth = MediaQuery.of(context).size.width;
      
      return ValueListenableBuilder<bool>(
        valueListenable: isDarkMode,
        builder: (context, darkMode, child) {
          return Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: darkMode ? Colors.grey[800] : Colors.teal[50],
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 30, top: 30, right: 10, bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Text(
                          "Workout Plan",
                          style: TextStyle(
                            fontSize: screenWidth * 0.045, // 4.5% of screen width
                            fontWeight: FontWeight.w600,
                            color: darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        if (isCurrentDay)
                          buildWorkoutPlanGenerateButton("Update", "false"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
                    child: _buildWorkoutSection(content),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      return _buildErrorCard('Failed to load plan: ${e.toString()}');
    }
  }

  Widget _buildWorkoutSection(List<dynamic> exercises) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final List<Map<String, dynamic>> exercisesList = exercises.cast<Map<String, dynamic>>();
    bool isCurrentDay = selectedDate.day == DateTime.now().day &&
                        selectedDate.month == DateTime.now().month &&
                        selectedDate.year == DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: exercisesList.map((exercise) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // Adjust spacing
          child: Row(
            children: [
              if (isCurrentDay)
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    bool isCompleted = _completedExercises[exercise['exercise']] ?? false;
                    return Checkbox(
                      shape: CircleBorder(),
                      value: isCompleted,
                      activeColor: isDarkMode.value ? Colors.white : Colors.teal,
                      checkColor: isDarkMode.value ? Colors.teal : Colors.white,
                      side: BorderSide(
                        color: isDarkMode.value ? Colors.white24 : Colors.grey, // Border color for inactive state
                        width: 2, // Thickness of the border
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          _completedExercises[exercise['exercise']] = value ?? false;
                        });
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          _saveCompletedExercises(user.uid, selectedDate, _completedExercises, exercisesList);
                        }
                      },
                    );
                  },
                ),
              const SizedBox(width: 10), // Add some space between checkbox and text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise['exercise'],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: screenWidth * 0.035, // 4% of screen width
                        color: isDarkMode.value ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      "${exercise['duration']} mins • ${exercise['intensity']}",
                      style: TextStyle(
                        color: isDarkMode.value ? Colors.white70 : Colors.grey[700], // Optional: Subtle color
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build an error card
  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(error, style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> _saveCompletedExercises(String userId, DateTime targetDate, Map<String, bool> completedExercises, List<Map<String, dynamic>> allExercises) async {
    try {
      // Ensure all exercises are included
      for (var exercise in allExercises) {
        completedExercises.putIfAbsent(exercise['exercise'], () => false);
      }

      bool allCompleted = completedExercises.values.every((v) => v);

      // Fetch user data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};
      
      int currentStreak = data['consistencyStreak'] ?? 0;
      int highestStreak = data['highestStreak'] ?? 0;
      DateTime? lastStreakDate = (data['lastStreakDate'] as Timestamp?)?.toDate();
      DateTime? highestStreakDate = (data['highestStreakDate'] as Timestamp?)?.toDate();

      // Helper function for date comparison
      bool isSameDay(DateTime? a, DateTime? b) {
        if (a == null || b == null) return false;
        return a.year == b.year && a.month == b.month && a.day == b.day;
      }

      // Calculate new values
      int newStreak = currentStreak;
      int newHighestStreak = highestStreak;
      DateTime? newLastStreakDate = lastStreakDate;
      DateTime? newHighestStreakDate = highestStreakDate;

      if (allCompleted) {
        // Handle exercise completion
        final isConsecutive = lastStreakDate != null && 
            targetDate.difference(lastStreakDate).inDays == 1;
        
        newStreak = isConsecutive ? currentStreak + 1 : 1;
        newLastStreakDate = targetDate;

        // Update highest streak only if new streak exceeds previous record
        if (newStreak > highestStreak) {
          newHighestStreak = newStreak;
          newHighestStreakDate = targetDate;
        }
      } else {
        // Handle exercise unchecking
        if (isSameDay(lastStreakDate, targetDate)) {
          // Only modify if unchecking the last streak day
          newStreak = currentStreak > 0 ? currentStreak - 1 : 0;
          newLastStreakDate = lastStreakDate?.subtract(Duration(days: 1));

          // Roll back highest streak only if it was set on the uncheck date
          if (isSameDay(highestStreakDate, targetDate)) {
            newHighestStreak = newStreak;
            newHighestStreakDate = newLastStreakDate;
          }
        }
      }

      // Update Firestore documents
      final completionsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('exercise_completions')
          .doc(DateFormat('yyyy-MM-dd').format(targetDate));

      await completionsRef.set({
        'date': targetDate,
        'completed_exercises': completedExercises,
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'consistencyStreak': newStreak,
        'lastStreakDate': newLastStreakDate != null 
            ? Timestamp.fromDate(newLastStreakDate)
            : null,
        'highestStreak': newHighestStreak,
        'highestStreakDate': newHighestStreakDate != null 
            ? Timestamp.fromDate(newHighestStreakDate)
            : null,
      });
      // Call leaderboard update
      await LeaderboardService.updateLeaderboard(
        userId: userId,
        displayName: username,
        photoURL: data['profileImage'],
        highestStreak: newHighestStreak,
      );
    } catch (e) {
      print('Error saving exercises: $e');
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return Scaffold(
          backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
          body: Column(
            children: [
              // Responsive Image Section
              SizedBox(
                height: screenHeight * 0.25, // 25% of screen height
                child: Stack(
                  clipBehavior: Clip.none, // Allow content to overflow
                  fit: StackFit.expand,
                  children: [
                    // Background image with reduced opacity
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.5, // Reduced opacity for better visibility in dark mode
                        child: SizedBox(
                          width: double.infinity,
                          child: Image.asset(
                            'assets/workoutplan-banner.png', // Replace with your image path
                            fit: BoxFit.cover, // Ensures the image covers the entire area
                            alignment: Alignment.topCenter, // Aligns the image from the top
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay to create a fade effect at the bottom
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent, // Fully transparent at the top
                              darkMode ? Colors.grey[900]! : Colors.white, // Fade to background color
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Foreground content: Profile + Calendar
                    Column(
                      children: [
                        SizedBox(height: screenHeight * 0.05), // 5% of screen height
                        buildProfileSection(context), // Pass context for responsive sizes
                      ],
                    ),
                    // Calendar section overlapping the image
                    Positioned(
                      bottom: -screenHeight * 0.03, // Adjust to make it overlap the image
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: screenHeight * 0.13, // Ensure the calendar has enough height
                        child: buildCalendar(context), // Pass context for responsive sizes
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02), // 2% of screen height
              buildWorkoutLevel(), // Add workout level before workout cards
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: getWorkoutPlansForDate(selectedDate),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      // Handle no workout plans found
                      final now = DateTime.now();
                      final isWithinOneWeek = selectedDate.isAfter(now) && selectedDate.difference(now).inDays <= 7;
                      final isCurrentDay = selectedDate.day == now.day &&
                          selectedDate.month == now.month &&
                          selectedDate.year == now.year;
                      
                      if (isWithinOneWeek || isCurrentDay) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "No workout plans found",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: darkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 10),
                              buildWorkoutPlanGenerateButton("Generate a workout plan", "true"),
                            ],
                          ),
                        );
                      } else {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "No workout plans available for the selected date",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: darkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: snapshot.data!.docs.map((doc) {
                        return Column(
                          children: [
                            buildWorkoutPlanCard(doc.data() as Map<String, dynamic>),
                            const SizedBox(height: 100),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
