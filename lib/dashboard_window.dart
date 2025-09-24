import 'package:flutter/material.dart';
import 'package:flutter_application_1/image_window.dart';

class DashboardWindow extends StatelessWidget {
  const DashboardWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Center(
            child: Text(
              "Dashboard",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text("Open Image"),
            onPressed: () {
              // We'll trigger file picker from the image window, or use a callback
              ImageWindow.openImageFile?.call();
            },
          ),
          // const SizedBox(height: 20),
          // IconButton(
          //   icon: const Icon(Icons.crop),
          //   onPressed: () {
          //     ImageWindow.openImageFile?.call();
          //     ImageWindow.focusNode?.requestFocus(); // ADD THIS
          //   },
          //   focusNode: FocusNode(canRequestFocus: false),
          // ),
          // IconButton(
          //   icon: const Icon(Icons.brush),
          //   onPressed: () {
          //     ImageWindow.openImageFile?.call();
          //     ImageWindow.focusNode?.requestFocus(); // ADD THIS
          //   },
          //   focusNode: FocusNode(canRequestFocus: false),
          // ),
          // Add more tools as needed
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Blotter Pixel AVG", textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
