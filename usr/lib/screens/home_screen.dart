import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ApiService _apiService = ApiService();

  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Arabic', 'Yoruba'];
  
  bool _isRecording = false;
  bool _isGenerating = false;
  String? _recordedFilePath;
  String? _generatedAudioPath;
  bool _isPlaying = false;

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/ref_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    } catch (e) {
      print('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      print('Error stopping record: $e');
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() => _isPlaying = false);
      });
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() => _isPlaying = false);
  }

  Future<void> _generateSpeech() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    if (_recordedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record a voice reference first')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    // Map display language to code
    String langCode = 'en';
    if (_selectedLanguage == 'Arabic') langCode = 'ar';
    if (_selectedLanguage == 'Yoruba') langCode = 'yo'; // Assuming 'yo' for Yoruba

    final File? result = await _apiService.generateSpeech(
      text: _textController.text,
      language: langCode,
      referenceAudio: File(_recordedFilePath!),
    );

    setState(() => _isGenerating = false);

    if (result != null) {
      setState(() => _generatedAudioPath = result.path);
    } else {
      // Show demo dialog since we don't have a real backend
      _showBackendDialog();
    }
  }

  void _showBackendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Required'),
        content: const Text(
          'To generate real audio, this app needs to be connected to a CozyVoice backend server.\n\n'
          'The app is currently configured to look for a server at http://10.0.2.2:8000 (Android Emulator default).\n\n'
          'Please set up the Python backend to process the requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CozyVoice Clone TTS'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Voice Reference
            _buildSectionTitle('1. Voice Reference'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Record a 3-10 second voice sample to clone.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onLongPress: _startRecording,
                        onLongPressUp: _stopRecording,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red : Colors.indigo,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : Colors.indigo).withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRecording ? 'Recording... Release to stop' : 'Hold to Record',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.red : Colors.black87,
                    ),
                  ),
                  if (_recordedFilePath != null) ...[
                    const SizedBox(height: 15),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: const Text('Reference Audio Ready'),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _playAudio(_recordedFilePath!),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Section 2: Text Input
            _buildSectionTitle('2. Text to Speech'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Target Language',
                prefixIcon: Icon(Icons.language),
              ),
              items: _languages.map((lang) {
                return DropdownMenuItem(value: lang, child: Text(lang));
              }).toList(),
              onChanged: (val) => setState(() => _selectedLanguage = val!),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Enter text to generate',
                hintText: _selectedLanguage == 'Arabic' 
                    ? 'أدخل النص هنا...' 
                    : 'Type something here...',
                alignLabelWithHint: true,
              ),
              textDirection: _selectedLanguage == 'Arabic' 
                  ? TextDirection.rtl 
                  : TextDirection.ltr,
            ),

            const SizedBox(height: 25),

            // Section 3: Generate
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSpeech,
                icon: _isGenerating 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      ) 
                    : const Icon(Icons.record_voice_over),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Speech',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            if (_generatedAudioPath != null) ...[
              const SizedBox(height: 25),
              _buildSectionTitle('3. Result'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.stop_circle : Icons.play_circle_fill),
                      iconSize: 48,
                      color: Colors.green,
                      onPressed: () {
                        if (_isPlaying) {
                          _stopAudio();
                        } else {
                          _playAudio(_generatedAudioPath!);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio Generated Successfully!',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          Text('Tap play to listen', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
