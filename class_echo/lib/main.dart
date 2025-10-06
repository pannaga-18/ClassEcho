import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:class_echo/utils/util.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassEcho',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AudioNotesPage(),
    );
  }
}

class AudioNotesPage extends StatefulWidget {
  const AudioNotesPage({super.key});

  @override
  State<AudioNotesPage> createState() => _AudioNotesPageState();
}

class _AudioNotesPageState extends State<AudioNotesPage> {
  String status = "Ready to process your audio";
  bool isLoading = false;
  bool isServerConnected = false;
  Map<String, dynamic>? apiResponse;
  String? selectedFileName;

  @override
  void initState() {
    super.initState();
    checkServerConnection();
  }

  Future<void> checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl1/'));
      if (response.statusCode == 200) {
        setState(() {
          isServerConnected = true;
          status = "Server connected successfully";
        });
      } else {
        setState(() {
          isServerConnected = false;
          status = "Server connection failed";
        });
      }
    } catch (e) {
      setState(() {
        isServerConnected = false;
        status = "Cannot reach server: $e";
      });
    }
  }

  Future<void> pickAndUploadAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true,
      );

      if (result != null) {
        final file = result.files.single;
        
        setState(() {
          isLoading = true;
          status = "Processing ${file.name}...";
          selectedFileName = file.name;
          apiResponse = null; // Clear previous response
        });

        http.MultipartRequest request =
            http.MultipartRequest('POST', Uri.parse('$baseUrl1/process-audio'));

        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('audio', file.path!));
        } else if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('audio', file.bytes!,
              filename: file.name));
        } else {
          setState(() {
            status = "No file data available";
            isLoading = false;
          });
          return;
        }

        var streamedResponse = await request.send();
        var respStr = await streamedResponse.stream.bytesToString();

        try {
          final decoded = jsonDecode(respStr);
          setState(() {
            status = "Processing complete!";
            apiResponse = decoded;
            isLoading = false;
          });
        } catch (err) {
          setState(() {
            status = "Failed to parse response";
            isLoading = false;
          });
        }
      } else {
        setState(() => status = "No file selected");
      }
    } catch (e) {
      setState(() {
        status = "Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassEcho', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: isServerConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isServerConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 14,
                      color: isServerConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                if (selectedFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.audio_file, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : pickAndUploadAudio,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(isLoading ? 'Processing...' : 'Upload Audio'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: checkServerConnection,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Check Server',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLoading ? Colors.blue : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: apiResponse == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Upload an audio file to generate notes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : NotesDisplay(data: apiResponse!),
          ),
        ],
      ),
    );
  }
}

class NotesDisplay extends StatelessWidget {
  final Map<String, dynamic> data;

  const NotesDisplay({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (data['title'] != null) ...[
            Text(
              data['title'],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Overview
          if (data['overview'] != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['overview'],
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Speakers
          if (data['speakers'] != null && data['speakers'].isNotEmpty) ...[
            const Text(
              '👥 Speakers',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(data['speakers'].length, (index) {
              final speaker = data['speakers'][index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speaker['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (speaker['role'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          speaker['role'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (speaker['key_contributions'] != null) ...[
                        const SizedBox(height: 8),
                        ...List.generate(speaker['key_contributions'].length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 16)),
                                Expanded(
                                  child: Text(
                                    speaker['key_contributions'][i],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Topics
          if (data['topics'] != null) ...[
            const Text(
              '📚 Topics',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(data['topics'].length, (index) {
              final topic = data['topics'][index];
              return TopicCard(topic: topic, index: index);
            }),
          ],

          // Key Takeaways
          if (data['key_takeaways'] != null && data['key_takeaways'].isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ Key Takeaways',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(data['key_takeaways'].length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              data['key_takeaways'][index],
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Action Items
          if (data['action_items'] != null && data['action_items'].isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎯 Action Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(data['action_items'].length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_box_outline_blank, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['action_items'][index],
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Further Learning
          if (data['further_learning'] != null) ...[
            const SizedBox(height: 16),
            FurtherLearningSection(data: data['further_learning']),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class TopicCard extends StatelessWidget {
  final Map<String, dynamic> topic;
  final int index;

  const TopicCard({super.key, required this.topic, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              '${index + 1}. ${topic['heading'] ?? 'Topic'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            
            // Summary
            if (topic['summary'] != null) ...[
              const SizedBox(height: 8),
              Text(
                topic['summary'],
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],

            // Key Points
            if (topic['key_points'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Key Points:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(topic['key_points'].length, (i) {
                final point = topic['key_points'][i];
                return KeyPointWidget(point: point);
              }),
            ],

            // Additional Insights
            if (topic['additional_insights'] != null &&
                topic['additional_insights'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💡 Additional Insights',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(topic['additional_insights'].length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                topic['additional_insights'][i],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Resources
            if (topic['recommended_resources'] != null &&
                topic['recommended_resources'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '📖 Recommended Resources',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(topic['recommended_resources'].length, (i) {
                final resource = topic['recommended_resources'][i];
                return ResourceWidget(resource: resource);
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class KeyPointWidget extends StatelessWidget {
  final Map<String, dynamic> point;

  const KeyPointWidget({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point['point'] ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (point['explanation'] != null) ...[
            const SizedBox(height: 6),
            Text(
              point['explanation'],
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          if (point['examples'] != null && point['examples'].isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Examples:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),
            ...List.generate(point['examples'].length, (i) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '• ${point['examples'][i]}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
          if (point['importance'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point['importance'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ResourceWidget extends StatelessWidget {
  final Map<String, dynamic> resource;

  const ResourceWidget({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    
    switch (resource['type']) {
      case 'book':
        icon = Icons.menu_book;
        iconColor = Colors.brown;
        break;
      case 'course':
        icon = Icons.school;
        iconColor = Colors.blue;
        break;
      case 'video':
        icon = Icons.play_circle;
        iconColor = Colors.red;
        break;
      case 'article':
        icon = Icons.article;
        iconColor = Colors.green;
        break;
      case 'tool':
        icon = Icons.build;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.link;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          resource['title'] ?? 'Resource',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource['description'] != null) ...[
              const SizedBox(height: 4),
              Text(resource['description']),
            ],
            if (resource['url'] != null && resource['url'] != 'Search online') ...[
              const SizedBox(height: 4),
              Text(
                resource['url'],
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        dense: false,
      ),
    );
  }
}

class FurtherLearningSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const FurtherLearningSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚀 Further Learning Paths',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          if (data['beginner'] != null) ...[
            LearningLevelWidget(
              level: 'Beginner',
              icon: Icons.star_border,
              color: Colors.green,
              resources: data['beginner'],
            ),
          ],
          if (data['intermediate'] != null) ...[
            const SizedBox(height: 12),
            LearningLevelWidget(
              level: 'Intermediate',
              icon: Icons.star_half,
              color: Colors.orange,
              resources: data['intermediate'],
            ),
          ],
          if (data['advanced'] != null) ...[
            const SizedBox(height: 12),
            LearningLevelWidget(
              level: 'Advanced',
              icon: Icons.star,
              color: Colors.red,
              resources: data['advanced'],
            ),
          ],
        ],
      ),
    );
  }
}

class LearningLevelWidget extends StatelessWidget {
  final String level;
  final IconData icon;
  final Color color;
  final List<dynamic> resources;

  const LearningLevelWidget({
    super.key,
    required this.level,
    required this.icon,
    required this.color,
    required this.resources,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              level,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(resources.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    resources[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}