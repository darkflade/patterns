import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Абстрактный прототип
abstract class Note {
  String title;
  String content;

  Note({required this.title, required this.content});

  Note clone();
  Map<String, dynamic> toJson();
}

// --------------------
// Конкретные заметки
// --------------------

class SimpleNote extends Note {
  SimpleNote({required super.title, required super.content});

  @override
  Note clone() {
    return SimpleNote(title: title, content: content);
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "simple",
    "title": title,
    "content": content,
  };

  static SimpleNote fromJson(Map<String, dynamic> json) =>
      SimpleNote(title: json["title"], content: json["content"]);
}

class TodoNote extends Note {
  List<TodoItem> items;

  TodoNote({required super.title, required super.content, required this.items});

  @override
  Note clone() {
    return TodoNote(
      title: title,
      content: content,
      items: items.map((e) => e.clone()).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "todo",
    "title": title,
    "content": content,
    "items": items.map((e) => e.toJson()).toList(),
  };

  static TodoNote fromJson(Map<String, dynamic> json) => TodoNote(
    title: json["title"],
    content: json["content"],
    items: (json["items"] as List)
        .map((e) => TodoItem.fromJson(e))
        .toList(),
  );
}

class TodoItem {
  String text;
  bool done;

  TodoItem({required this.text, this.done = false});

  TodoItem clone() => TodoItem(text: text, done: done);

  Map<String, dynamic> toJson() => {"text": text, "done": done};

  static TodoItem fromJson(Map<String, dynamic> json) =>
      TodoItem(text: json["text"], done: json["done"]);
}


class TaggedNote extends Note {
  String tag;

  TaggedNote({required super.title, required super.content, required this.tag});

  @override
  Note clone() {
    return TaggedNote(title: title, content: content, tag: tag);
  }

  @override
  Map<String, dynamic> toJson() => {
    "type": "tagged",
    "title": title,
    "content": content,
    "tag": tag,
  };

  static TaggedNote fromJson(Map<String, dynamic> json) => TaggedNote(
    title: json["title"],
    content: json["content"],
    tag: json["tag"] ?? "",
  );
}

// --------------------
// Factory Method
// --------------------

abstract class NoteCreator {
  Note createNote();
}

class SimpleNoteCreator extends NoteCreator {
  @override
  Note createNote() => SimpleNote(title: "Новая заметка", content: "");
}

class TodoNoteCreator extends NoteCreator {
  @override
  Note createNote() => TodoNote(title: "Список дел", content: "", items: []);
}

class TaggedNoteCreator extends NoteCreator {
  final String tag;
  TaggedNoteCreator(this.tag);

  @override
  Note createNote() =>
      TaggedNote(title: "Пометка", content: "", tag: tag);
}

// --------------------
// Хранилище заметок
// --------------------

class NotesModel extends ChangeNotifier {
  final List<Note> _notes = [];
  final String _prefsKey = "notes";

  List<Note> get notes => _notes;

  NotesModel() {
    _load();
  }

  void add(Note note) {
    _notes.add(note);
    _save();
    notifyListeners();
  }

  void remove(int index) {
    _notes.removeAt(index);
    _save();
    notifyListeners();
  }

  void clone(Note note) {
    _notes.add(note.clone());
    _save();
    notifyListeners();
  }

  void update(int index, Note note) {
    _notes[index] = note;
    _save();
    notifyListeners();
  }

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _notes.map((n) => n.toJson()).toList();
    prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null) return;

    final data = jsonDecode(jsonString) as List;
    _notes.clear();

    for (var n in data) {
      switch (n["type"]) {
        case "simple":
          _notes.add(SimpleNote.fromJson(n));
          break;
        case "todo":
          _notes.add(TodoNote.fromJson(n));
          break;
        case "tagged":
          _notes.add(TaggedNote.fromJson(n));
          break;
      }
    }
    notifyListeners();
  }
}
