import 'package:flutter/material.dart';
import '../logic/3lab_logic.dart';
import 'package:provider/provider.dart';

class EditNoteScreen extends StatefulWidget {
  final int index;
  final Note note; // The original note from the model

  const EditNoteScreen({super.key, required this.index, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late Note _editableNote; // Local clone of the note for editing

  @override
  void initState() {
    super.initState();

    _editableNote = widget.note.clone();

    _titleCtrl = TextEditingController(text: _editableNote.title);
    _contentCtrl = TextEditingController(text: _editableNote.content);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final model = Provider.of<NotesModel>(context, listen: false);

    // Apply changes from TextControllers to the local _editableNote
    _editableNote.title = _titleCtrl.text;
    _editableNote.content = _contentCtrl.text; // For SimpleNote/TaggedNote

    // For TodoNote, its items list within _editableNote has already been
    // modified directly by the UI interactions.

    // Update the model with the fully modified local _editableNote
    model.update(widget.index, _editableNote);
    Navigator.pop(context, _editableNote); // Optionally pass the updated note back
  }

  @override
  Widget build(BuildContext context) {
    // No need to get model here for immediate updates, only for saving.

    return Scaffold(
      appBar: AppBar(
        title: const Text("Редактировать заметку"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Заголовок
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: "Заголовок"),
            ),
            const SizedBox(height: 12),

            // Контент или TodoList
            Expanded(
              child: _editableNote is TodoNote
                  ? Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: (_editableNote as TodoNote).items.length,
                            itemBuilder: (context, i) {
                              // Work directly with items from _editableNote
                              final item = (_editableNote as TodoNote).items[i];
                              return CheckboxListTile(
                                title: TextFormField(
                                  initialValue: item.text,
                                  onChanged: (val) {
                                    // Update the local _editableNote's item
                                    // No model.update() here
                                    setState(() {
                                       item.text = val;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none, // Cleaner look
                                  ),
                                ),
                                value: item.done,
                                onChanged: (val) {
                                  // Update the local _editableNote's item's done status
                                  // No model.update() here
                                  setState(() {
                                    item.done = val ?? false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        // Кнопка добавления нового пункта
                        TextButton.icon(
                          onPressed: () {
                            // Add item to the local _editableNote
                            // No model.update() here
                            setState(() {
                              (_editableNote as TodoNote)
                                  .items
                                  .add(TodoItem(text: "Новая задача"));
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Добавить задачу"),
                        ),
                      ],
                    )
                  : TextField( // For SimpleNote or TaggedNote
                      controller: _contentCtrl,
                      decoration: const InputDecoration(labelText: "Содержимое"),
                      maxLines: null,
                      expands: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
