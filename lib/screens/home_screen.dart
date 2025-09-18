import 'package:flutter/material.dart';
import '1lab_screen.dart';
import '2lab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  final String lab1 = "Лабораторная работа 1";
  final String lab2 = "Лабораторная работа 2";
  final String lab3 = "Лабораторная работа 3";
  final String lab4 = "Лабораторная работа 4";
  final String lab5 = "Лабораторная работа 5";
  final String lab6 = "Лабораторная работа 6";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ElevatedButton(
              child: Text(lab1),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab1Screen(title: lab1)),
                );
              },
            ),
            ElevatedButton(
              child: Text(lab2),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab2Screen(title: lab2)),
                );
              },
            ),
            ElevatedButton(
              child: Text(lab3),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab1Screen(title: lab3)),
                );
              },
            ),
            ElevatedButton(
              child: Text(lab4),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab1Screen(title: lab4)),
                );
              },
            ),
            ElevatedButton(
              child: Text(lab5),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab1Screen(title: lab5)),
                );
              },
            ),
            ElevatedButton(
              child: Text(lab6),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Lab1Screen(title: lab6)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
