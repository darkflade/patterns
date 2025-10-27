import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/6lab_logic.dart';

class Lab6Screen extends StatelessWidget {
  const Lab6Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Player (State Pattern)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Consumer<AudioPlayerManager>(
              builder: (context, player, child) => Text('State: ${player.currentStateName}')),
            Consumer<AudioPlayerManager>(
              builder: (context, player, child) => Text('Track: ${player.currentTrack?.split('/').last ?? 'None'}')),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => context.read<AudioPlayerManager>().play()),
                IconButton(icon: const Icon(Icons.pause), onPressed: () => context.read<AudioPlayerManager>().pause()),
                IconButton(icon: const Icon(Icons.stop), onPressed: () => context.read<AudioPlayerManager>().stop()),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<AudioPlayerManager>(
                builder: (context, player, child) {
                  if (player.playlist.isEmpty) {
                    return const Center(child: Text('No audio files selected.'));
                  }
                  return ListView.builder(
                    itemCount: player.playlist.length,
                    itemBuilder: (context, index) {
                      final track = player.playlist[index];
                      return ListTile(
                        title: Text(track.split('/').last),
                        onTap: () => player.setTrack(track),
                        selected: player.currentTrack == track,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<AudioPlayerManager>().pickFiles(),
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
