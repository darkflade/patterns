import 'package:flutter/material.dart';
import 'package:patterns/logic/3lab_logic.dart';
import 'package:patterns/logic/6lab_logic.dart';
import 'package:patterns/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notesModel = NotesModel();
  await notesModel.loadNotes();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: notesModel),
        ChangeNotifierProvider(create: (_) => AudioPlayerManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patterns',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const HomeScreen(title: 'Navigation'),
    );
  }
}
