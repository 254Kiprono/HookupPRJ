import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.4),
        selectedLabelStyle: GoogleFonts.sora(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
        unselectedLabelStyle: GoogleFonts.sora(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.explore_outlined),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.explore),
            ),
            label: 'Discovery',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.bed_outlined),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.bed),
            ),
            label: 'BnB',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Badge(
                backgroundColor: AppConstants.primaryColor,
                label: Text('3', style: TextStyle(fontSize: 10)),
                child: Icon(Icons.chat_bubble_outline),
              ),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Badge(
                backgroundColor: AppConstants.primaryColor,
                label: Text('3', style: TextStyle(fontSize: 10)),
                child: Icon(Icons.chat_bubble),
              ),
            ),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.person_outline),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.person),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
