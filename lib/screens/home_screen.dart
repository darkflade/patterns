import 'package:flutter/material.dart';
import 'package:patterns/screens/project_login_screen.dart';
import 'lab5_7_login_screen.dart';
import '1lab_screen.dart';
import '2lab.dart';
import '3lab_screen.dart';
import '4lab_screen.dart';
import '6lab_screen.dart';

final String lab1 = "Лабораторная работа 1";
final String lab2 = "Лабораторная работа 2";
final String lab3 = "Лабораторная работа 3";
final String lab4 = "Лабораторная работа 4";
final String lab57 = "Лабораторная работа 5 и 7";
final String lab6 = "Лабораторная работа 6";
final String project = "Проект";

// A data class to hold information about each lab for the grid.
class _LabInfo {
  final String title;
  final String subtitle;
  final Widget screen;
  final IconData icon;
  final Color color;

  const _LabInfo({
    required this.title,
    required this.subtitle,
    required this.screen,
    required this.icon,
    required this.color,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    // A list of all the labs to display in the grid.
    final List<_LabInfo> labs = [
      _LabInfo(
        title: "Lab 1",
        subtitle: "TV Shop",
        screen: Lab1Screen(title: lab1),
        icon: Icons.tv_outlined,
        color: Colors.blue,
      ),
      _LabInfo(
        title: "Lab 2",
        subtitle: "Abstract Factory",
        screen: Lab2Screen(title: lab2),
        icon: Icons.directions_car_outlined,
        color: Colors.green,
      ),
      _LabInfo(
        title: "Lab 3",
        subtitle: "Prototype Pattern",
        screen: Lab3Screen(title: lab3),
        icon: Icons.copy_outlined,
        color: Colors.orange,
      ),
      _LabInfo(
        title: "Lab 4",
        subtitle: "Adapter Pattern",
        screen: Lab4Screen(title: lab4),
        icon: Icons.payment_outlined,
        color: Colors.purple,
      ),
       _LabInfo(
        title: "Labs 5 & 7",
        subtitle: "Decorator & Client-Server",
        screen: LoginScreen(title: lab57),
        icon: Icons.chat_outlined,
        color: Colors.red,
      ),
      _LabInfo(
        title: "Lab 6",
        subtitle: "State Pattern",
        screen: const Lab6Screen(),
        icon: Icons.atm_outlined,
        color: Colors.teal,
      ),
      _LabInfo(
        title: "Project",
        subtitle: "Decorator & Client-Server",
        screen: ProjectLoginScreen(title: project),
        icon: Icons.chat_outlined,
        color: Colors.red,
      )
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Theme.of(context).colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.0,
        ),
        itemCount: labs.length,
        itemBuilder: (context, index) {
          final lab = labs[index];
          return _LabCard(
            title: lab.title,
            subtitle: lab.subtitle,
            icon: lab.icon,
            color: lab.color,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => lab.screen),
              );
            },
          );
        },
      ),
    );
  }
}

// A custom card widget for the lab buttons.
class _LabCard extends StatelessWidget {
  const _LabCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withAlpha(128),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(179), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 50.0,
                color: Colors.white,
              ),
              const SizedBox(height: 12.0),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4.0),
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                 child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14.0,
                  ),
                  textAlign: TextAlign.center,
                             ),               ),            
            ],
          ),
        ),
      ),
    );
  }
}
