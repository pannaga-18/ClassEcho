import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:class_echo/utils/util.dart'; // Adjust the path as necessary to import
import 'dart:convert'; // for jsonDecode

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Audio File Picker")),
        body: const Center(child: AudioPickerWidget()),
      ),
    );
  }
}

class AudioPickerWidget extends StatefulWidget {
  const AudioPickerWidget({super.key});

  @override
  State<AudioPickerWidget> createState() => _AudioPickerWidgetState();
}

class _AudioPickerWidgetState extends State<AudioPickerWidget> {
  String status = "Pick an audio file";

  Future<void> testServer() async {
    final response = await http.get(Uri.parse('$baseUrl/'));
    if (response.statusCode == 200) {
      setState(() => status = "Server Response: ${response.body}");
    } else {
      setState(() => status = "Failed to connect to server");
    }
  }

 
  Map<String, dynamic>? apiResponse; // to store API response

Future<void> pickAndUploadAudio() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
      withData: true, // IMPORTANT: ensures bytes are available
    );

    if (result != null) {
      final file = result.files.single;

      print("File name: ${file.name}");
      print("File size: ${file.size}");
      print("File path: ${file.path}");
      print("File bytes: ${file.bytes != null ? file.bytes!.length : 'null'}");

      http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/process-audio'));

      // ✅ Android/Desktop: upload using path
      if (file.path != null) {
        request.files
            .add(await http.MultipartFile.fromPath('audio', file.path!));
      } 
      // ✅ Web: upload using bytes
      else if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('audio', file.bytes!,
            filename: file.name));
      } else {
        setState(() => status = "No file data available");
        return;
      }

      // Send request
      var streamedResponse = await request.send();
      var respStr = await streamedResponse.stream.bytesToString();

      // ✅ Try decoding JSON
      try {
        final decoded = jsonDecode(respStr);

        // Example: if FastAPI returns { "title": "...", "topics": [...] }
        print("Decoded response: $decoded");

        // Store in state to use later
        setState(() {
          status = "Processed successfully";
          apiResponse = decoded; // <-- keep this Map<String, dynamic> in state
        });
      } catch (err) {
        print("Response was not valid JSON: $respStr");
        setState(() => status = "Upload done, but parsing failed");
      }
    } else {
      setState(() => status = "No file selected");
    }
  } catch (e) {
    setState(() => status = "Error: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: testServer,
          child: const Text("Test Server Connection"),
        ),
        ElevatedButton(
          onPressed: pickAndUploadAudio,
          child: const Text("Pick Audio File"),
        ),
        const SizedBox(height: 20),
        SelectableText(status, textAlign: TextAlign.center),
      ],
    );
  }
}
