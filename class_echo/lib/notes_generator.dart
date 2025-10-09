import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:class_echo/utils/util.dart';
import 'dart:convert';

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
  Map<String, dynamic>? qaData;
  String? selectedFileName;

  FilePickerResult? result = null;
  bool showFeatures = false;
  bool isNotes = false;
  bool isQA = false;
  bool isGenerated = false;

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

// 1️⃣ Pick audio and store it
  Future<void> pickAudio() async {
    try {
      final pickedResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true,
      );

      if (pickedResult != null) {
        final file = pickedResult.files.single;

        setState(() {
          result = pickedResult;
          selectedFileName = file.name;
          status = "File selected: ${file.name} \n Select any feature";
          showFeatures = true;
        });
      } else {
        setState(() {
          status = "No file selected";
          result = null;
          selectedFileName = null;
          showFeatures = false;
        });
      }
    } catch (e) {
      setState(() {
        status = "Error picking file, try again";
        result = null;
        selectedFileName = null;
        showFeatures = false;
      });
    }
  }

// 2️⃣ Generate notes only when button clicked
  Future<void> generate(String feature) async {
    if (result == null) {
      setState(() {
        status = "No file selected. Pick an audio file first.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      isGenerated = true;

      if (feature == "notes") {
        status = "Generating notes...";
      } else {
        status = "Generating Q / A...";
      }

      apiResponse = null;
      qaData = null;
    });

    final file = result!.files.single;
    try {
      http.MultipartRequest request;
      if (feature == "notes") {
        request = http.MultipartRequest(
            'POST', Uri.parse('$baseUrl1/generate_notes'));
      } else {
        request =
            http.MultipartRequest('POST', Uri.parse('$baseUrl1/generate_qa'));
      }

      if (file.path != null) {
        request.files
            .add(await http.MultipartFile.fromPath('audio', file.path!));
      } else if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('audio', file.bytes!,
            filename: file.name));
      } else {
        setState(() {
          status = "No file data available";
          isLoading = false;
          isGenerated = false;
        });
        return;
      }

      var streamedResponse = await request.send();
      var respStr = await streamedResponse.stream.bytesToString();

      final decoded = jsonDecode(respStr);
      print(decoded);
      print("SS");

      if (feature == "notes") {
        setState(() {
          apiResponse = decoded;
          status = "Notes generation complete!";
          isLoading = false;
          isNotes = true;
          isQA = false;
          isGenerated = false;
        });
      } else {
        // print(qaData);

        setState(() {
          qaData = decoded;
          print(qaData);
          print("SS");
          status = "Q / A generation complete!";
          isLoading = false;
          isNotes = false;
          isQA = true;
          isGenerated = false;
        });
      }
    } catch (e) {
      setState(() {
        status = "Failed to generate notes. Try again.";
        isLoading = false;
        isGenerated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassEcho',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                        onPressed: isLoading ? null : pickAudio,
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
                        label:
                            Text(isLoading ? 'Processing...' : 'Upload Audio'),
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
                SelectableText(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLoading ? Colors.blue : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showFeatures) ...[
                  Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                              onPressed: () {
                                generate("notes");
                              },
                              child: Text("Generate Notes")),
                          ElevatedButton(
                              onPressed: () {
                                generate("qa");
                              },
                              child: Text("Generate Q / A")),
                        ],
                      ))
                ]
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: !isGenerated &&
                    (apiResponse == null || (apiResponse?.isEmpty ?? true)) &&
                    (qaData == null || (qaData?.isEmpty ?? true))
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
                          'Upload an audio file to generate notes or Q/A',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (isGenerated)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  isNotes
                                      ? 'Generating notes...'
                                      : 'Generating Q / A...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                : (isNotes && !isGenerated)
                    ? NotesDisplay(data: apiResponse!)
                    : (isQA && !isGenerated)
                        ? QADisplay(qaData: qaData!)
                        : Container(),
          ),
        ],
      ),
    );
  }
}

// class QADisplay extends

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
            SelectableText(
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
                  const SelectableText(
                    '📋 Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
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
            const SelectableText(
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
                      SelectableText(
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
                        ...List.generate(speaker['key_contributions'].length,
                            (i) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(fontSize: 16)),
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
            const SelectableText(
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
          if (data['key_takeaways'] != null &&
              data['key_takeaways'].isNotEmpty) ...[
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
                  const SelectableText(
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
                            child: SelectableText(
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
          if (data['action_items'] != null &&
              data['action_items'].isNotEmpty) ...[
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
              SelectableText(
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
              const SelectableText(
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
                    const SelectableText(
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
                            const SelectableText('• '),
                            Expanded(
                              child: SelectableText(
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
              const SelectableText(
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
        title: SelectableText(
          resource['title'] ?? 'Resource',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource['description'] != null) ...[
              const SizedBox(height: 4),
              SelectableText(resource['description']),
            ],
            if (resource['url'] != null &&
                resource['url'] != 'Search online') ...[
              const SizedBox(height: 4),
              SelectableText(
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
          const SelectableText(
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
            SelectableText(
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
                const SelectableText('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: SelectableText(
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

// QA Section
class QADisplay extends StatelessWidget {
  final Map<String, dynamic> qaData;

  const QADisplay({super.key, required this.qaData});

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'concept':
        return Icons.lightbulb_outline;
      case 'application':
        return Icons.build_outlined;
      case 'critical_thinking':
        return Icons.psychology_outlined;
      case 'synthesis':
        return Icons.hub_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  qaData['topic'] ?? 'Practice Questions',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(
                      '${qaData['total_questions']} Questions',
                      Icons.quiz,
                    ),
                    const SizedBox(width: 8),
                    if (qaData['difficulty_breakdown'] != null) ...[
                      _buildStatChip(
                        '${qaData['difficulty_breakdown']['easy']} Easy',
                        Icons.star_border,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        '${qaData['difficulty_breakdown']['medium']} Medium',
                        Icons.star_half,
                        color: Colors.orange.shade300,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Study Tips Section
          if (qaData['study_tips'] != null &&
              qaData['study_tips'].isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates,
                          color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      SelectableText(
                        'Study Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(qaData['study_tips'].length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText('${index + 1}. ',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: SelectableText(qaData['study_tips'][index]),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Questions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Question Cards
          if (qaData['questions'] != null) ...[
            ...List.generate(qaData['questions'].length, (index) {
              final question = qaData['questions'][index];
              return QuestionCard(
                question: question,
                index: index,
                difficultyColor:
                    _getDifficultyColor(question['difficulty'] ?? ''),
                categoryIcon: _getCategoryIcon(question['category'] ?? ''),
              );
            }),
          ],

          // Quiz Summary
          if (qaData['quiz_summary'] != null) ...[
            QuizSummarySection(summary: qaData['quiz_summary']),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          SelectableText(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// EXPANDABLE QUESTION CARD
// ==========================================
class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final int index;
  final Color difficultyColor;
  final IconData categoryIcon;

  const QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.difficultyColor,
    required this.categoryIcon,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: _isExpanded ? widget.difficultyColor : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Question Header (Always Visible)
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Number Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.difficultyColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.difficultyColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Question Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.question['question'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Difficulty Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.difficultyColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.question['difficulty'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.difficultyColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Category Icon
                            Icon(
                              widget.categoryIcon,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            SelectableText(
                              widget.question['category'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand/Collapse Icon
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.difficultyColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: widget.difficultyColor,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Answer Section (Expandable)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Answer Label
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Answer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Answer Text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: SelectableText(
                      widget.question['answer'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Key Terms
                  if (widget.question['key_terms'] != null &&
                      widget.question['key_terms'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const SelectableText(
                          '🏷️ Key Terms: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ...List.generate(
                          widget.question['key_terms'].length,
                          (index) => Chip(
                            label: SelectableText(
                              widget.question['key_terms'][index],
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.blue.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Related Topics
                  if (widget.question['related_topics'] != null &&
                      widget.question['related_topics'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const Text(
                          '🔗 Related: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ...List.generate(
                          widget.question['related_topics'].length,
                          (index) => Chip(
                            label: SelectableText(
                              widget.question['related_topics'][index],
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.purple.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// QUIZ SUMMARY SECTION
// ==========================================
class QuizSummarySection extends StatelessWidget {
  final Map<String, dynamic> summary;

  const QuizSummarySection({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📚 Quiz Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          if (summary['main_themes'] != null) ...[
            _buildSummarySection(
              'Main Themes',
              summary['main_themes'],
              Icons.topic,
              Colors.blue,
            ),
          ],
          if (summary['prerequisites'] != null) ...[
            const SizedBox(height: 12),
            _buildSummarySection(
              'Prerequisites',
              summary['prerequisites'],
              Icons.school,
              Colors.orange,
            ),
          ],
          if (summary['next_steps'] != null) ...[
            const SizedBox(height: 12),
            _buildSummarySection(
              'Next Steps',
              summary['next_steps'],
              Icons.arrow_forward,
              Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection(
      String title, List<dynamic> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            SelectableText(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            return Chip(
              label: SelectableText(
                item.toString(),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: color.withOpacity(0.1),
              side: BorderSide(color: color.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}
