import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class MemeSettingsScreen extends StatefulWidget {
  const MemeSettingsScreen({super.key});

  @override
  State<MemeSettingsScreen> createState() => _MemeSettingsScreenState();
}

class _MemeSettingsScreenState extends State<MemeSettingsScreen> {
  bool _meme67 = true;
  bool _memeNice = true;
  bool _memeRoundSounds = true;
  bool _memeOffensive = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final m67 = await AppSettings.getMeme67();
    final mNice = await AppSettings.getMemeNice();
    final mRound = await AppSettings.getMemeRoundSounds();
    final mOffensive = await AppSettings.getMemeOffensive();
    setState(() {
      _meme67 = m67;
      _memeNice = mNice;
      _memeRoundSounds = mRound;
      _memeOffensive = mOffensive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meme Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'You found the secret menu!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          SwitchListTile(
            title: const Text('6-7, 6-7'),
            subtitle: const Text('When a player hits 6 then 7 in a row'),
            value: _meme67,
            onChanged: (v) {
              setState(() => _meme67 = v);
              AppSettings.setMeme67(v);
            },
          ),
          SwitchListTile(
            title: const Text('Nice'),
            subtitle: const Text('When a round totals exactly 69'),
            value: _memeNice,
            onChanged: (v) {
              setState(() => _memeNice = v);
              AppSettings.setMemeNice(v);
            },
          ),
          SwitchListTile(
            title: const Text('End of round sounds'),
            subtitle: const Text('Play a reaction sound based on round score (100+ or below 10)'),
            value: _memeRoundSounds,
            onChanged: (v) {
              setState(() => _memeRoundSounds = v);
              AppSettings.setMemeRoundSounds(v);
            },
          ),
          SwitchListTile(
            title: const Text('Offensive sounds'),
            subtitle: const Text('Include offensive sounds in the pool when they are available'),
            value: _memeOffensive,
            onChanged: (v) {
              setState(() => _memeOffensive = v);
              AppSettings.setMemeOffensive(v);
            },
          ),
        ],
      ),
    );
  }
}
