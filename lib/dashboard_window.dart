import 'package:blotter_avg/image_window.dart';
import 'package:flutter/material.dart';

class DashboardWindow extends StatefulWidget {
  const DashboardWindow({super.key});

  static void Function(String)? appendText;

  @override
  State<DashboardWindow> createState() => _DashboardWindowState();
}

class _DashboardWindowState extends State<DashboardWindow> {
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    DashboardWindow.appendText = (String text) {
      if (controller.text.isEmpty) {
        controller.text = text;
      } else {
        controller.text += '\n$text';
      }
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      setState(() {});
    };
  }

  @override
  void dispose() {
    if (DashboardWindow.appendText != null) DashboardWindow.appendText = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text("Open Image"),
            onPressed: () {
              ImageWindow.openImageFile?.call();
            },
          ),
          const SizedBox(height: 16),
          // This Expanded makes the TextField fill vertical space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  labelText: 'Values',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                readOnly: false,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Blotter Pixel AVG", textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
