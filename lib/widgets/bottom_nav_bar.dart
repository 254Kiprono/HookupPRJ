import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Color selectedColor;
  final Color unselectedColor;
  final ValueChanged<int>? onTap; // Add callback for index changes

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap, // Use the passed callback
      type: BottomNavigationBarType.fixed,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('3'),
            child: Icon(Icons.message),
          ),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
