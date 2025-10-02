import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/3lab_logic.dart';
import 'lab3_edit_screen.dart';

class Lab3Screen extends StatelessWidget {
  const Lab3Screen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const NotesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTemplateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTemplateDialog(BuildContext context) {
    final model = Provider.of<NotesModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text("Выбери шаблон заметки"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              final newNote = SimpleNoteCreator().createNote();
              model.add(newNote);
              Navigator.pop(dialogContext); // Close the dialog first
              Navigator.push( // Then navigate to EditNoteScreen
                context,
                MaterialPageRoute(
                  builder: (_) => EditNoteScreen(
                    // The new note will be the last one in the list
                    index: model.notes.length -1, // or model.notes.indexOf(newNote) if preferred
                    note: newNote,
                  ),
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.note_add),
              title: Text("Простая заметка"),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              final newNote = TodoNoteCreator().createNote();
              model.add(newNote);
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditNoteScreen(
                    index: model.notes.length - 1,
                    note: newNote,
                  ),
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.checklist),
              title: Text("Список дел"),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              // Assuming TaggedNoteCreator needs a tag.
              // You might want to prompt for a tag here or use a default.
              final newNote = TaggedNoteCreator("важно").createNote();
              model.add(newNote);
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditNoteScreen(
                    index: model.notes.length - 1,
                    note: newNote,
                  ),
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.label),
              title: Text("Заметка с меткой"),
            ),
          ),
        ],
      ),
    );
  }
}

class NotesList extends StatelessWidget {
  const NotesList({super.key});

  IconData _getIcon(Note note) {
    if (note is SimpleNote) return Icons.note_alt;
    if (note is TodoNote) return Icons.checklist;
    if (note is TaggedNote) return Icons.label;
    return Icons.sticky_note_2;
  }

  Widget _buildNoteContent(Note note, int index, NotesModel model, BuildContext context) {
    if (note is TodoNote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: note.items.asMap().entries.map((entry) {
          //final i = entry.key;
          final item = entry.value;
          return Row(
            children: [
              Checkbox(
                value: item.done,
                onChanged: (val) {
                  final model = Provider.of<NotesModel>(context, listen: false);
                  item.done = val == true;
                  model.update(index, note); 
                },
              ),
              Expanded(child: Text(item.text)),
            ],
          );
        }).toList(),
      );
    } else if (note is TaggedNote) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              note.tag,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(note.content)),
        ],
      );
    } else {
      return Text(note.content.isEmpty ? "Пустая заметка" : note.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesModel>(
      builder: (context, model, child) {
        if (model.notes.isEmpty) {
          return const Center(child: Text("Нет заметок"));
        }
        return ListView.builder(
          itemCount: model.notes.length,
          itemBuilder: (context, index) {
            final note = model.notes[index];
            return Card(
              child: ListTile(
                leading: Icon(_getIcon(note)),
                title: Text(note.title),
                subtitle: _buildNoteContent(note, index, model, context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditNoteScreen(index: index, note: note),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => model.clone(note),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => model.remove(index),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


